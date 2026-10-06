import 'package:flutter/material.dart';

import '../core/theme.dart';

/// 积分流水（FR-4.2：来源类型 / 变动值 / 变动后余额 / 触发事件）
class PointsFlowPage extends StatelessWidget {
  const PointsFlowPage({super.key});

  static const _mockFlows = [
    ('达标入队积分', 300, 'SN20261001', '10-01 14:22'),
    ('推荐达标 1 级', 100, 'BIZ8801', '09-29 09:10'),
    ('团队分红', 1200, '房间#1 第2轮', '09-27 20:05'),
    ('任务：每日签到', 2, 'T-D1', '09-28 08:01'),
    ('商城核销', -200, '订单 OF20260925001', '09-25 18:40'),
    ('晋级礼 L1', 100, '规则赠送', '09-20 10:00'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('积分流水')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _mockFlows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final f = _mockFlows[i];
          final positive = f.$2 >= 0;
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: positive ? const Color(0xFF3F8600).withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.1),
                child: Icon(
                  positive ? Icons.arrow_downward : Icons.arrow_upward,
                  color: positive ? const Color(0xFF3F8600) : Colors.red,
                  size: 22,
                ),
              ),
              title: Text(f.$1, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text('${f.$3} · ${f.$4}', style: const TextStyle(fontSize: 12, color: Colors.black45)),
              trailing: Text(
                positive ? '+${f.$2}' : '${f.$2}',
                style: pointsTextStyle(color: positive ? const Color(0xFF3F8600) : Colors.red),
              ),
            ),
          );
        },
      ),
    );
  }
}
