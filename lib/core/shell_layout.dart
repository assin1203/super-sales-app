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

/// 底部导航：只保留 首页 / 商城 / 我的，其余功能入口均收进「我的」。
class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  static const _items = [
    (path: '/', icon: Icons.home_outlined, active: Icons.home, label: '首页'),
    (path: '/mall', icon: Icons.storefront_outlined, active: Icons.storefront, label: '商城'),
    (path: '/me', icon: Icons.person_outline, active: Icons.person, label: '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    var currentIndex = _items.indexWhere(
      (i) => location == i.path || location.startsWith('${i.path}/'),
    );
    if (currentIndex < 0) currentIndex = 0;
    return BottomNavigationBar(
      currentIndex: currentIndex,
      items: _items
          .map((i) => BottomNavigationBarItem(icon: Icon(i.icon), activeIcon: Icon(i.active), label: i.label))
          .toList(),
      onTap: (i) => context.go(_items[i].path),
    );
  }
}
