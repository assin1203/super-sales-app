import 'dart:typed_data';

import 'package:flutter/material.dart';

/// 登录态（骨架：用户名密码登录，JWT 由 server 签发）。
/// TODO: 持久化 token（shared_preferences / flutter_secure_storage）
class AuthProvider extends ChangeNotifier {
  bool _loggedIn = false;
  String? _token;
  int? _userId;
  String? _name;
  Uint8List? _avatarBytes; // 裁剪后的头像字节，null 表示用默认头像

  bool get loggedIn => _loggedIn;
  String? get token => _token;
  int? get userId => _userId;
  String? get name => _name;
  Uint8List? get avatarBytes => _avatarBytes;

  /// 修改个人资料；name / avatarBytes 传 null 表示不变更该字段，name 传空串表示清空昵称
  void updateProfile({String? name, Uint8List? avatarBytes}) {
    if (name != null) _name = name.trim().isEmpty ? null : name.trim();
    if (avatarBytes != null) _avatarBytes = avatarBytes;
    notifyListeners();
  }

  void init() {
    // TODO: 从本地安全存储恢复 token 并校验
  }

  /// 手机号 + 密码登录；mock 模式直接置登录态
  Future<bool> loginPassword(String phone, String password) async {
    // TODO: api.post('/auth/login', body: {phone, password}) → token/userId
    _token = 'mock-token';
    _userId = 1;
    _name = _maskedPhone(phone);
    _loggedIn = true;
    notifyListeners();
    return true;
  }

  /// 手机号脱敏展示：138****0001
  String _maskedPhone(String phone) =>
      phone.length >= 7
          ? '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}'
          : phone;

  void logout() {
    _token = null;
    _userId = null;
    _name = null;
    _avatarBytes = null;
    _loggedIn = false;
    notifyListeners();
  }
}
