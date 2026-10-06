import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 团队（FR-10.x：7 人团队 1+2+4，满员进度，分红轮次）
class TeamTab extends StatelessWidget {
  const TeamTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 我的团队卡片
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('我的 7 人团队', style: TextStyle(fontWeight: FontWeight.w600)),
                    Spacer(),
                    Text('#1 房间', style: TextStyle(color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _seat('我（队长）', true)),
                    const SizedBox(width: 8),
                    Expanded(child: _seat('138****1002')),
                    const SizedBox(width: 8),
                    Expanded(child: _seat('空位', false, true)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _seat('138****1003')),
                    const SizedBox(width: 8),
                    Expanded(child: _seat('138****1004')),
                    const SizedBox(width: 8),
                    Expanded(child: _seat('空位', false, true)),
                  ],
                ),
                const SizedBox(height: 12),
                const LinearProgressIndicator(value: 5 / 7, minHeight: 8),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('满员 5/7 · 满员即触发分红', style: TextStyle(color: Colors.black54, fontSize: 13)),
                    Text('已分红 2 轮', style: TextStyle(color: Colors.black54, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 其他房间列表
        const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text('房间列表', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 8),
        ..._mockRooms
            .map(
              (r) => Card(
                child: ListTile(
                  title: Text('房间 #${r.$1}'),
                  subtitle: Text('L${r.$2} · 已分红 ${r.$4} 轮 · 更新 ${r.$5}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${r.$3}/7', style: const TextStyle(color: Colors.black54)),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => context.push('/room/${r.$1}'),
                ),
              ),
            )
            .toList(),
      ],
    );
  }

  Widget _seat(String label, [bool self = false, bool empty = false]) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: empty ? Colors.grey.shade100 : (self ? const Color(0xFF1677FF).withOpacity(0.1) : Colors.white),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: empty ? Colors.grey.shade300 : Colors.transparent),
      ),
      alignment: Alignment.center,
      child: Text(label, style: TextStyle(fontSize: 12, color: empty ? Colors.black45 : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  static const _mockRooms = [
    (2, 1, 7, 5, '09-28'),
    (3, 1, 3, 0, '09-30'),
    (4, 2, 6, 2, '10-01'),
  ];
}
