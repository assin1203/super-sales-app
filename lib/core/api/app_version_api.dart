import '../api_client.dart';
import '../models/app_version_info.dart';

/// App 版本检查接口（`/common/app/version`）。
///
/// **公开端点**：冷启动时用户可能还没登录，因此不带 token 也要能查。
/// 后端尚未上线该接口时会返回 404，调用方按「检查失败」静默放行，
/// 不能把用户挡在启动页外。
class AppVersionApi {
  AppVersionApi({ApiClient? client}) : _api = client ?? api;

  final ApiClient _api;

  /// 最新版本；服务端没有版本记录时返回 null
  Future<AppVersionInfo?> latest({
    required String platform,
    required int versionCode,
  }) async {
    final json = await _api.get<dynamic>(
      '/common/app/version',
      query: {'platform': platform, 'versionCode': '$versionCode'},
    );
    final body = _asMap(json);
    if (body == null) return null;
    // 兼容 `{latest: {...}}` / `{data: {...}}` 包一层的返回
    final inner = _asMap(body['latest']) ?? _asMap(body['data']) ?? body;
    final info = AppVersionInfo.fromJson(inner);
    // 没有 versionCode 说明服务端没配版本，按「无更新」处理
    return info.versionCode > 0 ? info : null;
  }

  Map<String, dynamic>? _asMap(Object? value) =>
      value is Map ? value.map((k, v) => MapEntry('$k', v)) : null;
}

final AppVersionApi appVersionApi = AppVersionApi();
