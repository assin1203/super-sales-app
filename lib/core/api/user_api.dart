import '../api_client.dart';
import '../models/invite.dart';
import '../models/page_result.dart';
import '../models/points_summary.dart';
import '../models/user_info.dart';

/// 登录成功返回的双 token（access 2h 无状态 / refresh 30d 轮换）
class LoginResult {
  const LoginResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final UserInfo user;
}

/// 刷新结果：access 与 refresh 一起轮换，旧的 refresh 立即作废
class RefreshResult {
  const RefreshResult({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

/// 注册结果：新账号 + 推广码
class RegisterResult {
  const RegisterResult({required this.user, required this.inviteCode});

  final UserInfo user;
  final String inviteCode;
}

/// 推荐祖先链节点（GET /user/ancestors）
class AncestorNode {
  const AncestorNode({required this.id, required this.level});

  final String id;

  /// 层级：1 直属 / 2 / 3
  final int level;

  factory AncestorNode.fromJson(Map<String, dynamic> json) => AncestorNode(
        id: '${json['id'] ?? ''}',
        level: (json['level'] as num?)?.toInt() ?? 1,
      );
}

/// C 端用户接口（`/user/*`）。
///
/// 字段与返回结构以服务端 `user.service.ts` / `invite.service.ts` 的
/// `UserProfile` / `UserPointSummary` / `InviteSummary` 为准。
class UserApi {
  UserApi({ApiClient? client}) : _api = client ?? api;

  final ApiClient _api;

  /// 手机号 + 密码登录（公开端点，失败统一 401「手机号或密码错误」）
  Future<LoginResult> login(String phone, String password) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/user/login',
      body: {'phone': phone, 'password': password},
    );
    return _loginResult(json);
  }

  /// 短信验证码登录（公开端点，验证码先由 `/common/sms/send` 下发）
  ///
  /// 未注册 → 20001「该手机号未注册，请先注册」；验证码错误/过期 → 400；
  /// 失败次数过多 → 429（服务端作废该验证码，需重新获取）
  Future<LoginResult> loginByCode(String phone, String code) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/user/login/code',
      body: {'phone': phone, 'code': code},
    );
    return _loginResult(json);
  }

  /// 两种登录方式返回同一个结构（access + refresh + user）
  LoginResult _loginResult(Map<String, dynamic> json) => LoginResult(
        accessToken: json['accessToken'] as String? ?? '',
        refreshToken: json['refreshToken'] as String? ?? '',
        user: UserInfo.fromJson((json['user'] as Map).cast<String, dynamic>()),
      );

  /// 注册（公开端点）：手机号已存在 → 409，推广码无效 → 400
  Future<RegisterResult> register(
    String phone,
    String password, {
    String? inviteCode,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/user/register',
      body: {
        'phone': phone,
        'password': password,
        if (inviteCode != null && inviteCode.isNotEmpty) 'inviteCode': inviteCode,
      },
    );
    return RegisterResult(
      user: UserInfo.fromJson((json['user'] as Map).cast<String, dynamic>()),
      inviteCode: json['inviteCode'] as String? ?? '',
    );
  }

  /// 刷新轮换：旧 refresh 换新的 access + refresh
  ///
  /// 走 [ApiClient.postWithoutAuthRetry]：刷新接口自己返回 401 时不能再触发刷新，
  /// 否则 ApiClient 的 401 回调会重新进入本方法，无限递归。
  Future<RefreshResult> refresh(String refreshToken) async {
    final json = await _api.postWithoutAuthRetry<Map<String, dynamic>>(
      '/user/refresh',
      body: {'refreshToken': refreshToken},
    );
    return RefreshResult(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
    );
  }

  /// 登出：撤销 refresh（access 无状态，自然到期）
  Future<void> logout(String refreshToken) =>
      _api.postVoid('/user/logout', body: {'refreshToken': refreshToken});

  /// 完整个人资料（需 app token；冷启动校验登录态时调用）
  Future<UserInfo> me() async {
    final json = await _api.get<Map<String, dynamic>>('/user/me');
    return UserInfo.fromJson(json);
  }

  /// 修改资料（补丁式）：只传要改的字段，返回更新后的完整资料
  Future<UserInfo> updateProfile({
    String? nickname,
    String? avatar,
    int? gender,
    String? birthday,
  }) async {
    final json = await _api.put<Map<String, dynamic>>(
      '/user/profile',
      body: {
        if (nickname != null) 'nickname': nickname,
        if (avatar != null) 'avatar': avatar,
        if (gender != null) 'gender': gender,
        if (birthday != null) 'birthday': birthday,
      },
    );
    return UserInfo.fromJson(json);
  }

  /// 积分概览（商城/流水页顶部横幅）
  Future<PointsSummary> points() async {
    final json = await _api.get<Map<String, dynamic>>('/user/points');
    return PointsSummary.fromJson(json);
  }

  /// 推荐祖先链：`[{ id, level }]`，最多 3 级
  Future<List<AncestorNode>> ancestors() async {
    final list = await _api.get<List<dynamic>>('/user/ancestors');
    return list
        .whereType<Map>()
        .map((e) => AncestorNode.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// 推广码与邀请统计
  Future<InviteSummary> invite() async {
    final json = await _api.get<Map<String, dynamic>>('/user/invite');
    return InviteSummary.fromJson(json);
  }

  /// 邀请记录（分页，按注册时间倒序）
  Future<PageResult<InviteRecord>> inviteRecords({
    int pageNum = 1,
    int pageSize = 20,
  }) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/user/invite/records',
      query: {'pageNum': '$pageNum', 'pageSize': '$pageSize'},
    );
    return PageResult.fromJson(json, InviteRecord.fromJson);
  }

  /// 本人改密：成功返回 200 空体，服务端会撤销 refresh token（需重新登录）
  Future<void> changePassword(String oldPassword, String newPassword) =>
      _api.putVoid(
        '/user/password',
        body: {'oldPassword': oldPassword, 'newPassword': newPassword},
      );
}

final UserApi userApi = UserApi();
