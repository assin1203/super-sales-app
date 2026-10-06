import 'package:flutter/material.dart';

/// 房间详情（FR-10.3：1+2+4 布局、权重展示、分红轮次）
class RoomDetailPage extends StatelessWidget {
  const RoomDetailPage({super.key, required this.roomId});
  final String roomId;

  // 1+2+4 二叉布局：位置号 → (成员, 贡献值, 是否自己)
  static const _seats = [
    (1, '我（队长）', 2, true),
    (2, '138****1002', 1, false),
    (3, '138****1003', 0, false),
    (4, '138****1004', 1, false),
    (5, '空位', 0, false),
    (6, '138****1005', 2, false),
    (7, '138****1006', 0, false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('房间 #$roomId 详情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SeatRow3(startIndex: 0), // 第 1 行：1 人
                  const SizedBox(height: 12),
                  const SeatRow2(startIndex: 1), // 第 2 行：2 人
                  const SizedBox(height: 12),
                  const SeatRow4(startIndex: 3), // 第 3 行：4 人
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('权重排序（贡献值为主，位置为辅）', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 12),
                  Text('1. 我（队长）— 贡献值 2', style: TextStyle(color: Colors.black87)),
                  Text('2. 138****1005 — 贡献值 2（入队更早）', style: TextStyle(color: Colors.black87)),
                  Text('3. 138****1002 — 贡献值 1', style: TextStyle(color: Colors.black87)),
                  Text('4. 138****1004 — 贡献值 1', style: TextStyle(color: Colors.black87)),
                  Text('5-7. 其余 3 人', style: TextStyle(color: Colors.black54)),
                  SizedBox(height: 12),
                  Text('满员后权重最高者获 1200 积分并自动再入队', style: TextStyle(color: Colors.black54, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SeatRow3 extends StatelessWidget {
  const SeatRow3({super.key, required this.startIndex});
  final int startIndex;

  @override
  Widget build(BuildContext context) => const SeatRow(startIndex: 0, count: 1);
}

class SeatRow2 extends StatelessWidget {
  const SeatRow2({super.key, required this.startIndex});
  final int startIndex;

  @override
  Widget build(BuildContext context) => const SeatRow(startIndex: 1, count: 2);
}

class SeatRow4 extends StatelessWidget {
  const SeatRow4({super.key, required this.startIndex});
  final int startIndex;

  @override
  Widget build(BuildContext context) => const SeatRow(startIndex: 3, count: 4);
}

class SeatRow extends StatelessWidget {
  const SeatRow({super.key, required this.startIndex, required this.count});
  final int startIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    final seats = RoomDetailPage._seats.sublist(startIndex, startIndex + count);
    return Row(
      children: seats
          .map(
            (s) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  decoration: BoxDecoration(
                    color: s.$3 == 0 && s.$2 == '空位'
                        ? Colors.grey.shade100
                        : s.$4
                            ? const Color(0xFF1677FF).withValues(alpha: 0.1)
                            : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: s.$2 == '空位' ? Colors.grey.shade300 : Colors.transparent),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Text(s.$2, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      if (s.$2 != '空位')
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(s.$3, (_) => const Icon(Icons.star, size: 14, color: Colors.orange)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
