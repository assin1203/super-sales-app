import 'package:dio/dio.dart';

/// 后端地址。
///
/// 默认指向生产环境：`https://zhy-api.citykafei.com` 的根路径就是后端
/// （无 `/appApi`、`/api` 之类前缀，CORS 已放通）。本地联调时用
/// `flutter run --dart-define=API_BASE_URL=http://<ip>:3000` 覆盖。
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://zhy-api.citykafei.com',
);

/// 后端业务错误。
///
/// 后端**成功**响应直接返回数据体；只有出错才包一层
/// `{code, message, data, path, timestamp}`，这里统一还原成异常。
class ApiException implements Exception {
  ApiException(this.code, this.message, {this.details});

  /// 业务错误码：10000 参数格式错、10001 校验失败、10100 未登录、70001 短信发送失败
  final int code;
  final String message;

  /// 字段级校验明细（后端 `data.details`）
  final List<String>? details;

  /// 优先展示字段明细，比笼统的「参数校验失败」更有用
  String get displayMessage =>
      details != null && details!.isNotEmpty ? details!.first : message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({String baseUrl = apiBaseUrl, Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 20),
                contentType: Headers.jsonContentType,
                responseType: ResponseType.json,
              ),
            );

  final Dio _dio;

  /// 底层 Dio：测试里换 httpClientAdapter 打桩，业务代码不该直接用它
  Dio get dio => _dio;

  /// 当前 access token，由 AuthProvider 维护
  String? accessToken;

  /// 401 时回调刷新，返回新 token；返回 null 表示刷新失败（调用方应登出）
  Future<String?> Function()? onRefresh;

  /// 进行中的刷新：并发 401 共用同一次轮换。
  ///
  /// refresh token 是一次性消费的，多个请求各自刷新会让后到者被服务端判为
  /// 失效并清空登录态（用户表现为「莫名被登出」）。
  Future<String?>? _refreshing;

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      _request<T>('GET', path, query: query);

  Future<T> post<T>(String path, {Object? body}) =>
      _request<T>('POST', path, body: body);

  /// 刷新 token 的专用通道。
  ///
  /// 刷新接口自身返回 401 时不能再去刷新，否则「刷新失败 → 再刷新」无限递归，
  /// 调用方永远等不到失败结果。
  Future<T> postWithoutAuthRetry<T>(String path, {Object? body}) =>
      _request<T>('POST', path, body: body, allowRefresh: false);

  Future<T> put<T>(String path, {Object? body}) =>
      _request<T>('PUT', path, body: body);

  Future<T> delete<T>(String path) => _request<T>('DELETE', path);

  /// 无返回体的写接口（如兑换成功返回 201 + 空响应）
  Future<void> postVoid(String path, {Object? body}) async {
    await _request<dynamic>('POST', path, body: body);
  }

  /// 无返回体的 PUT（如 PUT /user/password 返回 200 空体）
  Future<void> putVoid(String path, {Object? body}) async {
    await _request<dynamic>('PUT', path, body: body);
  }

  /// 无返回体的 DELETE（如删除收货地址返回 200 空体）
  Future<void> deleteVoid(String path) async {
    await _request<dynamic>('DELETE', path);
  }

  /// 上传图片（multipart，字段名 `file`），返回 `{url, key, size}`
  ///
  /// 服务端按 part 的 Content-Type 先做 MIME 白名单，再按文件头嗅探真实类型，
  /// 因此这里显式声明图片类型，不依赖 dio 的默认 octet-stream。
  Future<Map<String, dynamic>> uploadImage(
    List<int> bytes, {
    String filename = 'upload.png',
    DioMediaType? contentType,
  }) async {
    // FormData 的流只能被消费一次：401 重放时用同一构造重建，否则 dio 抛 StateError
    FormData buildForm() => FormData.fromMap({
          'file': MultipartFile.fromBytes(
            bytes,
            filename: filename,
            contentType: contentType ?? DioMediaType('image', 'png'),
          ),
        });
    return _request<Map<String, dynamic>>(
      'POST',
      '/common/upload/image',
      body: buildForm(),
      rebuildBody: buildForm,
    );
  }

  Future<T> _request<T>(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    /// 重放时重建请求体（multipart 的 FormData 只能被消费一次）
    Object? Function()? rebuildBody,

    /// false 表示本次请求的 401 不再触发刷新（刷新接口自身用）
    bool allowRefresh = true,
    bool retried = false,
  }) async {
    try {
      final res = await _dio.request<dynamic>(
        path,
        data: retried ? (rebuildBody?.call() ?? body) : body,
        queryParameters: query,
        options: Options(method: method, headers: _headers()),
      );
      final dynamic data = res.data;
      // 空响应（如 201 兑换成功）：可空返回类型按 null 处理，
      // 非空返回类型说明服务端契约不符，抛 ApiException 而不是 TypeError。
      if (data == null) {
        if (data is T) return data;
        throw ApiException(-1, '服务端未返回数据，请稍后重试');
      }
      return data as T;
    } on DioException catch (e) {
      // accessToken 为空说明这条请求没带鉴权头，刷新也救不回来（如登录 401）
      if (e.response?.statusCode == 401 &&
          !retried &&
          allowRefresh &&
          accessToken != null) {
        final fresh = await _refreshOnce();
        if (fresh != null) {
          accessToken = fresh;
          return _request<T>(
            method,
            path,
            query: query,
            body: body,
            rebuildBody: rebuildBody,
            retried: true,
          );
        }
      }
      throw _error(e);
    }
  }

  /// 复用进行中的刷新，没有才发起一次
  Future<String?> _refreshOnce() {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight;
    final future = _runRefresh();
    _refreshing = future;
    return future;
  }

  Future<String?> _runRefresh() async {
    try {
      return await onRefresh?.call();
    } finally {
      _refreshing = null;
    }
  }

  Map<String, String> _headers() {
    final token = accessToken;
    return token == null ? const {} : {'Authorization': 'Bearer $token'};
  }

  ApiException _error(DioException e) {
    final payload = e.response?.data;
    if (payload is Map) {
      final code = (payload['code'] as num?)?.toInt() ?? -1;
      final message = payload['message'] as String? ?? '请求失败';
      List<String>? details;
      final data = payload['data'];
      if (data is Map && data['details'] is List) {
        details = (data['details'] as List).map((x) => '$x').toList();
      }
      return ApiException(code, message, details: details);
    }
    // 非 JSON 响应（网关错误、空响应等）：e.message 是 dio 的英文开发者文案，
    // 不能直接展示给用户，按状态码给中文文案。
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return ApiException(-1, '无法连接服务器，请检查网络或后端是否已启动');
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 429) return ApiException(12900, '操作过于频繁，请稍后再试');
        if (status >= 500) return ApiException(-1, '服务器开小差了，请稍后再试');
        return ApiException(-1, '请求失败（HTTP $status）');
      default:
        return ApiException(-1, '网络异常，请稍后重试');
    }
  }
}

final ApiClient api = ApiClient();
