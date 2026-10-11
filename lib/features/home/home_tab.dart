import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';

/// 首页（FR-2.3 等级进度 / FR-3.4 达标进度 25 天倒计时）
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await api.get('/user/home');
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _heroCard(),
        const SizedBox(height: 16),
        _quickActions(),
        const SizedBox(height: 16),
        _levelCard(),
        const SizedBox(height: 12),
        _machineCard(),
        const SizedBox(height: 12),
        _noticeCard(),
      ],
    );
  }

  /// 顶部渐变卡：问候 + 积分余额 + 流水入口
  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1677FF), Color(0xFF4096FF)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('你好，138****0001', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    const Text('L1 基础会员 · 推荐码 KQW888', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.notifications_none, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Text('积分余额', style: TextStyle(color: Colors.white70, fontSize: 13)),
              SizedBox(width: 8),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('880', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white24,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 30),
                  ),
                  onPressed: () => context.push('/points-flow'),
                  child: const Text('流水'),
                ),
              ),
              const Spacer(),
              const Text('昨日 +300', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  /// 快捷入口四宫格
  Widget _quickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _quickItem(Icons.storefront, '积分商城', () => context.go('/mall'))),
          const SizedBox(width: 12),
          Expanded(child: _quickItem(Icons.account_tree, '我的团队', () => context.go('/team'))),
          const SizedBox(width: 12),
          Expanded(child: _quickItem(Icons.task_alt, '任务中心', () => context.go('/tasks'))),
          const SizedBox(width: 12),
          Expanded(child: _quickItem(Icons.campaign_outlined, '推广活动', () {})),
        ],
      ),
    );
  }

  Widget _quickItem(IconData icon, String label, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kqwPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: kqwPrimary),
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
            ],
          ),
        ),
      ),
    );
  }

  /// 等级进度（L1 → L2 双条件取较优）
  Widget _levelCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kqwPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('L1', style: TextStyle(color: kqwPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                const Text('会员等级进度', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                const Text('距 L2 还差 1500 积分', style: TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            const LinearProgressIndicator(value: 0.5, minHeight: 8, borderRadius: BorderRadius.all(Radius.circular(4))),
            const SizedBox(height: 8),
            const Text('直推达标 1/2 人 · 积分累计 1500/3000（两条件满足其一即可升级）', style: TextStyle(color: Colors.black54, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  /// 机器达标监控（25 天 / 1000 元）
  Widget _machineCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.point_of_sale, color: kqwPrimary),
                const SizedBox(width: 8),
                const Expanded(child: Text('机器达标监控', style: TextStyle(fontWeight: FontWeight.w600))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3F8600).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('进行中', style: TextStyle(color: Color(0xFF3F8600), fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _machineStat('已刷金额', '¥620 / ¥1000', 0.62),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _machineStat('剩余天数', '12 / 25 天', 0.48),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.black45),
                SizedBox(width: 4),
                Expanded(
                  child: Text('SN20261001 · 25 天内刷满 1000 元即达标，达标送 300 积分并入队', style: TextStyle(color: Colors.black45, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _machineStat(String label, String value, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: progress, minHeight: 6),
        ),
      ],
    );
  }

  /// 公告 / 活动卡
  Widget _noticeCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign_outlined, color: kqwPrimary, size: 20),
                const SizedBox(width: 8),
                const Text('平台公告', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(onPressed: () {}, child: const Text('全部')),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('10 月达标冲刺活动：达标额外 +100 积分', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: const Text('10-01 10:00 发布 · 活动至 10-31', style: TextStyle(fontSize: 12, color: Colors.black45)),
              onTap: () {},
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('新版积分规则说明已上线', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: const Text('09-25 09:00 发布', style: TextStyle(fontSize: 12, color: Colors.black45)),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}
