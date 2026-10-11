import 'package:go_router/go_router.dart';

import '../features/home/home_tab.dart';
import '../features/mall/mall_tab.dart';
import '../features/me/me_tab.dart';
import '../features/task/task_tab.dart';
import '../features/team/team_tab.dart';
import '../pages/addresses_page.dart';
import '../pages/login_page.dart';
import '../pages/machines_page.dart';
import '../pages/orders_page.dart';
import '../pages/points_flow_page.dart';
import '../pages/referral_page.dart';
import '../pages/room_detail_page.dart';
import 'auth_provider.dart';
import 'shell_layout.dart';

/// 路由表：未登录 → /login；登录后进入底部导航壳
GoRouter appRouter(AuthProvider auth) {
  return GoRouter(
    initialLocation: auth.loggedIn ? '/' : '/login',
    refreshListenable: auth,
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => ShellLayout(child: child),
        routes: [
          GoRoute(path: '/', builder: (c, s) => const HomeTab()),
          GoRoute(path: '/mall', builder: (c, s) => const MallTab()),
          GoRoute(path: '/team', builder: (c, s) => const TeamTab()),
          GoRoute(path: '/tasks', builder: (c, s) => const TaskTab()),
          GoRoute(path: '/me', builder: (c, s) => const MeTab()),
        ],
      ),
      GoRoute(path: '/points-flow', builder: (c, s) => const PointsFlowPage()),
      GoRoute(path: '/orders', builder: (c, s) => const OrdersPage()),
      GoRoute(path: '/addresses', builder: (c, s) => const AddressesPage()),
      GoRoute(path: '/referral', builder: (c, s) => const ReferralPage()),
      GoRoute(path: '/machines', builder: (c, s) => const MachinesPage()),
      GoRoute(
        path: '/room/:roomId',
        builder: (c, s) => RoomDetailPage(roomId: s.pathParameters['roomId']!),
      ),
    ],
  );
}
