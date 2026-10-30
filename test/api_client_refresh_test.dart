import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kqw_app/core/api_client.dart';

import 'support/fake_http_adapter.dart';

void main() {
  test('并发 401 只刷新一次：refresh token 不会被并发消费', () async {
    final adapter = FakeAdapter(staleTokenGuard);
    final client = ApiClient()..accessToken = 'stale';
    client.dio.httpClientAdapter = adapter;

    var refreshCalls = 0;
    client.onRefresh = () async {
      refreshCalls += 1;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return 'fresh';
    };

    final results = await Future.wait([
      client.get<Map<String, dynamic>>('/a'),
      client.get<Map<String, dynamic>>('/b'),
      client.get<Map<String, dynamic>>('/c'),
    ]);

    expect(refreshCalls, 1, reason: '并发 401 必须共用同一次刷新');
    expect(results.map((r) => r['ok']), everyElement(true));
    // 3 次首发（401）+ 3 次带新 token 的重放
    expect(adapter.requests.length, 6);
    expect(adapter.countOf('/a'), 2);
  });

  test('刷新接口自身 401 不再递归刷新，失败向上抛出', () async {
    final adapter = FakeAdapter(
      (options, attempt) async =>
          jsonResponse({'code': 10100, 'message': 'refresh 已失效'}, 401),
    );
    final client = ApiClient()..accessToken = 'stale';
    client.dio.httpClientAdapter = adapter;

    var refreshCalls = 0;
    client.onRefresh = () async {
      refreshCalls += 1;
      // 刷新通道自身不触发刷新回调；若这里被再次刷新，就是无限递归
      await client.postWithoutAuthRetry<Map<String, dynamic>>(
        '/user/refresh',
        body: {'refreshToken': 'r'},
      );
      return 'fresh';
    };

    await expectLater(
      client.get<Map<String, dynamic>>('/protected'),
      throwsA(isA<ApiException>()),
    );

    expect(refreshCalls, 1);
    expect(adapter.requests.length, 2, reason: '受保护请求 + 刷新请求，不应继续递归');
  });

  test('上传遇 401：multipart 请求体重建后重放成功，不抛 StateError', () async {
    final adapter = FakeAdapter(staleTokenGuard);
    final client = ApiClient()..accessToken = 'stale';
    client.dio.httpClientAdapter = adapter;
    client.onRefresh = () async => 'fresh';

    final res = await client.uploadImage(Uint8List.fromList([1, 2, 3]));

    expect(res['ok'], true);
    expect(adapter.requests.length, 2);
  });

  test('空响应：可空返回类型得到 null，非空类型抛 ApiException 而非 TypeError', () async {
    final adapter = FakeAdapter(
      // 后端 201 + 空体（兑换成功等场景）
      (options, attempt) async => jsonResponse(null, 201),
    );
    final client = ApiClient();
    client.dio.httpClientAdapter = adapter;

    await client.postVoid('/points/exchange');

    await expectLater(
      client.post<Map<String, dynamic>>('/points/exchange'),
      throwsA(isA<ApiException>()),
    );
  });

  test('没带鉴权头的 401 不触发刷新（登录密码错误不该轮换 token）', () async {
    final adapter = FakeAdapter(
      (options, attempt) async =>
          jsonResponse({'code': 10100, 'message': '手机号或密码错误'}, 401),
    );
    final client = ApiClient();
    client.dio.httpClientAdapter = adapter;

    var refreshCalls = 0;
    client.onRefresh = () async {
      refreshCalls += 1;
      return 'fresh';
    };

    await expectLater(
      client.post<Map<String, dynamic>>('/user/login', body: {'phone': '1'}),
      throwsA(isA<ApiException>()),
    );

    expect(refreshCalls, 0);
    expect(adapter.requests.length, 1);
  });
}
