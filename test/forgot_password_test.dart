import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kqw_app/core/api_client.dart';
import 'package:kqw_app/core/theme.dart';
import 'package:kqw_app/pages/forgot_password_page.dart';

import 'support/fake_http_adapter.dart';

/// 忘记密码页：手机号 + 短信验证码 + 新密码 → `POST /user/password/reset`
///
/// 滑块只拦「获取验证码」，提交环节不再校验拼图，因此本测试直接填码提交，
/// 覆盖请求体、两次密码一致性与服务端错误提示三条主链路。
void main() {
  FakeAdapter adapter({bool resetOk = true}) => FakeAdapter((options, attempt) async {
        if (options.path == '/common/sms/send') {
          return jsonResponse({'expireSeconds': 300}, 200);
        }
        if (options.path == '/user/password/reset') {
          if (resetOk) return jsonResponse({'ok': true}, 200);
          return jsonResponse({'code': 10001, 'message': '验证码错误或已过期'}, 400);
        }
        return jsonResponse({'code': 40400, 'message': '未打桩的请求'}, 404);
      });

  Future<void> pumpPage(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/forgot-password',
      routes: [
        GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordPage()),
        GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('登录页'))),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(theme: kqwTheme, routerConfig: router));
    await tester.pumpAndSettle();
  }

  /// 表单字段顺序：手机号 / 验证码 / 新密码 / 确认新密码
  Future<void> fillForm(
    WidgetTester tester, {
    String phone = '13800000001',
    String code = '123456',
    String pwd = 'NewPassw0rd',
    String? confirm,
  }) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), phone);
    await tester.enterText(fields.at(1), code);
    await tester.enterText(fields.at(2), pwd);
    await tester.enterText(fields.at(3), confirm ?? pwd);
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, '重置密码');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  setUp(() {
    api.dio.httpClientAdapter = adapter();
  });

  testWidgets('提交手机号+验证码+新密码 → POST /user/password/reset 并回登录页', (tester) async {
    await pumpPage(tester);
    await fillForm(tester);
    await submit(tester);

    final adapter = api.dio.httpClientAdapter as FakeAdapter;
    final reset = adapter.requests.where((r) => r.path == '/user/password/reset').toList();
    expect(reset, hasLength(1));
    expect(reset.single.data, {
      'phone': '13800000001',
      'code': '123456',
      'newPassword': 'NewPassw0rd',
    });
    expect(find.text('登录页'), findsOneWidget);
  });

  testWidgets('两次输入的新密码不一致 → 不发请求', (tester) async {
    await pumpPage(tester);
    await fillForm(tester, confirm: 'OtherPassw0rd');
    await submit(tester);

    final adapter = api.dio.httpClientAdapter as FakeAdapter;
    expect(adapter.countOf('/user/password/reset'), 0);
    expect(find.text('两次输入的新密码不一致'), findsOneWidget);
  });

  testWidgets('新密码强度不符（纯数字）→ 本地拦截，不发请求', (tester) async {
    await pumpPage(tester);
    await fillForm(tester, pwd: '12345678', confirm: '12345678');
    await submit(tester);

    final adapter = api.dio.httpClientAdapter as FakeAdapter;
    expect(adapter.countOf('/user/password/reset'), 0);
    expect(find.text('8~64 位，须同时包含字母和数字'), findsOneWidget);
  });

  testWidgets('服务端拒绝（验证码错误）→ 停留本页并提示', (tester) async {
    api.dio.httpClientAdapter = adapter(resetOk: false);
    await pumpPage(tester);
    await fillForm(tester);
    await submit(tester);

    expect(find.text('验证码错误或已过期'), findsOneWidget);
    // 没有跳登录页：提交按钮仍在
    expect(find.widgetWithText(FilledButton, '重置密码'), findsOneWidget);
  });
}
