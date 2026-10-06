import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// 积分商城（FR-5.x：纯积分兑换，按等级分池）
class MallTab extends StatelessWidget {
  const MallTab({super.key});

  static const _mockProducts = [
    ('POS 收纳包', 200, 'L1'),
    ('收银立牌', 150, 'L1'),
    ('50 元话费券', 160, 'L1'),
    ('视频会员月卡', 250, 'L2'),
    ('定制工牌', 300, 'L2'),
    ('保温杯', 400, 'L3'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('积分商城'),
        bottom: const TabBar(
          tabs: [
            Tab(text: '全部'),
            Tab(text: '我的等级池'),
            Tab(text: '虚拟权益'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          _grid(0),
          _grid(1),
          _grid(2),
        ],
      ),
    );
  }

  Widget _grid(int tab) {
    final items = tab == 0
        ? _mockProducts
        : _mockProducts.where((p) => tab == 1 ? p.$2 == 'L1' : p.$2 != 'L1').toList();
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final p = items[i];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Expanded(
                child: Container(
                  color: Colors.grey.shade100,
                  alignment: Alignment.center,
                  child: Icon(Icons.shopping_bag_outlined, size: 44, color: Colors.grey.shade400),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text('${p.$2} 积分', style: pointsTextStyle(size: 15)),
                    const SizedBox(height: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(34)),
                      onPressed: () => _confirmExchange(context, p.$1, p.$2),
                      child: const Text('兑换'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmExchange(BuildContext context, String name, int points) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('兑换「$name」'),
        content: Text('消耗 $points 积分，确认兑换？\n（积分先冻结，扣减成功后发货）'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('兑换成功（mock）')));
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}
