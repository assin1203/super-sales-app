import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kqw_app/core/api_client.dart';
import 'package:kqw_app/core/auth_provider.dart';
import 'package:kqw_app/core/theme.dart';
import 'package:kqw_app/pages/login_page.dart';

import 'support/fake_http_adapter.dart';
import 'support/memory_secure_store.dart';

/// 登录页双形态：密码 / 短信验证码（验证码走 `/user/login/code`）
void main() {
  final calls = <RequestOptions>[];

  /// 默认桩：验证码发送与验证码登录都成功
  FakeAdapter okAdapter() => FakeAdapter((options, attempt) async {
        calls.add(options);
        if (options.path == '/common/sms/send') {
          return jsonResponse({'expireSeconds': 300}, 200);
        }
        if (options.path == '/user/login/code') {
          return jsonResponse({
            'accessToken': 'access-token',
            'refreshToken': 'refresh-token',
            'user': {'id': '1', 'phone': '13800000001', 'nickname': '张三', 'level': 1},
          }, 200);
        }
        return jsonResponse({'code': 40400, 'message': '未打桩的请求'}, 404);
      });

  setUp(() {
    calls.clear();
    api.dio.httpClientAdapter = okAdapter();
  });

  Future<AuthProvider> pumpLogin(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthProvider(secureStore: MemorySecureStore());
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
        GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('首页'))),
      ],
    );
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp.router(theme: kqwTheme, routerConfig: router),
    ));
    await tester.pumpAndSettle();
    return auth;
  }

  Future<void> switchToCodeMode(WidgetTester tester) async {
    await tester.tap(find.text('验证码登录'));
    await tester.pumpAndSettle();
  }

  /// 登录页内容高于测试默认视口（800x600），点击前先滚动到可见
  Future<void> tapVisible(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('验证码登录：手机号 + 验证码提交到 /user/login/code 并进入首页', (tester) async {
    final auth = await pumpLogin(tester);
    await switchToCodeMode(tester);

    // 验证码形态下不再有密码框
    expect(find.text('密码'), findsNothing);
    expect(find.text('获取验证码'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '13800000001');
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tapVisible(tester, '登录 / 注册');

    final login = calls.where((c) => c.path == '/user/login/code').toList();
    expect(login, hasLength(1));
    expect(login.single.data, {'phone': '13800000001', 'code': '123456'});
    expect(auth.user?.phone, '13800000001');
    expect(find.text('首页'), findsOneWidget);
  });

  testWidgets('获取验证码：未过滑块时提示且不发请求', (tester) async {
    await pumpLogin(tester);
    await switchToCodeMode(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '13800000001');
    await tester.tap(find.text('获取验证码'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('请先完成滑块验证'), findsOneWidget);
    expect(calls.where((c) => c.path == '/common/sms/send'), isEmpty);
  });

  testWidgets('未注册手机号：展示服务端文案并停留在登录页', (tester) async {
    await pumpLogin(tester);
    api.dio.httpClientAdapter = FakeAdapter((options, attempt) async {
      calls.add(options);
      if (options.path == '/user/login/code') {
        return jsonResponse({'code': 20001, 'message': '该手机号未注册，请先注册'}, 404);
      }
      return jsonResponse({'code': 40400, 'message': '未打桩的请求'}, 404);
    });
    await switchToCodeMode(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '13900000002');
    await tester.enterText(find.byType(TextFormField).at(1), '654321');
    await tapVisible(tester, '登录 / 注册');

    expect(find.text('该手机号未注册，请先注册'), findsOneWidget);
    expect(find.text('首页'), findsNothing);
  });
}
