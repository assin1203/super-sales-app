import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:kqw_app/core/app_router.dart';
import 'package:kqw_app/core/auth_provider.dart';
import 'package:kqw_app/core/theme.dart';
import 'package:kqw_app/features/home/home_tab.dart';

void main() {
  testWidgets('登录后首页正常渲染', (tester) async {
    final auth = AuthProvider();
    auth.init();
    await auth.loginPassword('13800000001', '123456');
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(theme: kqwTheme, routerConfig: appRouter(auth)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('积分礼包'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('会员等级进度'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('会员等级进度'), findsOneWidget);
  });

  testWidgets('登录后商城页正常渲染', (tester) async {
    final auth = AuthProvider();
    auth.init();
    await auth.loginPassword('13800000001', '123456');
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(theme: kqwTheme, routerConfig: appRouter(auth)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('商城'));
    await tester.pumpAndSettle();
    expect(find.text('积分商城'), findsOneWidget);
    expect(find.text('POS 收纳包'), findsOneWidget);
  });

  testWidgets('我的推荐页渲染（二维码 + 分享微信）', (tester) async {
    final auth = AuthProvider();
    auth.init();
    await auth.loginPassword('13800000001', '123456');
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(theme: kqwTheme, routerConfig: appRouter(auth)),
      ),
    );
    await tester.pumpAndSettle();
    final ctx = tester.element(find.byType(HomeTab));
    GoRouter.of(ctx).push('/referral');
    await tester.pumpAndSettle();
    expect(find.text('我的推荐码'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('分享到微信'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('分享到微信'), findsOneWidget);
  });

  testWidgets('我的机器页渲染（编号/开机时间/推荐/新手任务 + 添加按钮）', (tester) async {
    final auth = AuthProvider();
    auth.init();
    await auth.loginPassword('13800000001', '123456');
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(theme: kqwTheme, routerConfig: appRouter(auth)),
      ),
    );
    await tester.pumpAndSettle();
    final ctx = tester.element(find.byType(HomeTab));
    GoRouter.of(ctx).push('/machines');
    await tester.pumpAndSettle();
    expect(find.text('我的机器'), findsWidgets);
    expect(find.text('SN20261001'), findsOneWidget);
    expect(find.text('SN20261008'), findsOneWidget);
    expect(find.text('新手任务已完成'), findsOneWidget);
    expect(find.text('审核中'), findsOneWidget);
    expect(find.text('新手任务进行中'), findsOneWidget);
    expect(find.text('添加新机器'), findsOneWidget);
  });
}
