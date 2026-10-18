import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth_provider.dart';
import '../../core/theme.dart';
import '../../core/toast.dart';

/// 我的（个人中心）：账户信息 + 积分 + 订单快捷 + 全部功能入口
/// 底部导航精简后，原「团队」「任务」等入口统一收进本页功能宫格。
class MeTab extends StatelessWidget {
  const MeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // 外层 ShellLayout 已提供 Scaffold，这里不再嵌套：
    // 嵌套 Scaffold 会让 ScaffoldMessenger 的 SnackBar 在两层各渲染一次。
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _header(context),
        const SizedBox(height: 16),
        Card(margin: const EdgeInsets.symmetric(horizontal: 16), child: _ordersCard(context)),
        const SizedBox(height: 12),
        Card(margin: const EdgeInsets.symmetric(horizontal: 16), child: _featureGrid(context)),
        const SizedBox(height: 12),
        Card(margin: const EdgeInsets.symmetric(horizontal: 16), child: _settingsCard(context)),
        const SizedBox(height: 24),
        Center(
          child: Text('v0.1.0 · 用户 ${auth.userId ?? '-'}',
              style: const TextStyle(color: Colors.black26, fontSize: 12)),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ---------- 渐变头部 ----------

  Widget _header(BuildContext context) {
    final auth = context.watch<AuthProvider>();
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
                        child: auth.avatarBytes != null
                            ? ClipOval(
                                child: Image.memory(auth.avatarBytes!, width: 60, height: 60, fit: BoxFit.cover),
                              )
                            : Image.asset('assets/avatar.jpeg', width: 52, height: 52),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(auth.name ?? '138****0001',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                                ),
                                const Icon(Icons.edit, size: 15, color: Colors.white70),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('L1 基础会员',
                                      style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () async {
                                try {
                                  await Clipboard.setData(const ClipboardData(text: 'KQW888'));
                                  if (!context.mounted) return;
                                  showToast(context, '邀请码已复制');
                                } catch (_) {
                                  if (!context.mounted) return;
                                  showToast(context, '复制失败，请手动选择');
                                }
                              },
                              child: const Row(
                                children: [
                                  Text('邀请码 KQW888', style: TextStyle(fontSize: 13, color: Colors.white70)),
                                  SizedBox(width: 4),
                                  Icon(Icons.copy_rounded, size: 14, color: Colors.white70),
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

  Widget _circle(double size) =>
      Container(width: size, height: size, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x14FFFFFF)));

  // ---------- 积分卡（悬浮压在渐变底部） ----------

  Widget _pointsCard(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/points-flow'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x1A2B5BFF), blurRadius: 24, offset: Offset(0, 10))],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('总积分', style: TextStyle(fontSize: 13, color: kqwTextSecondary)),
                    SizedBox(height: 6),
                    Text('2,680', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: kqwPrimary)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: kqwPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    children: [
                      Text('明细', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kqwPrimary)),
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
                _stat('1,280', '任务积分'),
                _statDivider(),
                _stat('860', '分红收益'),
                _statDivider(),
                _stat('5/7', '我的团队'),
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
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1F2430))),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: kqwTextSecondary)),
          ],
        ),
      );

  Widget _statDivider() => const SizedBox(width: 12, child: VerticalDivider(width: 1, thickness: 1, color: Color(0xFFEEF1F6)));

  // ---------- 我的订单 ----------

  Widget _ordersCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('我的订单', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const Spacer(),
              InkWell(
                onTap: () => context.push('/orders'),
                child: const Row(
                  children: [
                    Text('查看全部订单', style: TextStyle(fontSize: 13, color: kqwTextSecondary)),
                    Icon(Icons.chevron_right, size: 16, color: kqwTextSecondary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _orderQuick(Icons.inventory_2_outlined, '待发货', () => context.push('/orders')),
              _orderQuick(Icons.local_shipping_outlined, '待收货', () => context.push('/orders')),
              _orderQuick(Icons.check_circle_outline, '已完成', () => context.push('/orders')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _orderQuick(IconData icon, String label, VoidCallback onTap) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Icon(icon, size: 28, color: kqwPrimary),
                const SizedBox(height: 8),
                Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF4A5160))),
              ],
            ),
          ),
        ),
      );

  // ---------- 功能宫格（团队/任务等入口都在这里） ----------

  Widget _featureGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
      child: Column(
        children: [
          Row(
            children: [
              _gridItem(context, Icons.account_tree, '我的团队', () => context.push('/team')),
              _gridItem(context, Icons.task_alt, '任务中心', () => context.push('/tasks')),
              _gridItem(context, Icons.receipt_long, '积分流水', () => context.push('/points-flow')),
              _gridItem(context, Icons.point_of_sale, '我的机器', () => context.push('/machines')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _gridItem(context, Icons.qr_code, '推荐海报', () => context.push('/referral')),
              _gridItem(context, Icons.location_on, '收货地址', () => context.push('/addresses')),
              _gridItem(context, Icons.notifications, '消息通知', () => showToast(context, '功能开发中')),
              _gridItem(context, Icons.headset_mic, '帮助与客服', () => showToast(context, '功能开发中')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _gridItem(BuildContext context, IconData icon, String label, VoidCallback onTap) {
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
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF4A5160))),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 设置 ----------

  Widget _settingsCard(BuildContext context) {
    return Column(
      children: [
        _tile(context, Icons.settings_outlined, '设置', () => showToast(context, '功能开发中')),
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
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                  FilledButton(
                    onPressed: () {
                      context.read<AuthProvider>().logout();
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

  Widget _tile(BuildContext context, IconData icon, String title, VoidCallback onTap, {bool red = false}) {
    final color = red ? const Color(0xFFE5484D) : const Color(0xFF1F2430);
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right, size: 20, color: kqwTextSecondary),
      onTap: onTap,
    );
  }
}
