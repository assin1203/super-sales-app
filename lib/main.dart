import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/app_router.dart';
import 'core/app_update.dart';
import 'core/auth_provider.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 先恢复本地登录态再建路由：GoRouter 的 initialLocation 依赖 loggedIn，
  // 否则每次冷启动都会先闪一下登录页。
  final auth = AuthProvider();
  await auth.init();
  runApp(KqwApp(auth: auth));
}

class KqwApp extends StatefulWidget {
  const KqwApp({super.key, required this.auth, this.updater});

  final AuthProvider auth;

  /// 版本检查器（测试可注入；生产用全局 appUpdateChecker）
  final AppUpdateChecker? updater;

  @override
  State<KqwApp> createState() => _KqwAppState();
}

class _KqwAppState extends State<KqwApp> {
  /// 登录态与路由都只创建一次：GoRouter 若在 Consumer 的 builder 里新建，
  /// 任何 notifyListeners()（如 updateProfile）都会重建路由并把导航重置回 initialLocation。
  late final GoRouter _router = appRouter(widget.auth, navigatorKey: _navigatorKey);

  /// 根导航器：更新弹窗要挂在它下面，才不依赖当前停在哪个路由
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  late final AppUpdateChecker _updater = widget.updater ?? appUpdateChecker;

  @override
  void initState() {
    super.initState();
    // 冷启动查版本：首帧之后再发请求，既不拖慢启动，也不依赖登录态
    // （未登录停在登录页时同样要提示更新）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _navigatorKey.currentContext;
      if (context != null) _updater.check(context);
    });
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: widget.auth,
      child: MaterialApp.router(
        title: '超级展业',
        debugShowCheckedModeBanner: false,
        theme: kqwTheme,
        routerConfig: _router,
      ),
    );
  }
}
