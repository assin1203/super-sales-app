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
      padding: const EdgeInsets.all(16),
      children: [
        // 积分余额卡片
        Card(
          color: kqwPrimary.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('积分余额', style: TextStyle(color: Colors.black54)),
                      const SizedBox(height: 8),
                      Text('880', style: pointsTextStyle(size: 30)),
                    ],
                  ),
                ),
                FilledButton.tonal(onPressed: () => context.go('/points-flow'), child: const Text('流水')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 会员等级进度
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('会员等级', style: TextStyle(fontWeight: FontWeight.w600)),
                    Spacer(),
                    Text('L1 → L2', style: TextStyle(color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 12),
                const LinearProgressIndicator(minHeight: 8),
                const SizedBox(height: 8),
                const Text('直推达标 1/2 人 或 积分累计 1500/3000', style: TextStyle(color: Colors.black54, fontSize: 13)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 机器达标监控
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('机器达标（25 天 / 1000 元）', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                const LinearProgressIndicator(value: 0.62, minHeight: 8),
                const SizedBox(height: 8),
                const Text('SN20261001 · 已刷 620 元 · 剩 12 天', style: TextStyle(color: Colors.black54, fontSize: 13)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 广告位 / 任务入口（FR-601/602 对应 C 端）
        Row(
          children: [
            Expanded(
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.campaign_outlined),
                  title: const Text('推广活动'),
                  onTap: () {},
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.add_shopping_cart_outlined),
                  title: const Text('申请装机'),
                  onTap: () {},
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
