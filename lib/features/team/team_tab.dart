import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 团队（FR-10.x：7 人团队 1+2+4，满员进度，分红轮次）
class TeamTab extends StatelessWidget {
  const TeamTab({super.key});

  @override
  Widget build(BuildContext context) {
    // 成员按顺序从左到右填 7 个座位（第一行 3 + 第二行 4），空位自动排在最右侧
    final slots = List<String?>.filled(_seatCount, null);
    for (var i = 0; i < _members.length; i++) {
      slots[i] = _members[i];
    }
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
                _seatRow(slots.sublist(0, 3)),
                const SizedBox(height: 8),
                _seatRow(slots.sublist(3)),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: _members.length / _seatCount, minHeight: 8),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('满员 ${_members.length}/$_seatCount · 满员即触发分红', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                    const Text('已分红 2 轮', style: TextStyle(color: Colors.black54, fontSize: 13)),
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

  /// 第一行座位数（1 队长 + 2 成员），第二行 _seatCount - 3
  static const int _seatCount = 7;

  /// 团队成员按顺序排列（含队长），不足 _seatCount 时右侧补空位
  static const List<String> _members = [
    '我（队长）',
    '138****1002',
    '138****1003',
    '138****1004',
    '138****1005',
  ];

  Widget _seatRow(List<String?> row) {
    return Row(
      children: [
        for (var i = 0; i < row.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _seat(row[i])),
        ],
      ],
    );
  }

  Widget _seat(String? label) {
    final empty = label == null;
    final self = label == '我（队长）';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: empty ? Colors.grey.shade100 : (self ? const Color(0xFF1677FF).withValues(alpha: 0.1) : Colors.white),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: empty ? Colors.grey.shade300 : Colors.transparent),
      ),
      alignment: Alignment.center,
      child: Text(empty ? '空位' : label, style: TextStyle(fontSize: 12, color: empty ? Colors.black45 : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  static const _mockRooms = [
    (2, 1, 7, 5, '09-28'),
    (3, 1, 3, 0, '09-30'),
    (4, 2, 6, 2, '10-01'),
  ];
}
