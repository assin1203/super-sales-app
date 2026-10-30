import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// 假 HTTP 适配器：记录每一次请求，按 [handler] 给出响应。
///
/// 用来在不打真实后端的前提下驱动 401 刷新、multipart 重放等链路。
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  /// attempt 为该请求在本次测试里的序号（从 1 开始）
  final Future<ResponseBody> Function(RequestOptions options, int attempt) handler;

  final List<RequestOptions> requests = [];

  /// 各路径被请求的次数，便于断言「没有重复刷新 / 没有递归」
  int countOf(String path) =>
      requests.where((r) => r.path == path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options, requests.length);
  }

  @override
  void close({bool force = false}) {}
}

/// JSON 响应体（后端成功/出错都返回 JSON）
ResponseBody jsonResponse(Object? data, int statusCode) => ResponseBody.fromString(
      jsonEncode(data),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// 鉴权守门：带 [freshToken] 的请求放行，其余一律 401
Future<ResponseBody> staleTokenGuard(
  RequestOptions options,
  int attempt, {
  String freshToken = 'Bearer fresh',
}) async {
  if (options.headers['Authorization'] == freshToken) {
    return jsonResponse({'path': options.path, 'ok': true}, 200);
  }
  return jsonResponse({'code': 10100, 'message': '登录已过期'}, 401);
}
