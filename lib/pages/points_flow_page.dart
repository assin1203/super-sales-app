import 'package:flutter/material.dart';

import '../core/api/points_api.dart';
import '../core/api_client.dart';
import '../core/models/points_flow.dart';
import '../core/models/points_summary.dart';
import '../core/theme.dart';
import '../core/toast.dart';
import '../core/widgets/async_view.dart';

/// 积分流水（FR-4.2：来源类型 / 变动值 / 变动后余额 / 触发事件）
///
/// 数据源 `GET /points/flows`：支持按流水类型筛选、下拉刷新、滚动加载更多。
class PointsFlowPage extends StatefulWidget {
  const PointsFlowPage({super.key});

  @override
  State<PointsFlowPage> createState() => _PointsFlowPageState();
}

class _PointsFlowPageState extends State<PointsFlowPage> {
  static const _pageSize = 20;

  PointsSummary _summary = PointsSummary.empty;
  final List<PointsFlowItem> _items = [];

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _pageNum = 1;
  bool _hasMore = true;

  /// 请求代次：切筛选/下拉刷新会自增，旧响应回来时代次不匹配就丢弃
  int _requestId = 0;

  /// null = 全部，其余为后端 flowType 1~10
  int? _flowType;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final reqId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      // 重载会作废在途的翻页请求，顺带放开它的标志位
      _loadingMore = false;
    });
    try {
      final type = _flowType;
      final results = await Future.wait([
        pointsApi.flows(flowType: type, pageNum: 1, pageSize: _pageSize),
        pointsApi.summary(),
      ]);
      if (!mounted || reqId != _requestId) return;
      final page = results[0] as dynamic;
      _items
        ..clear()
        ..addAll(page.items as List<PointsFlowItem>);
      _summary = results[1] as PointsSummary;
      _pageNum = 1;
      _hasMore = _items.length < page.total;
      _error = null;
    } on ApiException catch (e) {
      if (reqId == _requestId) _error = e.displayMessage;
    } finally {
      if (mounted && reqId == _requestId) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    // 记下当前代次：期间切了筛选或下拉刷新，本次响应就属于上一代，直接丢弃
    final reqId = _requestId;
    setState(() => _loadingMore = true);
    try {
      final page = await pointsApi.flows(
        flowType: _flowType,
        pageNum: _pageNum + 1,
        pageSize: _pageSize,
      );
      if (!mounted || reqId != _requestId) return;
      setState(() {
        _pageNum += 1;
        _items.addAll(page.items);
        _hasMore = _items.length < page.total;
      });
    } on ApiException catch (e) {
      if (mounted && reqId == _requestId) showToast(context, e.displayMessage);
    } finally {
      if (mounted && reqId == _requestId) setState(() => _loadingMore = false);
    }
  }

  Future<void> _selectType(int? type) async {
    if (_flowType == type) return;
    setState(() => _flowType = type);
    await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('积分流水')),
      body: Column(
        children: [
          _summaryBanner(),
          _typeFilter(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAll,
              child: AsyncStateView(
                loading: _loading,
                error: _error,
                isEmpty: _items.isEmpty,
                onRetry: _loadAll,
                emptyText: '暂无积分流水',
                emptyIcon: Icons.receipt_long_outlined,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.pixels >= n.metrics.maxScrollExtent - 120) {
                      _loadMore();
                    }
                    return false;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _items.length + (_loadingMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      if (i >= _items.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      return _flowCard(_items[i]);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: kqwHeaderGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('可用积分', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text(_summary.balance,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('累计获得 ${_summary.totalEarned}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text('累计消耗 ${_summary.totalSpent}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeFilter() {
    const entries = <MapEntry<int?, String>>[
      MapEntry(null, '全部'),
      MapEntry(1, '达标入队'),
      MapEntry(2, '推荐奖励'),
      MapEntry(3, '团队分红'),
      MapEntry(4, '任务奖励'),
      MapEntry(5, '商城兑换'),
      MapEntry(9, '礼包充值'),
      MapEntry(10, '其他'),
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final entry = entries[i];
          final selected = _flowType == entry.key;
          return ChoiceChip(
            label: Text(entry.value, style: const TextStyle(fontSize: 12)),
            selected: selected,
            showCheckmark: false,
            labelStyle: TextStyle(color: selected ? Colors.white : Colors.black54),
            selectedColor: kqwPrimary,
            backgroundColor: Colors.white,
            side: BorderSide(color: selected ? kqwPrimary : Colors.black12),
            onSelected: (_) => _selectType(entry.key),
          );
        },
      ),
    );
  }

  Widget _flowCard(PointsFlowItem item) {
    final income = item.isIncome;
    final color = income ? const Color(0xFF3F8600) : Colors.red;
    final detail = [
      if (item.bizNo.isNotEmpty) item.bizNo,
      formatShortTime(item.createdAt),
    ].where((e) => e.isNotEmpty).join(' · ');
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            income ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
            size: 22,
          ),
        ),
        title: Text(
          item.typeName.isEmpty ? '积分变动' : item.typeName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (detail.isNotEmpty)
              Text(detail,
                  style: const TextStyle(fontSize: 12, color: Colors.black45)),
            if (item.remark.isNotEmpty)
              Text('余额 ${item.balanceAfter} · ${item.remark}',
                  style: const TextStyle(fontSize: 11, color: Colors.black38)),
          ],
        ),
        trailing: Text(item.deltaLabel, style: pointsTextStyle(color: color)),
      ),
    );
  }
}
