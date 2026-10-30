import 'package:flutter/material.dart';

import '../core/api/points_api.dart';
import '../core/api_client.dart';
import '../core/models/points_package.dart';
import '../core/theme.dart';
import '../core/toast.dart';
import '../core/widgets/async_view.dart';

/// 积分礼包（`GET /points/packages`）。
///
/// 金额与到账积分由后端定价接口给出；在线支付网关尚未接入，
/// 点击购买只做面向用户的提示，不建待支付订单（见 [_PackagesPageState._onBuyTap]）。
class PackagesPage extends StatefulWidget {
  const PackagesPage({super.key});

  @override
  State<PackagesPage> createState() => _PackagesPageState();
}

class _PackagesPageState extends State<PackagesPage> {
  List<PointsPackage> _packages = const [];
  bool _loading = true;
  String? _error;

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
      final items = await pointsApi.packages();
      if (!mounted) return;
      setState(() {
        _packages = items;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _packages = const [];
        _error = e.displayMessage;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 支付网关未接入：只给面向用户的提示，**不建单**。
  ///
  /// 后端对同一礼包有「已有待支付订单」拦截（50005），未接支付时建单会留下
  /// 无法支付的垃圾单，导致用户之后再点直接报错。接入微信/支付宝网关后，
  /// 这里恢复为 `pointsApi.createPackageOrder` + 唤起收银台。
  void _onBuyTap() {
    showToast(context, '在线支付即将上线，敬请期待');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('积分礼包')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: AsyncStateView(
          loading: _loading,
          error: _error,
          isEmpty: _packages.isEmpty,
          onRetry: _load,
          emptyText: '暂无可购买的礼包',
          emptyIcon: Icons.card_giftcard_outlined,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _packages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _packageCard(_packages[i]),
          ),
        ),
      ),
    );
  }

  Widget _packageCard(PointsPackage pkg) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: kqwHeaderGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                pkg.totalPoints,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(pkg.name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (pkg.tag.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: kqwPrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(pkg.tag,
                              style: const TextStyle(
                                  fontSize: 10, color: kqwPrimary)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pkg.hasBonus
                        ? '${pkg.points} 积分 + 赠 ${pkg.bonusPoints}'
                        : '${pkg.points} 积分',
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF4A5160)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: kqwPrimary,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: _onBuyTap,
              child: Text('¥${pkg.priceAmount}'),
            ),
          ],
        ),
      ),
    );
  }
}
