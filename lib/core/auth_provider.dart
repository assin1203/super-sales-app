import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/user_api.dart';
import 'api_client.dart';
import 'models/user_info.dart';
import 'token_store.dart';

/// 登录态（手机号 + 密码登录，双 token 由 server 签发）。
///
/// - access token 走内存 + 本地存储，注入到 [ApiClient] 的 Authorization 头
/// - access 过期（401）时用 refresh token 轮换一次并自动重放原请求
/// - 本地只缓存 refresh token / 用户快照，启动时静默续期校验，失效即登出
class AuthProvider extends ChangeNotifier {
  AuthProvider({ApiClient? client, UserApi? users, SecureStore? secureStore})
      : _api = client ?? api,
        _users = users ?? userApi,
        _secure = secureStore ?? const PlatformSecureStore();

  static const _kAccessToken = 'kqw.access_token';
  static const _kRefreshToken = 'kqw.refresh_token';
  static const _kUser = 'kqw.user';
  static const _kNickname = 'kqw.nickname';
  static const _kAvatarUrl = 'kqw.avatar_url';

  final ApiClient _api;
  final UserApi _users;

  SharedPreferences? _prefs;

  /// token 走系统安全存储（iOS Keychain / Android Keystore），不落明文
  final SecureStore _secure;

  /// 安全存储不可用（单元测试、无平台插件的环境）时降级到 SharedPreferences
  bool _secureUnavailable = false;

  bool _loggedIn = false;
  String? _accessToken;
  String? _refreshToken;
  UserInfo? _user;
  String? _nicknameOverride;
  String? _avatarUrl;

  /// 刚裁切完的头像字节，用于立即预览（网络头像走 [avatarUrl]）
  Uint8List? _avatarBytes;

  bool get loggedIn => _loggedIn;
  String? get token => _accessToken;
  UserInfo? get user => _user;
  int? get userId => int.tryParse(_user?.id ?? '');
  int get level => _user?.level ?? 0;
  String? get maskedPhone => _user?.maskedPhone;
  String? get avatarUrl => _avatarUrl;
  Uint8List? get avatarBytes => _avatarBytes;

  /// 昵称：以服务端（`GET /user/me`）为准，本地覆盖只作提交前的乐观展示
  String? get nickname {
    final server = _user?.nickname?.trim();
    if (server != null && server.isNotEmpty) return server;
    final local = _nicknameOverride?.trim();
    return local != null && local.isNotEmpty ? local : null;
  }

  /// 性别：0 未知 / 1 男 / 2 女（服务端 `gender`）
  int get gender => _user?.gender ?? 0;

  /// 生日：YYYY-MM-DD（服务端 `birthday`）
  String? get birthday => _user?.birthday;

  /// 展示名：昵称 → 脱敏手机号
  String? get name => nickname ?? _user?.displayName;

  /// 启动时恢复：读取本地 token 并静默续期校验
  Future<void> init() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    _nicknameOverride = prefs.getString(_kNickname);
    _avatarUrl = prefs.getString(_kAvatarUrl);

    final userJson = prefs.getString(_kUser);
    if (userJson != null) {
      try {
        _user = UserInfo.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      } catch (_) {
        _user = null;
      }
    }

    final access = await _readSecret(_kAccessToken);
    final refreshToken = await _readSecret(_kRefreshToken);
    if (access == null || refreshToken == null) {
      notifyListeners();
      return;
    }

    _accessToken = access;
    _refreshToken = refreshToken;
    _loggedIn = true;
    _api.accessToken = access;
    _api.onRefresh = _refreshSession;
    notifyListeners();

