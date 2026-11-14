import 'package:flutter/material.dart';

import '../core/api/mall_api.dart';
import '../core/api_client.dart';
import '../core/models/mall_order.dart';
import '../core/theme.dart';
import '../core/widgets/async_view.dart';
import '../core/toast.dart';

/// 我的订单（积分兑换订单：待发货 / 已发货 / 已完成 / 已取消）
///
/// 数据源 `GET /mall/orders`；取消走 `POST /mall/orders/{id}/cancel`（退积分），
/// 确认收货走 `POST /mall/orders/{id}/confirm`。
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  /// (标题, 后端 status)：null = 全部
  static const _tabs = <({String title, int? status})>[
    (title: '全部', status: null),
    (title: '待发货', status: 0),
    (title: '已发货', status: 1),
    (title: '已完成', status: 2),
    (title: '已取消', status: 3),
  ];

  int _tabIndex = 0;
  List<OrderItem> _items = const [];
  bool _loading = true;
  String? _error;

  /// 正在执行取消/确认的订单 id，避免重复点击
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int? get _status => _tabs[_tabIndex].status;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await mallApi.orders(status: _status);
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _error = e.displayMessage;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel(OrderItem order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消订单'),
        content: Text('取消「${order.productName}」后积分将退回账户，确定取消？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('再想想'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定取消'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyId = order.id);
    try {
      final res = await mallApi.cancelOrder(order.id, reason: '用户主动取消');
      if (!mounted) return;
      showToast(context, '已取消，退回 ${res.pointsRefunded} 积分');
      await _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.displayMessage);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _confirm(OrderItem order) async {
    setState(() => _busyId = order.id);
    try {
      await mallApi.confirmOrder(order.id);
      if (!mounted) return;
      showToast(context, '已确认收货');
      await _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.displayMessage);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('我的订单'),
          bottom: TabBar(
            labelColor: kqwPrimary,
            unselectedLabelColor: Colors.black54,
            indicatorColor: kqwPrimary,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: _tabs.map((t) => Tab(text: t.title)).toList(),
            onTap: (i) {
              setState(() => _tabIndex = i);
              _load();
            },
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: AsyncStateView(
            loading: _loading,
            error: _error,
            isEmpty: _items.isEmpty,
            onRetry: _load,
            emptyText: '暂无订单',
            emptyIcon: Icons.receipt_long_outlined,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _orderCard(_items[i]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _orderCard(OrderItem o) {
    final statusColor = switch (o.status) {
      0 => const Color(0xFFB25E00),
      1 => const Color(0xFF1565C0),
      2 => const Color(0xFF3F8600),
      _ => Colors.black45,
    };
    final busy = _busyId == o.id;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_outlined,
                    size: 18, color: Colors.black45),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('订单号 ${o.orderNo}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                      overflow: TextOverflow.ellipsis),
                ),
                Text(
                  o.statusName,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 发货后（实物单已发货/已完成）只展示订单号 + 快递公司/单号，其余信息隐藏
            if (o.fulfilled)
              Row(
                children: [
                  const Icon(Icons.local_shipping_outlined,
                      size: 20, color: kqwPrimary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${o.expressCompany ?? ''} ${o.expressNo}'.trim(),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          o.shippedAt == null
                              ? '已发货'
                              : '发货时间 ${formatShortTime(o.shippedAt)}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black45),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFFFEBEE), Color(0xFFFFCDD2)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      o.isVirtual
                          ? Icons.card_giftcard_outlined
                          : Icons.shopping_bag_outlined,
                      size: 22,
                      color: kqwPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.productName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          '${formatShortTime(o.createdAt)} · 数量 ${o.buyCount}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black45),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(o.pointsCost, style: pointsTextStyle(size: 16)),
                      const Text('积分',
                          style: TextStyle(fontSize: 11, color: Colors.black45)),
                    ],
                  ),
                ],
              ),
            if (o.cancellable || o.confirmable) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (o.cancellable)
                    OutlinedButton(
                      onPressed: busy ? null : () => _cancel(o),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: Colors.black54,
                      ),
                      child: Text(busy ? '处理中…' : '取消订单'),
                    ),
                  if (o.confirmable) ...[
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: busy ? null : () => _confirm(o),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: kqwPrimary,
                      ),
                      child: Text(busy ? '处理中…' : '确认收货'),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
