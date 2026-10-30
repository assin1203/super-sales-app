import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kqw_app/core/api/user_api.dart';
import 'package:kqw_app/core/api_client.dart';
import 'package:kqw_app/core/app_router.dart';
import 'package:kqw_app/core/auth_provider.dart';
import 'package:kqw_app/core/theme.dart';
import 'package:kqw_app/core/token_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_http_adapter.dart';
import 'support/memory_secure_store.dart';

/// 用假适配器装配一套 AuthProvider（走真实 ApiClient 的 401/刷新逻辑）。
///
/// secureStore 必须注入内存实现：平台通道在 testWidgets 的 fake async 里
/// 不会完成，真实现会让 init() 里的 token 读取永远挂住。
AuthProvider _authWith(FakeAdapter adapter, {SecureStore? secureStore}) {
  final client = ApiClient();
  client.dio.httpClientAdapter = adapter;
  return AuthProvider(
    client: client,
    users: UserApi(client: client),
    secureStore: secureStore ?? MemorySecureStore(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'kqw.access_token': 'stale-access',
      'kqw.refresh_token': 'stale-refresh',
      'kqw.user': '{"id":"1","phone":"13800000001","nickname":null,"level":1}',
    });
  });

  test('冷启动续期失败（refresh 401）：自动登出并清掉本地 token', () async {
    final adapter = FakeAdapter(
      (options, attempt) async =>
          jsonResponse({'code': 10100, 'message': '登录已失效'}, 401),
    );
    final auth = _authWith(adapter);

    await auth.init();
    expect(auth.loggedIn, isTrue, reason: 'init 先用本地 token 恢复登录态');
    await pumpEventQueue();

    expect(auth.loggedIn, isFalse);
    expect(auth.token, isNull);
    expect(adapter.countOf('/user/refresh'), 1, reason: '刷新失败只尝试一次，不递归');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('kqw.access_token'), isNull);
    expect(prefs.getString('kqw.refresh_token'), isNull);
  });

  test('冷启动续期成功：保持登录并换上新 access token', () async {
    final adapter = FakeAdapter(
      (options, attempt) async => jsonResponse(
        {'accessToken': 'new-access', 'refreshToken': 'new-refresh'},
        200,
      ),
    );
    final store = MemorySecureStore();
    final auth = _authWith(adapter, secureStore: store);

    await auth.init();
    await pumpEventQueue();

    expect(auth.loggedIn, isTrue);
    expect(auth.token, 'new-access');
    expect(store.values['kqw.access_token'], 'new-access');
    expect(adapter.countOf('/user/refresh'), 1);
  });

  test('旧版本明文 token 迁移到安全存储，SharedPreferences 不留明文', () async {
    final adapter = FakeAdapter(
      (options, attempt) async =>
          jsonResponse({'accessToken': 'a1', 'refreshToken': 'r1'}, 200),
    );
    final store = MemorySecureStore();
    final auth = _authWith(adapter, secureStore: store);

    await auth.init();
    await pumpEventQueue();

    expect(auth.loggedIn, isTrue);
    expect(store.values['kqw.access_token'], 'a1', reason: '新 token 落在安全存储');
    expect(store.values['kqw.refresh_token'], 'r1');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('kqw.access_token'), isNull, reason: '明文副本必须清掉');
    expect(prefs.getString('kqw.refresh_token'), isNull);
  });

  test('安全存储不可用时降级到 SharedPreferences，登录态不丢', () async {
    final adapter = FakeAdapter(
      (options, attempt) async =>
          jsonResponse({'accessToken': 'a2', 'refreshToken': 'r2'}, 200),
    );
    final auth = _authWith(adapter, secureStore: UnavailableSecureStore());

    await auth.init();
    await pumpEventQueue();

    expect(auth.loggedIn, isTrue);
    expect(auth.token, 'a2');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('kqw.access_token'), 'a2', reason: '降级后写回明文存储');
  });

  testWidgets('未登录时首屏落在登录页', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // 这里不调 init()：testWidgets 是 fake async，平台通道永远等不到响应。
    // 默认构造即「未登录」，足以渲染登录页。
    final auth = AuthProvider(secureStore: MemorySecureStore());

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(theme: kqwTheme, routerConfig: appRouter(auth)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('超级展业'), findsOneWidget);
    expect(find.text('登录'), findsWidgets);
  });
}