    // 后台校验，不阻塞首屏；网络异常时保留本地登录态
    unawaited(_validateSession());
  }

  /// 手机号 + 密码登录。失败抛 [ApiException]（401 → 「手机号或密码错误」）
  Future<void> loginPassword(String phone, String password) async {
    final res = await _users.login(phone, password);
    _user = res.user;
    _loggedIn = true;
    _accessToken = res.accessToken;
    _refreshToken = res.refreshToken;
    _api.accessToken = res.accessToken;
    _api.onRefresh = _refreshSession;

    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await _writeSecret(_kAccessToken, res.accessToken);
    await _writeSecret(_kRefreshToken, res.refreshToken);
    await prefs.setString(_kUser, jsonEncode(res.user.toJson()));
    notifyListeners();
  }

  /// 退出登录：先清本地登录态，再后台撤销 refresh token。
  ///
  /// 顺序不能反过来：先等网络的话弱网下最长要卡 30s，期间用户再次登录，
  /// 这条迟到的清理会把新会话一起清掉。
  Future<void> logout() async {
    final refreshToken = _refreshToken;
    await _clearSession();
    if (refreshToken == null) return;
    unawaited(() async {
      try {
        await _users.logout(refreshToken);
      } catch (_) {
        // 撤销失败不影响本地登出（access 本身无状态，到期自然失效）
      }
    }());
  }

  /// 修改个人资料；name / avatarBytes 传 null 表示不变更该字段，name 传空串表示清空昵称。
  /// avatarUrl 为上传成功后服务端返回的地址，本地一并缓存。
  void updateProfile({String? name, Uint8List? avatarBytes, String? avatarUrl}) {
    if (name != null) {
      _nicknameOverride = name.trim();
      unawaited(_prefs?.setString(_kNickname, _nicknameOverride!) ?? Future<void>.value());
    }
    if (avatarBytes != null) _avatarBytes = avatarBytes;
    if (avatarUrl != null) {
      _avatarUrl = avatarUrl;
      unawaited(_prefs?.setString(_kAvatarUrl, avatarUrl) ?? Future<void>.value());
    }
    notifyListeners();
  }

  /// 拉取完整资料（`GET /user/me`）：登录只回四个字段，等级名/邀请码/性别/生日需此接口补齐。
  /// 服务端是唯一事实来源：昵称/头像以返回值为准，本地乐观覆盖随之清空。
  /// 失败不抛错，保留本地快照，页面继续用旧数据渲染。
  Future<void> loadProfile() async {
    if (!_loggedIn) return;
    try {
      final me = await _users.me();
      _user = me;
      final avatar = me.avatar;
      _avatarUrl = (avatar != null && avatar.trim().isNotEmpty) ? avatar : null;
      _nicknameOverride = null;
      await _prefs?.setString(_kUser, jsonEncode(me.toJson()));
      final prefs = _prefs;
      if (prefs != null) {
        await prefs.remove(_kNickname);
        if (_avatarUrl != null) {
          await prefs.setString(_kAvatarUrl, _avatarUrl!);
        } else {
          await prefs.remove(_kAvatarUrl);
        }
      }
      notifyListeners();
    } on ApiException catch (e) {
      if (e.code == 10100) await _clearSession();
    }
  }

  /// 保存资料（`PUT /user/profile`，补丁式）：成功用服务端返回值刷新本地快照。
  /// 失败抛 [ApiException] 交给页面提示。
  Future<void> saveProfile({
    String? nickname,
    String? avatar,
    int? gender,
    String? birthday,
  }) async {
    final updated = await _users.updateProfile(
      nickname: nickname,
      avatar: avatar,
      gender: gender,
      birthday: birthday,
    );
    _user = updated;
    if (nickname != null) _nicknameOverride = null;
    final avatarFromServer = updated.avatar;
    _avatarUrl =
        (avatarFromServer != null && avatarFromServer.trim().isNotEmpty)
            ? avatarFromServer
            : (avatar ?? _avatarUrl);
    _avatarBytes = null;
    await _prefs?.setString(_kUser, jsonEncode(updated.toJson()));
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.remove(_kNickname);
      if (_avatarUrl != null) await prefs.setString(_kAvatarUrl, _avatarUrl!);
    }
    notifyListeners();
  }

  /// 修改密码（`PUT /user/password`）：成功后服务端撤销 refresh token，
  /// 因此调用方必须接着 [logout] 并回登录页。
  Future<void> changePassword(String oldPassword, String newPassword) =>
      _users.changePassword(oldPassword, newPassword);

  /// access 过期后由 [ApiClient] 回调：轮换 token 并返回新的 access
  Future<String?> _refreshSession() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) return null;
    try {
      final res = await _users.refresh(refreshToken);
      await _applyTokens(res.accessToken, res.refreshToken);
      return res.accessToken;
    } catch (_) {
      await _clearSession();
      return null;
    }
  }

  /// 启动校验：成功则顺手轮换一次 token，token 明确失效才登出
  Future<void> _validateSession() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) return;
    try {
      final res = await _users.refresh(refreshToken);
      await _applyTokens(res.accessToken, res.refreshToken);
    } on ApiException catch (e) {
      // -1 = 网络/连接失败（后端未启动、换网络），保留登录态等下次请求再试
      if (e.code != -1) await _clearSession();
    }
  }

  Future<void> _applyTokens(String accessToken, String refreshToken) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _api.accessToken = accessToken;
    await _writeSecret(_kAccessToken, accessToken);
    await _writeSecret(_kRefreshToken, refreshToken);
    notifyListeners();
  }

  // ---------- 敏感数据存储：安全存储优先，环境不支持时降级 ----------

  /// 读取 token：优先系统安全存储（iOS Keychain / Android Keystore）。
  /// 旧版本把 token 明文存在 SharedPreferences，首次读到就迁移并清掉明文。
  Future<String?> _readSecret(String key) async {
    if (!_secureUnavailable) {
      try {
        final value = await _secure.read(key: key);
        if (value != null) return value;
        final legacy = _prefs?.getString(key);
        if (legacy != null) {
          await _secure.write(key: key, value: legacy);
          await _prefs?.remove(key);
        }
        return legacy;
      } catch (_) {
        _secureUnavailable = true;
      }
    }
    return _prefs?.getString(key);
  }

  Future<void> _writeSecret(String key, String value) async {
    if (!_secureUnavailable) {
      try {
        await _secure.write(key: key, value: value);
        // 迁移完成后不再保留明文副本
        await _prefs?.remove(key);
        return;
      } catch (_) {
        _secureUnavailable = true;
      }
    }
    await _prefs?.setString(key, value);
  }

  Future<void> _deleteSecret(String key) async {
    if (!_secureUnavailable) {
      try {
        await _secure.delete(key: key);
      } catch (_) {
        _secureUnavailable = true;
      }
    }
    // 明文副本（含旧版本残留）一并清掉
    await _prefs?.remove(key);
  }

  Future<void> _clearSession() async {
    _loggedIn = false;
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    _nicknameOverride = null;
    _avatarUrl = null;
    _avatarBytes = null;
    _api.accessToken = null;
    _api.onRefresh = null;

    await _deleteSecret(_kAccessToken);
    await _deleteSecret(_kRefreshToken);
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.remove(_kUser);
      await prefs.remove(_kNickname);
      await prefs.remove(_kAvatarUrl);
    }
    notifyListeners();
  }
}
