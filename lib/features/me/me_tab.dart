import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/points_api.dart';
import '../../core/api_client.dart';
import '../../core/app_update.dart';
import '../../core/auth_provider.dart';
import '../../core/models/points_summary.dart';
import '../../core/theme.dart';
import '../../core/toast.dart';

/// 我的（个人中心）：账户信息 + 积分 + 订单快捷 + 全部功能入口
///
/// 数据源：登录态快照 + `GET /user/me`（资料补齐）+ `GET /user/points`（积分概览）。
class MeTab extends StatefulWidget {
  const MeTab({super.key, this.updater});

  /// 版本检查器（测试注入；生产用全局 appUpdateChecker）
  final AppUpdateChecker? updater;

  @override
  State<MeTab> createState() => _MeTabState();
}

class _MeTabState extends State<MeTab> {
  PointsSummary _points = PointsSummary.empty;
  bool _loaded = false;

  late final AppUpdateChecker _updater = widget.updater ?? appUpdateChecker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (!auth.loggedIn) return;
    await auth.loadProfile();
    try {
      final points = await pointsApi.summary();
      if (!mounted) return;
      setState(() {
        _points = points;
        _loaded = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 10100) {
        await auth.logout();
        if (mounted) context.go('/login');
        return;
      }
      setState(() => _loaded = true);
    }
  }

