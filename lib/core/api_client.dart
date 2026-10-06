import 'package:dio/dio.dart';

/// API 客户端（对接 server :3000）。
/// USE_MOCK=true 时走本地 mock，页面可独立开发（对齐 admin 后台约定）。
const bool useMock = true;

class ApiClient {
  ApiClient() : _dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000', connectTimeout: const Duration(seconds: 10))) {
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      // TODO: 登录态注入 Authorization: Bearer <token>
      handler.next(options);
    }));
  }

  final Dio _dio;

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) async {
    if (useMock) return (await _mock()) as T;
    final res = await _dio.get(path, queryParameters: query);
    return res.data as T;
  }

  Future<T> post<T>(String path, {Object? body}) async {
    if (useMock) return (await _mock()) as T;
    final res = await _dio.post(path, data: body);
    return res.data as T;
  }

  Future<dynamic> _mock() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {'mock': true};
  }
}

final ApiClient api = ApiClient();
