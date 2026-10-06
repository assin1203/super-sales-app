import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 底部导航壳（ShellRoute 的 child 由 GoRouter 按路由切换）。
/// 独立文件避免 main.dart 与 app_router.dart 循环依赖。
class ShellLayout extends StatelessWidget {
  const ShellLayout({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const BottomNav(),
    );
  }
}

class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  static const _items = [
    (path: '/', icon: Icons.home_outlined, active: Icons.home, label: '首页'),
    (path: '/mall', icon: Icons.storefront_outlined, active: Icons.storefront, label: '商城'),
    (path: '/team', icon: Icons.account_tree_outlined, active: Icons.account_tree, label: '团队'),
    (path: '/tasks', icon: Icons.task_alt_outlined, active: Icons.task_alt, label: '任务'),
    (path: '/me', icon: Icons.person_outline, active: Icons.person, label: '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _items.indexWhere((i) => location.startsWith(i.path));
    return BottomNavigationBar(
      currentIndex: currentIndex < 0 ? 0 : currentIndex,
      type: BottomNavigationBarType.fixed,
      items: _items
          .map((i) => BottomNavigationBarItem(icon: Icon(i.icon), activeIcon: Icon(i.active), label: i.label))
          .toList(),
      onTap: (i) => context.go(_items[i].path),
    );
  }
}
