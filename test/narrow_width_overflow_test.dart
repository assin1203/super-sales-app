import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_secure_store.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kqw_app/core/app_router.dart';
import 'package:kqw_app/core/auth_provider.dart';
import 'package:kqw_app/core/theme.dart';

/// 窄宽度（360dp，最小常见手机 / 真机逻辑宽度）布局溢出检测。
///
/// 逐个渲染每个页面，整页滚动触发懒加载内容，捕获所有
/// `RenderFlex overflowed` 异常（含完整肇事组件树）。
/// 首页轮播含定时器动画，故全程使用有限次 pump + drag，
/// 不用 pumpAndSettle（会因轮播持续排帧而超时）。
void main() {
  const narrow = Size(360, 740);

  bool isOverflow(FlutterErrorDetails d) =>
      d.exception.toString().toLowerCase().contains('overflowed');

  /// 捕获 [body] 期间上报的全部 FlutterErrorDetails。
  /// （takeException 只带短消息，这里能拿到完整组件树。）
  Future<List<FlutterErrorDetails>> captureErrors(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    final captured = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      captured.add(details);
      // 非溢出错误走原流程（记入 binding，随后 takeException 清掉）
      if (!isOverflow(details)) previous?.call(details);
    };
    try {
      await body();
    } finally {
      FlutterError.onError = previous;
    }
    while (tester.takeException() != null) {}
    return captured;
  }

  /// 从屏幕下半固定点向上滚动 6 次，触发列表懒加载
  Future<void> scrollThrough(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.dragFrom(const Offset(180, 600), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  void expectNoOverflow(String route, List<FlutterErrorDetails> errors) {
    final overflows = errors.where(isOverflow).toList();
    final others = errors.where((d) => !isOverflow(d)).toList();
    if (others.isNotEmpty) {
      // 非溢出异常单独打印，不阻断本测试（可能是 mock/网络相关）
      debugPrint('[non-overflow @ $route]\n'
          '${others.map((d) => d.exception).join('\n---\n')}');
    }
    expect(
      overflows,
      isEmpty,
      reason: '窄宽度($route) 检测到溢出：\n'
          '${overflows.map((d) => d.toString()).join('\n---\n')}',
    );
  }

  /// 渲染 App 壳并返回 router（未登录也可渲染，用于纯布局检测）。
  ///
  /// 不再依赖 mock 登录：登录已经接真实后端，测试里不发起认证请求；
  /// 各页面本身没有登录态守卫，直接 go 到目标路由即可。
  Future<GoRouter> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthProvider(secureStore: MemorySecureStore());
    await auth.init();
    final router = appRouter(auth);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(theme: kqwTheme, routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();
    return router;
  }

  final routes = [
    '/',
    '/mall',
    '/me',
    '/team',
    '/tasks',
    '/points',
    '/points/transfer',
    '/points-flow',
    '/orders',
    '/addresses',
    '/referral',
    '/profile',
    '/machines',
    '/room/1',
  ];

  for (final route in routes) {
    testWidgets('窄宽度 $route 无溢出', (tester) async {
      tester.view.physicalSize = narrow;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final errors = await captureErrors(tester, () async {
        final router = await pumpApp(tester);
        if (route != '/') {
          router.go(route);
          await tester.pump();
        }
        await scrollThrough(tester);
      });
      expectNoOverflow(route, errors);
    });
  }

  testWidgets('窄宽度 /login 无溢出', (tester) async {
    tester.view.physicalSize = narrow;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final auth = AuthProvider(secureStore: MemorySecureStore()); // 未登录 → 初始页 /login
    await auth.init();
    final errors = await captureErrors(tester, () async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp.router(theme: kqwTheme, routerConfig: appRouter(auth)),
        ),
      );
      await tester.pump();
      await tester.pump();
      await scrollThrough(tester);
    });
    expectNoOverflow('/login', errors);
  });
}
