import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

/// 积分商城（FR-5.x：纯积分兑换，按等级分池）
class MallTab extends StatefulWidget {
  const MallTab({super.key});

  @override
  State<MallTab> createState() => _MallTabState();
}

class _MallTabState extends State<MallTab> {
  static const _mockProducts = [
    _Product('POS 收纳包', 200, 'L1', Icons.point_of_sale, 'L1 起可兑'),
    _Product('收银立牌', 150, 'L1', Icons.price_change, 'L1 起可兑'),
    _Product('50 元话费券', 160, 'L1', Icons.cell_wifi, '虚拟权益 · 自动到账'),
    _Product('视频会员月卡', 250, 'L2', Icons.smart_display, '虚拟权益 · 自动到账'),
    _Product('定制工牌', 300, 'L2', Icons.badge, 'L2 起可兑'),
    _Product('保温杯', 400, 'L3', Icons.local_drink, 'L3 起可兑'),
  ];

  /// 当前等级（mock：默认 L1，后续由 /user/home 下发）
  int get _userLevel => 1;

  List<_Product> _filtered(int tab) {
    switch (tab) {
      case 1: // 我的等级池：等级 ≥ 要求
        return _mockProducts.where((p) => _userLevel >= int.parse(p.minLevel.substring(1))).toList();
      case 2: // 虚拟权益（desc 标注“虚拟权益”的商品）
        return _mockProducts.where((p) => p.desc.startsWith('虚拟权益')).toList();
      default:
        return _mockProducts;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('积分商城'),
          actions: [
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: '我的订单',
              onPressed: () => context.push('/orders'),
            ),
          ],
          bottom: TabBar(
            tabs: const [
              Tab(text: '全部'),
              Tab(text: '我的等级池'),
              Tab(text: '虚拟权益'),
            ],
          ),
        ),
        body: Column(
          children: [
            _pointsBanner(),
            Expanded(
              child: TabBarView(
                children: [0, 1, 2].map((t) => _productGrid(t)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶部积分横幅
  Widget _pointsBanner() {
    final balance = 880; // mock，后续由 /user/home 下发
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1677FF), Color(0xFF4096FF)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard, color: Colors.white70),
          const SizedBox(width: 8),
          const Text('我的积分', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(width: 8),
          Text('$balance', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const Spacer(),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(0, 32)),
            onPressed: () => context.push('/points-flow'),
            child: const Text('查看流水 >'),
          ),
        ],
      ),
    );
  }

  Widget _productGrid(int tab) {
    final items = _filtered(tab);
    if (items.isEmpty) {
      return const Center(child: Text('该分类暂无商品', style: TextStyle(color: Colors.black45)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _productCard(items[i]),
    );
  }

  Widget _productCard(_Product p) {
    final affordable = 880 >= p.points; // mock 余额
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xFFEAF3FF), const Color(0xFFD6E6FF)],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(p.icon, size: 48, color: const Color(0xFF1677FF).withValues(alpha: 0.55)),
                  if (p.minLevel != 'L1')
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8C4B00).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${p.minLevel} 池', style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(p.desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black45, fontSize: 11)),
                  const Spacer(),
                  Row(
                    children: [
                      Text('${p.points}', style: pointsTextStyle(size: 16)),
                      const Text(' 积分', style: TextStyle(color: Colors.black54, fontSize: 12)),
                      const Spacer(),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 30),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          backgroundColor: affordable ? kqwPrimary : Colors.grey.shade400,
                        ),
                        onPressed: affordable ? () => _confirmExchange(context, p) : null,
                        child: const Text('兑换'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmExchange(BuildContext context, _Product p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('兑换「${p.name}」'),
        content: Text('消耗 ${p.points} 积分，确认兑换？\n（积分先冻结，扣减成功后发货）'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('「${p.name}」兑换成功（mock）')));
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}

class _Product {
  const _Product(this.name, this.points, this.minLevel, this.icon, this.desc);

  final String name;
  final int points;
  final String minLevel; // 'L1' / 'L2' / 'L3'
  final IconData icon;
  final String desc;
}
