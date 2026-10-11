import 'package:flutter/material.dart';

import '../core/theme.dart';

/// 我的订单（积分兑换订单：待发货/已完成）
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  int _tabIndex = 0;

  static const _tabTitles = ['全部', '待发货', '已完成'];

  static const _mockOrders = [
    _Order(
      no: 'OF20261001001',
      product: 'POS 收纳包',
      points: 200,
      status: 'shipped',
      time: '10-01 14:30',
      addr: '138****0001 · 上海市徐汇区漕溪北路 88 号',
    ),
    _Order(
      no: 'OF20260928002',
      product: '50 元话费券',
      points: 160,
      status: 'pending',
      time: '09-28 10:12',
      addr: '虚拟商品 · 自动到账至手机号',
    ),
    _Order(
      no: 'OF20260925001',
      product: '收银立牌',
      points: 150,
      status: 'shipped',
      time: '09-25 18:40',
      addr: '138****0001 · 上海市徐汇区漕溪北路 88 号',
    ),
  ];

  List<_Order> get _filtered {
    switch (_tabIndex) {
      case 1:
        return _mockOrders.where((o) => o.status == 'pending').toList();
      case 2:
        return _mockOrders.where((o) => o.status == 'shipped').toList();
      default:
        return _mockOrders;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return DefaultTabController(
      length: _tabTitles.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('我的订单'),
          bottom: TabBar(
            labelColor: kqwPrimary,
            unselectedLabelColor: Colors.black54,
            indicatorColor: kqwPrimary,
            tabs: _tabTitles.map((t) => Tab(text: t)).toList(),
            onTap: (i) => setState(() => _tabIndex = i),
          ),
        ),
        body: items.isEmpty
            ? const Center(child: Text('暂无订单', style: TextStyle(color: Colors.black45)))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _orderCard(items[i]),
              ),
      ),
    );
  }

  Widget _orderCard(_Order o) {
    final pending = o.status == 'pending';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_outlined, size: 18, color: Colors.black45),
                const SizedBox(width: 6),
                Text('订单号 ${o.no}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const Spacer(),
                Text(
                  pending ? '待发货' : '已完成',
                  style: TextStyle(
                    fontSize: 12,
                    color: pending ? const Color(0xFFB25E00) : const Color(0xFF3F8600),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFEAF3FF), Color(0xFFD6E6FF)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.shopping_bag_outlined, size: 22, color: Color(0xFF1677FF)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.product, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(o.time, style: const TextStyle(fontSize: 12, color: Colors.black45)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${o.points}', style: pointsTextStyle(size: 16)),
                    const Text('积分', style: TextStyle(fontSize: 11, color: Colors.black45)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: Colors.black45),
                const SizedBox(width: 4),
                Expanded(child: Text(o.addr, style: const TextStyle(fontSize: 12, color: Colors.black54))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Order {
  const _Order({
    required this.no,
    required this.product,
    required this.points,
    required this.status,
    required this.time,
    required this.addr,
  });

  final String no;
  final String product;
  final int points;
  final String status; // pending / shipped
  final String time;
  final String addr;
}
