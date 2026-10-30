import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/app_router.dart';
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
  const KqwApp({super.key, required this.auth});

  final AuthProvider auth;

  @override
  State<KqwApp> createState() => _KqwAppState();
}

class _KqwAppState extends State<KqwApp> {
  /// 登录态与路由都只创建一次：GoRouter 若在 Consumer 的 builder 里新建，
  /// 任何 notifyListeners()（如 updateProfile）都会重建路由并把导航重置回 initialLocation。
  late final GoRouter _router = appRouter(widget.auth);

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
