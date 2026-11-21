import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'api/pos_api.dart';
import 'api/team_api.dart';
import 'api_client.dart';
import 'auth_provider.dart';
import 'models/machine.dart';
import 'toast.dart';
import 'widgets/newbie_confirm_dialog.dart';
import 'widgets/upgrade_prompt_dialog.dart';

/// 底部导航壳（ShellRoute 的 child 由 GoRouter 按路由切换）。
/// 独立文件避免 main.dart 与 app_router.dart 循环依赖。
///
/// 曾承担两个全局自动提醒（冷启动首帧与每次回到前台各查一次）：
///   1. 升级提示：名下有待定冻结奖励且积分够进下一档房间 → 问是否升级（先弹）；
///   2. 新手达标双方确认：有我没确认的机器 → 多选确认框（后弹）。
/// 现在默认关闭（[enableDialogs] = false）：不再请求也不再弹，逻辑保留待恢复。
class ShellLayout extends StatefulWidget {
  const ShellLayout({
    super.key,
    required this.child,
    this.posApi,
    this.teamApi,
    this.enableDialogs = false,
  });

  final Widget child;

  /// 待确认检查用的接口实例（测试可注入；默认全局 posApi）
  final PosApi? posApi;

  /// 升级提示检查用的接口实例（测试可注入；默认全局 teamApi）
  final TeamApi? teamApi;

  /// 两个自动弹窗的总开关，默认关闭：先不打扰用户，关掉后冷启动/回前台
  /// 连这两组接口都不再请求。弹窗实现与检查逻辑都保留，需要恢复时置 true。
  final bool enableDialogs;

  @override
  State<ShellLayout> createState() => _ShellLayoutState();
}

class _ShellLayoutState extends State<ShellLayout> with WidgetsBindingObserver {
  /// 防止冷启动与回前台叠在一起发两次请求/弹两个框
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 首帧之后再查：不拖慢启动，也不与登录页/版本弹窗抢生命周期
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAll());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 每次回到前台都查一次：对方可能刚确认完，冻结奖励也可能刚可升级
    if (state == AppLifecycleState.resumed) _checkAll();
  }

  /// 依次检查两个提醒：先升级提示（资金决策），用户处理完再弹达标确认，
  /// 避免两个框叠在一起互相盖住。
  Future<void> _checkAll() async {
    // 总开关关掉时连接口都不请求：既不弹框，也不留无用的网络请求
    if (!widget.enableDialogs) return;
    if (_checking || !mounted) return;
    if (!context.read<AuthProvider>().loggedIn) return;
    _checking = true;
    try {
      await _maybeShowUpgradePrompt();
      if (!mounted) return;
      await _maybeShowNewbieConfirm();
    } finally {
      _checking = false;
    }
  }

  /// 升级提示：后端只在「有待定冻结奖励 + 积分够进下一档房 + 不是 L2」时返回数据
  Future<void> _maybeShowUpgradePrompt() async {
    try {
      final api = widget.teamApi ?? teamApi;
      final prompt = await api.upgradePrompt();
      if (!mounted || prompt == null || !prompt.canUpgrade) return;
      final result = await showUpgradePromptDialog(context, prompt: prompt, api: widget.teamApi);
      if (!mounted || result == null) return;
      showToast(context, result.message);
    } on ApiException {
      // 拉取失败（未登录 / 网络异常）静默：不能因为一个提醒打扰正常使用
    }
  }

  /// 新手达标双方确认：自己确认过的机器后端不再返回，所以不会反复打扰
  Future<void> _maybeShowNewbieConfirm() async {
    try {
      final api = widget.posApi ?? posApi;
      final pending = await api.pendingNewbieConfirms();
      if (!mounted || pending.isEmpty) return;
      final result = await showNewbieConfirmDialog(context, pending: pending, api: widget.posApi);
      if (!mounted || result == null) return;
      showToast(context, _confirmToast(result));
    } on ApiException {
      // 同上：静默
    }
  }

  /// 确认结果的提示文案：有逐台未通过原因（如流水未达门槛）时优先展示，
  /// 否则用后端汇总文案；同一原因只出现一次。
  String _confirmToast(NewbieConfirmResponse result) {
    final blocked = result.items.where((item) => item.confirmed && !item.settled && item.message.isNotEmpty);
    final reasons = <String>{for (final item in blocked) item.message};
    if (reasons.isEmpty) return result.message;
    return reasons.join('；');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
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