  Future<void> _copyInviteCode(String code) async {
    if (code.isEmpty) {
      showToast(context, '推广码生成中，稍后下拉刷新');
      return;
    }
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) showToast(context, '邀请码已复制');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // 外层 ShellLayout 已提供 Scaffold，这里不再嵌套：
    // 嵌套 Scaffold 会让 ScaffoldMessenger 的 SnackBar 在两层各渲染一次。
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _header(context, auth),
          const SizedBox(height: 16),
          Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: _ordersCard(context)),
          const SizedBox(height: 12),
          Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: _featureGrid(context)),
          const SizedBox(height: 12),
          Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: _settingsCard(context)),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'v0.1.0 · 用户 ${auth.user?.id ?? '-'}'
              '${_loaded ? '' : ' · 同步中…'}',
              style: const TextStyle(color: Colors.black26, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ---------- 渐变头部 ----------

  Widget _header(BuildContext context, AuthProvider auth) {
    final inviteCode = auth.user?.inviteCode ?? '';
    return Container(
      decoration: const BoxDecoration(gradient: kqwHeaderGradient),
      child: Stack(
        children: [
          // 装饰圆（科技感点缀）
          Positioned(top: -40, right: -30, child: _circle(160)),
          Positioned(bottom: -40, left: -40, child: _circle(140)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
            child: Column(
              children: [
                // 点用户信息区进入「修改个人资料」
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push('/profile'),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white.withValues(alpha: 0.22),
                        child: _avatar(auth, 60),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(auth.name ?? '未登录',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white)),
                                ),
                                const Icon(Icons.edit,
                                    size: 15, color: Colors.white70),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                      '${auth.user?.levelLabel ?? 'L0'} 会员',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _copyInviteCode(inviteCode),
                              child: Row(
                                children: [
                                  Text(
                                      inviteCode.isEmpty
                                          ? '推广码生成中'
                                          : '邀请码 $inviteCode',
                                      style: const TextStyle(
                                          fontSize: 13, color: Colors.white70)),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.copy_rounded,
                                      size: 14, color: Colors.white70),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _pointsCard(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 头像：服务端 URL → 本地新裁切字节 → 默认图
  Widget _avatar(AuthProvider auth, double size) {
    final url = auth.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _avatarFallback(auth, size),
        ),
      );
    }
    return _avatarFallback(auth, size);
  }

  Widget _avatarFallback(AuthProvider auth, double size) {
    final bytes = auth.avatarBytes;
    if (bytes != null) {
      return ClipOval(
        child: Image.memory(bytes, width: size, height: size, fit: BoxFit.cover),
      );
    }
    return Image.asset('assets/avatar.jpeg', width: size - 8, height: size - 8);
  }

  Widget _circle(double size) => Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
          shape: BoxShape.circle, color: Color(0x14FFFFFF)));

  // ---------- 积分卡（悬浮压在渐变底部） ----------

  Widget _pointsCard(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/points'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Color(0x1AE53935),
                blurRadius: 24,
                offset: Offset(0, 10))
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('可用积分',
                        style: TextStyle(
                            fontSize: 13, color: kqwTextSecondary)),
                    const SizedBox(height: 6),
                    Text(_points.balance,
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: kqwPrimary)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: kqwPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    children: [
                      Text('明细',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: kqwPrimary)),
                      Icon(Icons.chevron_right, size: 15, color: kqwPrimary),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFEEF1F6)),
            const SizedBox(height: 14),
            Row(
              children: [
                _stat(_points.totalEarned, '累计获得'),
                _statDivider(),
                _stat(_points.totalSpent, '累计消耗'),
                _statDivider(),
                _stat(_points.frozen, '冻结中'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2430))),
            const SizedBox(height: 4),
            Text(label,
                style:
                    const TextStyle(fontSize: 12, color: kqwTextSecondary)),
          ],
        ),
      );

  Widget _statDivider() => const SizedBox(
      width: 12,
      child: VerticalDivider(width: 1, thickness: 1, color: Color(0xFFEEF1F6)));

  // ---------- 我的订单 ----------

  Widget _ordersCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('我的订单',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const Spacer(),
              InkWell(
                onTap: () => context.push('/orders'),
                child: const Row(
                  children: [
                    Text('查看全部订单',
                        style:
                            TextStyle(fontSize: 13, color: kqwTextSecondary)),
                    Icon(Icons.chevron_right, size: 16, color: kqwTextSecondary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _orderQuick(Icons.inventory_2_outlined, '待发货',
                  () => context.push('/orders')),
              _orderQuick(Icons.local_shipping_outlined, '待收货',
                  () => context.push('/orders')),
              _orderQuick(Icons.check_circle_outline, '已完成',
                  () => context.push('/orders')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _orderQuick(IconData icon, String label, VoidCallback onTap) =>
      Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Icon(icon, size: 28, color: kqwPrimary),
                const SizedBox(height: 8),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF4A5160))),
              ],
            ),
          ),
        ),
      );

  // ---------- 功能宫格（团队/任务等入口都在这里） ----------

  /// 每行格子数，末行不足时补占位，保持列对齐
  static const int _gridColumns = 4;

  Widget _featureGrid(BuildContext context) {
    // 「安装POS」入口由后台 user.can_install 开关控制显隐
    // （后台：POST /admin/users/{id}/can-install，C 端见 UserInfo.canInstall）
    final canInstall = context.watch<AuthProvider>().user?.canInstall ?? false;

    final entries = <_GridEntry>[
      _GridEntry(Icons.account_tree, '我的团队', () => context.push('/team')),
      _GridEntry(Icons.task_alt, '任务中心', () => context.push('/tasks')),
      _GridEntry(Icons.savings, '积分中心', () => context.push('/points')),
      _GridEntry(Icons.point_of_sale, '我的机器', () => context.push('/machines')),
      _GridEntry(Icons.qr_code, '推荐海报', () => context.push('/referral')),
      _GridEntry(Icons.location_on, '收货地址', () => context.push('/addresses')),
      _GridEntry(Icons.card_giftcard, '积分礼包', () => context.push('/packages')),
      _GridEntry(
          Icons.headset_mic, '帮助与客服', () => showToast(context, '功能开发中')),
      if (canInstall)
        _GridEntry(Icons.install_desktop, '安装POS',
            () => context.push('/machine/add')),
    ];

    final rows = <Widget>[];
    for (var start = 0; start < entries.length; start += _gridColumns) {
      final end = start + _gridColumns > entries.length
          ? entries.length
          : start + _gridColumns;
      final chunk = entries.sublist(start, end);
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 12));
      rows.add(Row(
        children: [
          for (final e in chunk) _gridItem(context, e.icon, e.label, e.onTap),
          for (var i = chunk.length; i < _gridColumns; i++)
            const Expanded(child: SizedBox()),
        ],
      ));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
      child: Column(children: rows),
    );
  }

  Widget _gridItem(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kqwPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 24, color: kqwPrimary),
              ),
              const SizedBox(height: 8),
              Text(label,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF4A5160))),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 设置 ----------

  /// 手动检查更新：已是最新/失败都会给一句提示
  Future<void> _checkUpdate() => _updater.check(context, manual: true);

  Widget _settingsCard(BuildContext context) {
    return Column(
      children: [
        _tile(context, Icons.lock_outline, '修改密码', () => context.push('/password')),
        const Divider(height: 1, indent: 56),
        _tile(context, Icons.system_update_alt, '检查更新', _checkUpdate),
        const Divider(height: 1, indent: 56),
        _tile(context, Icons.settings_outlined, '设置',
            () => showToast(context, '功能开发中')),
        const Divider(height: 1, indent: 56),
        _tile(
          context,
          Icons.logout,
          '退出登录',
          () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('确认退出登录？'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消')),
                  FilledButton(
                    onPressed: () {
                      context.read<AuthProvider>().logout();
                      Navigator.pop(ctx);
                      context.go('/login');
                    },
                    child: const Text('退出'),
                  ),
                ],
              ),
            );
          },
          red: true,
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title,
      VoidCallback onTap,
      {bool red = false}) {
    final color = red ? const Color(0xFFE5484D) : const Color(0xFF1F2430);
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right, size: 20, color: kqwTextSecondary),
      onTap: onTap,
    );
  }
}

/// 功能宫格入口（图标 + 文案 + 点击），由 [_MeTabState._featureGrid] 按行分块渲染
class _GridEntry {
  const _GridEntry(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}
