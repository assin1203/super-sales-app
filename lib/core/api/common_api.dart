import '../api_client.dart';

/// 共用接口（`/common/*`）：短信验证码、图片上传。
///
/// 短信为公开端点，防刷由服务端 Redis 冷却（60s）+ 每手机号每日上限保证，
/// 触发限流返回 429（前端映射为 12900「操作过于频繁」）。
class CommonApi {
  CommonApi({ApiClient? client}) : _api = client ?? api;

  final ApiClient _api;

  /// 发送短信验证码（验证码 5 分钟有效、校验成功即消费）
  Future<void> sendSms(String phone) =>
      _api.postVoid('/common/sms/send', body: {'phone': phone});

  /// 校验短信验证码
  Future<bool> verifySms(String phone, String code) async {
    final json = await _api.post<dynamic>(
      '/common/sms/verify',
      body: {'phone': phone, 'code': code},
    );
    // 服务端校验通过返回 true；兼容 {verified: true} 形状
    if (json is bool) return json;
    if (json is Map && json['verified'] is bool) return json['verified'] as bool;
    return true;
  }

  /// 上传图片（multipart 字段 `file`），返回 `{url, key, size}`
  Future<Map<String, dynamic>> uploadImage(List<int> bytes,
          {String filename = 'upload.png'}) =>
      _api.uploadImage(bytes, filename: filename);
}

final CommonApi commonApi = CommonApi();
