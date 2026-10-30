import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/mall_api.dart';
import '../../core/api/points_api.dart';
import '../../core/api_client.dart';
import '../../core/auth_provider.dart';
import '../../core/models/points_summary.dart';
import '../../core/models/product.dart';
import '../../core/theme.dart';
import '../../core/toast.dart';

/// 积分商城（FR-5.x：纯积分兑换，按等级分池）
///
/// 商品列表来自 `GET /mall/products`，兑换走 `POST /mall/exchange`
/// （userId 由后端从 JWT 取，前端不传）。
class MallTab extends StatefulWidget {
  const MallTab({super.key});

  @override
  State<MallTab> createState() => _MallTabState();
}

class _MallTabState extends State<MallTab> {
  /// 可用积分（`GET /user/points`），BigInt 用字符串保精度
  String _pointsBalance = '0';
  int get _pointsValue => int.tryParse(_pointsBalance) ?? 0;

  List<Product> _products = const [];
  bool _loading = true;
  String? _error;

  /// 正在兑换的商品 id，用于 disable 按钮防重复提交
  String? _exchangingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        mallApi.products(),
        pointsApi.summary().catchError((_) => PointsSummary.empty),
      ]);
      if (!mounted) return;
      final summary = results[1] as PointsSummary;
      setState(() {
        _products = results[0] as List<Product>;
        _pointsBalance = summary.balance;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.displayMessage;
        _loading = false;
      });
    }
  }

  List<Product> _filtered(int tab, int userLevel) {
    switch (tab) {
      case 1: // 我的等级池：商品要求等级 ≤ 当前等级
        return _products.where((p) => p.minLevel <= userLevel).toList();
      case 2: // 虚拟权益
        return _products.where((p) => p.isVirtual).toList();
      default:
        return _products;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userLevel = context.watch<AuthProvider>().level;
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
          bottom: const TabBar(
            tabs: [
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
                children: [0, 1, 2]
                    .map((t) => _productGrid(t, _filtered(t, userLevel)))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶部积分横幅
  Widget _pointsBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [kqwPrimary, kqwAccent]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard, color: Colors.white70),
          const SizedBox(width: 8),
          const Text('我的积分', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(width: 8),
          Text(_pointsBalance, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
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

  Widget _productGrid(int tab, List<Product> items) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return _stateView(
        icon: Icons.cloud_off_outlined,
        text: _error!,
        action: TextButton(onPressed: _load, child: const Text('重试')),
      );
    }
    if (items.isEmpty) {
      final text = _products.isEmpty ? '商城暂无商品' : '该分类暂无商品';
      return _stateView(
        icon: Icons.inventory_2_outlined,
        text: text,
        action: TextButton(onPressed: _load, child: const Text('刷新')),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) => _productCard(items[i]),
      ),
    );
  }

  /// 空态/错误态：长文案（如接口错误）在窄屏也可滚动，避免 Column 溢出
  Widget _stateView({required IconData icon, required String text, Widget? action}) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 44, color: Colors.black26),
                  const SizedBox(height: 12),
                  Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black45)),
                  if (action != null) action,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _productCard(Product p) {
    final affordable = _pointsValue >= p.pricePoints;
    final exchanging = _exchangingId == p.id;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _cover(p),
                if (p.minLevel > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8C4B00).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${p.levelLabel} 池', style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ),
              ],
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
                  Text(
                    p.isVirtual ? '虚拟权益 · 自动到账' : '实物 · 兑换后发货',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black45, fontSize: 11),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: '${p.pricePoints}', style: pointsTextStyle(size: 16)),
                              const TextSpan(
                                  text: ' 积分',
                                  style: TextStyle(color: Colors.black54, fontSize: 12)),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 30),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          backgroundColor: affordable ? kqwPrimary : Colors.grey.shade400,
                        ),
                        onPressed: (affordable && !exchanging) ? () => _confirmExchange(p) : null,
                        child: exchanging
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('兑换'),
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

  /// 封面图：无 cover 或加载失败时回退到占位底图
  Widget _cover(Product p) {
    final fallback = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
        ),
      ),
      child: Icon(_placeholderIcon(p), size: 48, color: const Color(0xFFE53935).withValues(alpha: 0.55)),
    );
    final cover = p.cover;
    if (cover == null || cover.isEmpty) return fallback;
    return Image.network(
      cover,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : fallback,
    );
  }

  IconData _placeholderIcon(Product p) => p.isVirtual ? Icons.redeem_outlined : Icons.inventory_2_outlined;

  Future<void> _confirmExchange(Product p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('兑换「${p.name}」'),
        content: Text('消耗 ${p.pricePoints} 积分，确认兑换？\n（积分先冻结，扣减成功后发货）'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _exchangingId = p.id);
    try {
      await mallApi.exchange(p.id);
      if (!mounted) return;
      showToast(context, '「${p.name}」兑换成功');
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showToast(context, e.displayMessage);
    } finally {
      if (mounted) setState(() => _exchangingId = null);
    }
  }
}
