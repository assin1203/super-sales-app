import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/app_router.dart';
import 'core/auth_provider.dart';
import 'core/theme.dart';

void main() {
  runApp(const KqwApp());
}

class KqwApp extends StatefulWidget {
  const KqwApp({super.key});

  @override
  State<KqwApp> createState() => _KqwAppState();
}

class _KqwAppState extends State<KqwApp> {
  /// 登录态与路由都只创建一次：GoRouter 若在 Consumer 的 builder 里新建，
  /// 任何 notifyListeners()（如 updateProfile）都会重建路由并把导航重置回 initialLocation。
  final AuthProvider _auth = AuthProvider()..init();
  late final GoRouter _router = appRouter(_auth);

  @override
  void dispose() {
    _router.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: _auth,
      child: MaterialApp.router(
        title: '超级展业',
        debugShowCheckedModeBanner: false,
        theme: kqwTheme,
        routerConfig: _router,
      ),
    );
  }
}
