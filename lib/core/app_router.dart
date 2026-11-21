import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_tab.dart';
import '../features/mall/mall_tab.dart';
import '../features/me/me_tab.dart';
import '../features/task/task_tab.dart';
import '../features/team/team_tab.dart';
import '../pages/add_machine_page.dart';
import '../pages/addresses_page.dart';
import '../pages/apply_machine_page.dart';
import '../pages/forgot_password_page.dart';
import '../pages/login_page.dart';
import '../pages/machines_page.dart';
import '../pages/message_detail_page.dart';
import '../pages/messages_page.dart';
import '../pages/orders_page.dart';
import '../pages/packages_page.dart';
import '../pages/password_page.dart';
import '../pages/points_center_page.dart';
import '../pages/points_flow_page.dart';
import '../pages/points_transfer_page.dart';
import '../pages/profile_page.dart';
import '../pages/referral_page.dart';
import '../pages/room_detail_page.dart';
import '../pages/settings_page.dart';
import '../pages/trade_password_page.dart';
import '../pages/phone_rebind_page.dart';
import '../pages/my_team_page.dart';
import 'auth_provider.dart';
import 'shell_layout.dart';

/// 路由表：未登录 → /login；登录后进入底部导航壳
///
/// [navigatorKey] 供启动时的「发现新版本」弹窗使用：main.dart 拿它的 context
/// 才能在任何页面（含登录页）之上弹出对话框。
/// [enableDialogs] 透传给 [ShellLayout]：控制冷启动/回前台的升级提示与机器达标确认
/// 两个自动弹窗（默认关闭，测试里传 true 以覆盖弹窗链路）。
GoRouter appRouter(
  AuthProvider auth, {
  GlobalKey<NavigatorState>? navigatorKey,
  bool enableDialogs = false,
}) {
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: auth.loggedIn ? '/' : '/login',
    refreshListenable: auth,
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      // 忘记密码：登录页「忘记密码？」进入，未登录可用
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => ShellLayout(enableDialogs: enableDialogs, child: child),
        routes: [
          GoRoute(path: '/', builder: (c, s) => const HomeTab()),
          GoRoute(path: '/mall', builder: (c, s) => const MallTab()),
          GoRoute(path: '/me', builder: (c, s) => const MeTab()),
        ],
      ),
      // 团队/任务不再是底部导航页，从「我的」宫格进入，使用独立页面
      GoRoute(path: '/team', builder: (c, s) => const TeamTab()),
      GoRoute(path: '/tasks', builder: (c, s) => const TaskTab()),
      GoRoute(path: '/points', builder: (c, s) => const PointsCenterPage()),
      GoRoute(
          path: '/points/transfer',
          builder: (c, s) => const PointsTransferPage()),
      GoRoute(path: '/points-flow', builder: (c, s) => const PointsFlowPage()),
      // 站内消息：装机提醒等业务通知，从首页铃铛与「我的」宫格进入
      GoRoute(path: '/messages', builder: (c, s) => const MessagesPage()),
      GoRoute(
        path: '/messages/:id',
        builder: (c, s) => MessageDetailPage(messageId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/orders', builder: (c, s) => const OrdersPage()),
      GoRoute(path: '/addresses', builder: (c, s) => const AddressesPage()),
      GoRoute(path: '/referral', builder: (c, s) => const ReferralPage()),
      GoRoute(path: '/profile', builder: (c, s) => const ProfilePage()),
      GoRoute(path: '/machines', builder: (c, s) => const MachinesPage()),
      GoRoute(path: '/machine/add', builder: (c, s) => const AddMachinePage()),
      GoRoute(
          path: '/machine/apply',
          builder: (c, s) => const ApplyMachinePage()),
      GoRoute(path: '/packages', builder: (c, s) => const PackagesPage()),
      GoRoute(path: '/password', builder: (c, s) => const PasswordPage()),
      GoRoute(path: '/settings', builder: (c, s) => const SettingsPage()),
      GoRoute(
          path: '/trade-password',
          builder: (c, s) => const TradePasswordPage()),
      GoRoute(
          path: '/phone/rebind',
          builder: (c, s) => const PhoneRebindPage()),
      GoRoute(
          path: '/my-team', builder: (c, s) => const MyTeamPage()),
      GoRoute(
        path: '/room/:roomId',
        builder: (c, s) => RoomDetailPage(roomId: s.pathParameters['roomId']!),
      ),
    ],
  );
}
