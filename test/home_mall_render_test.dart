import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kqw_app/core/app_router.dart';
import 'package:kqw_app/core/auth_provider.dart';
import 'package:kqw_app/core/theme.dart';
import 'package:kqw_app/features/home/home_tab.dart';

import 'support/memory_secure_store.dart';

void main() {
  /// 注入本地登录态（token + 用户快照）后渲染 App。
  ///
  /// 登录接口已接真实后端，测试里不再发认证请求；init() 的静默续期在
  /// 测试环境会失败（flutter_test 的 HttpClient 固定返回 400），
  /// 网络类失败不会清登录态，因此这里能稳定拿到已登录状态。
  Future<void> pumpLoggedInApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'kqw.access_token': 'test-access',
      'kqw.refresh_token': 'test-refresh',
      'kqw.user': jsonEncode({
        'id': '1',
        'phone': '13800000001',
        'nickname': null,
        'level': 1,
      }),
    });
    final auth = AuthProvider(secureStore: MemorySecureStore());
    await auth.init();
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(theme: kqwTheme, routerConfig: appRouter(auth)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('登录后首页正常渲染', (tester) async {
    await pumpLoggedInApp(tester);
    // 入房档位与积分礼包已从首页下线，房间统一从「我的团队」进入
    expect(find.text('积分礼包'), findsNothing);
    expect(find.text('购买升级礼包'), findsNothing);
    await tester.scrollUntilVisible(find.text('会员等级'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('会员等级'), findsOneWidget);
  });

  testWidgets('登录后商城页正常渲染', (tester) async {
    await pumpLoggedInApp(tester);
    await tester.tap(find.text('商城'));
    await tester.pumpAndSettle();
    expect(find.text('积分商城'), findsOneWidget);
    // 商品来自 GET /mall/products（测试环境请求失败 → 空态/错误态），
    // 这里只校验页架结构，商品内容由后端数据决定。
    expect(find.text('全部'), findsOneWidget);
  });

  testWidgets('我的推荐页渲染（推广码 + 分享入口）', (tester) async {
    await pumpLoggedInApp(tester);
    final ctx = tester.element(find.byType(HomeTab));
    GoRouter.of(ctx).push('/referral');
    await tester.pumpAndSettle();
    expect(find.text('推广中心'), findsOneWidget);
    expect(find.text('我的推广码'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('复制推广链接'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('复制推广链接'), findsOneWidget);
  });

  testWidgets('登录后首页展示申请 POS 机入口', (tester) async {
    await pumpLoggedInApp(tester);
    expect(find.text('申请 POS 机'), findsOneWidget);
    expect(find.text('立即申请'), findsOneWidget);

    // 点入口进申请表单页
    await tester.tap(find.text('立即申请'));
    await tester.pumpAndSettle();
    expect(find.text('联系人'), findsOneWidget);
    // 使用人标记：自己用 / 他人用
    expect(find.text('自己使用'), findsOneWidget);
    expect(find.text('他人使用'), findsOneWidget);
    await tester.tap(find.text('他人使用'));
    await tester.pumpAndSettle();
    expect(find.text('他人使用'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('提交申请'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('提交申请'), findsOneWidget);
  });

  testWidgets('我的机器页渲染（页面骨架，无添加按钮）', (tester) async {
    await pumpLoggedInApp(tester);
    final ctx = tester.element(find.byType(HomeTab));
    GoRouter.of(ctx).push('/machines');
    await tester.pumpAndSettle();
    expect(find.text('我的机器'), findsWidgets);
    // 机器数据来自 GET /pos/machines（测试环境请求失败），
    // 只校验页架；申请入口已收敛到首页，本页不再有悬浮添加按钮。
    expect(find.text('已提交'), findsOneWidget);
    expect(find.text('已安装'), findsOneWidget);
    expect(find.text('添加新机器'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
