import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api/points_api.dart';
import '../core/api_client.dart';
import '../core/models/page_result.dart';
import '../core/models/points_flow.dart';
import '../core/models/points_summary.dart';
import '../core/theme.dart';
import '../core/widgets/async_view.dart';

/// 积分中心：把散在「我的」里的积分能力收到一处。
///
/// 数据源 `GET /user/points`（概览）+ `GET /points/flows`（最近流水）；
/// 二级入口：送积分 `/points/transfer`、明细 `/points-flow`、
/// 礼包 `/packages`、赚积分 `/tasks`。
class PointsCenterPage extends StatefulWidget {
  const PointsCenterPage({super.key, this.api});

  /// 测试注入用；生产走全局 [pointsApi]
  final PointsApi? api;

  @override
  State<PointsCenterPage> createState() => _PointsCenterPageState();
}

class _PointsCenterPageState extends State<PointsCenterPage> {
  /// 首页只预览最近几条，完整列表在流水页
  static const int _recentSize = 5;

  PointsSummary _summary = PointsSummary.empty;
  List<PointsFlowItem> _recent = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final api = widget.api ?? pointsApi;
    try {
      final results = await Future.wait([
        api.summary(),
        api.flows(pageNum: 1, pageSize: _recentSize),
      ]);
      final page = results[1] as PageResult<PointsFlowItem>;
      if (!mounted) return;
      setState(() {
        _summary = results[0] as PointsSummary;
        _recent = page.items.take(_recentSize).toList();
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

  /// 送积分回来若真的转过（页面 pop(true)），刷新余额与流水
  Future<void> _openTransfer() async {
    final changed = await context.push<bool>('/points/transfer');
    if (changed == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kqwPageBg,
      appBar: AppBar(title: const Text('积分中心')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _balanceCard(),
            const SizedBox(height: 12),
            _actions(),
            const SizedBox(height: 16),
            _quickEntries(),
            const SizedBox(height: 16),
            _recentFlowCard(),
          ],
        ),
      ),
    );
  }

  // ---------- 余额卡 ----------

  Widget _balanceCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        gradient: kqwHeaderGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('可用积分',
              style: TextStyle(fontSize: 12, color: Color(0xCCFFFFFF))),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_summary.balance,
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              if (_summary.levelName != null) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(_summary.levelName!,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: const Color(0x33FFFFFF)),
          const SizedBox(height: 10),
          Row(
            children: [
              _stat(_summary.totalEarned, '累计获得'),
              _stat(_summary.totalSpent, '累计消耗'),
              _stat(_summary.frozen, '冻结中'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xB3FFFFFF))),
          ],
        ),
      );

  // ---------- 主操作 ----------

  Widget _actions() {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            icon: Icons.card_giftcard,
            label: '送积分',
            desc: '转给好友',
            onTap: _openTransfer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionButton(
            icon: Icons.receipt_long,
            label: '积分明细',
            desc: '收支记录',
            onTap: () => context.push('/points-flow'),
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required String desc,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kqwPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: kqwPrimary),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(desc,
                    style: const TextStyle(
                        fontSize: 11, color: kqwTextSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 快捷入口 ----------

  Widget _quickEntries() {
    return Row(
      children: [
        Expanded(
          child: _entryTile(
            icon: Icons.savings_outlined,
            title: '积分礼包',
            subtitle: '充值积分',
            onTap: () => context.push('/packages'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _entryTile(
            icon: Icons.task_alt,
            title: '赚积分',
            subtitle: '做任务领取',
            onTap: () => context.push('/tasks'),
          ),
        ),
      ],
    );
  }

  Widget _entryTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: kqwTextSecondary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 10, color: kqwTextSecondary)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, size: 16, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  // ---------- 最近流水 ----------

  Widget _recentFlowCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('最近流水',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              InkWell(
                onTap: () => context.push('/points-flow'),
                child: const Row(
                  children: [
                    Text('全部',
                        style: TextStyle(
                            fontSize: 12, color: kqwTextSecondary)),
                    Icon(Icons.chevron_right,
                        size: 15, color: Colors.black26),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black45)),
                  ),
                  TextButton(onPressed: _load, child: const Text('重试')),
                ],
              ),
            )
          else if (_recent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text('暂无积分记录',
                  style: TextStyle(fontSize: 12, color: Colors.black45)),
            )
          else
            for (final item in _recent) _flowRow(item),
        ],
      ),
    );
  }

  Widget _flowRow(PointsFlowItem item) {
    final income = item.isIncome;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.typeName.isNotEmpty
                      ? item.typeName
                      : (PointsFlowItem.typeLabels[item.flowType] ?? '积分变动'),
                  style: const TextStyle(fontSize: 13),
                ),
                if (item.remark.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(item.remark,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: kqwTextSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.deltaLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: income ? const Color(0xFF2E9E5B) : const Color(0xFF1F2430),
                ),
              ),
              const SizedBox(height: 2),
              Text(formatDate(item.createdAt),
                  style: const TextStyle(
                      fontSize: 10, color: Colors.black38)),
            ],
          ),
        ],
      ),
    );
  }
}
