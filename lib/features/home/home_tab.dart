import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/toast.dart';

/// 首页：积分礼包（五个）+ 等级进度 / 机器达标监控 / 任务中心 / 平台公告
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  static const _gifts = [
    _Gift('200 积分礼包', '200 积分'),
    _Gift('300 积分礼包', '300 积分'),
    _Gift('600 积分礼包', '600 积分'),
    _Gift('白银会员礼包', '300 积分 600 积分'),
    _Gift('黄金会员礼包', '300 积分 600 积分'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _banner(),
        for (final g in _gifts)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _giftCard(context, g),
          ),
        _levelCard(),
        const SizedBox(height: 12),
        _machineCard(),
        const SizedBox(height: 12),
        _taskCard(context),
        const SizedBox(height: 12),
        _noticeCard(),
      ],
    );
  }

  // ---------- 顶部横幅 ----------

  Widget _banner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: const BoxDecoration(gradient: kqwHeaderGradient, borderRadius: BorderRadius.all(Radius.circular(16))),
      child: Stack(
        children: [
          Positioned(top: -50, right: -30, child: _circle(140)),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text('积分礼包', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
              SizedBox(height: 8),
              Text('选购礼包进入队伍，解锁团队分红收益', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circle(double size) =>
      Container(width: size, height: size, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x14FFFFFF)));

  // ---------- 礼包卡 ----------

  Widget _giftCard(BuildContext context, _Gift g) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _confirmBuy(context, g),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF2B5BFF), Color(0xFF00A9E8)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.card_giftcard, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(g.points, style: pointsTextStyle(size: 17)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: kqwPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                ),
                onPressed: () => _confirmBuy(context, g),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('购买', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    Icon(Icons.chevron_right, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmBuy(BuildContext context, _Gift g) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('购买「${g.name}」'),
        content: const Text('确认购买该积分礼包？\n（mock：支付流程待接入）'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              showToast(context, '「${g.name}」购买成功（mock）');
            },
            child: const Text('确认购买'),
          ),
        ],
      ),
    );
  }

  // ---------- 等级进度（L1 → L2 双条件取较优） ----------

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

  // ---------- 机器达标监控（25 天 / 1000 元） ----------

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

  // ---------- 任务中心（进度 + 入口） ----------

  Widget _taskCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/tasks'),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.task_alt, color: kqwPrimary),
                  SizedBox(width: 8),
                  Expanded(child: Text('任务中心', style: TextStyle(fontWeight: FontWeight.w600))),
                  Text('剩 21 天', style: TextStyle(color: Colors.black54, fontSize: 12)),
                  SizedBox(width: 6),
                  Icon(Icons.chevron_right, size: 18, color: kqwTextSecondary),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Text('新手任务 3/6', style: TextStyle(color: Colors.black54, fontSize: 13)),
                  Spacer(),
                  Text('今日签到 +2 分', style: TextStyle(color: Colors.black54, fontSize: 13)),
                ],
              ),
              SizedBox(height: 6),
              LinearProgressIndicator(value: 0.5, minHeight: 8, borderRadius: BorderRadius.all(Radius.circular(4))),
              SizedBox(height: 8),
              Text('再完成「T-N4 首次推荐」得 50 积分', style: TextStyle(color: Colors.black45, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 公告 / 活动卡 ----------

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

class _Gift {
  const _Gift(this.name, this.points);

  final String name;
  final String points;
}
