import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api/pos_api.dart';
import '../core/api_client.dart';
import '../core/models/machine.dart';
import '../core/theme.dart';
import '../core/toast.dart';
import '../core/widgets/async_view.dart';

/// 我的机器（FR-3.x：机器编号 / 开机时间 / 推荐人 / 新手任务完成状态）
///
/// 数据源 `GET /pos/machines`；提交达标走 `POST /pos/newbie/submit`，
/// 新增机器跳 `/machine/add`（该页目前只有 UI，接口未接）。
class MachinesPage extends StatefulWidget {
  const MachinesPage({super.key});

  @override
  State<MachinesPage> createState() => _MachinesPageState();
}

class _MachinesPageState extends State<MachinesPage> {
  List<Machine> _machines = const [];
  bool _loading = true;
  String? _error;
  String? _busySn;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 新增机器页返回后刷新列表：新机器要等后台审核通过才出现，刷新不亏
  Future<void> _openAddMachine() async {
    final submitted = await context.push<bool>('/machine/add');
    if (submitted == true && mounted) await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await posApi.machines();
      if (!mounted) return;
      setState(() {
        _machines = page.items;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _machines = const [];
        _error = e.displayMessage;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitNewbie(Machine m) async {
    setState(() => _busySn = m.sn);
    try {
      await posApi.submitNewbie(m.sn);
      if (!mounted) return;
      showToast(context, '达标申请已提交，后台人工审核通过后发放奖励');
      await _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.displayMessage);
    } finally {
      if (mounted) setState(() => _busySn = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的机器')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddMachine,
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('添加新机器'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: AsyncStateView(
          loading: _loading,
          error: _error,
          isEmpty: _machines.isEmpty,
          onRetry: _load,
          emptyText: '还没有机器，点右下角申请装机',
          emptyIcon: Icons.point_of_sale_outlined,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: _machines.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _machineCard(_machines[i]),
          ),
        ),
      ),
    );
  }

  Widget _machineCard(Machine m) {
    final (statusColor, statusText) = switch (m.newbieStatus) {
      3 => (const Color(0xFF3F8600), '新手任务已完成'),
      2 => (const Color(0xFFE53935), '审核中'),
      _ => (const Color(0xFFB25E00), m.newbieStatusName.isEmpty ? '新手任务进行中' : m.newbieStatusName),
    };
    final progress = m.progress;
    final busy = _busySn == m.sn;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.point_of_sale, size: 18, color: kqwPrimary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(m.sn,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoItem(Icons.schedule, '开机时间', formatShortTime(m.bootedAt)),
            _infoItem(Icons.dvr, '机器型号', m.model.isEmpty ? '—' : m.model),
            _infoItem(
              Icons.person_outline,
              '推荐人',
              m.referredBy == null
                  ? '—（自装机）'
                  : '${m.referredBy!.phone}（${m.referredBy!.levelLabel}）',
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        switch (m.newbieStatus) {
                          3 => Icons.task_alt,
                          2 => Icons.hourglass_bottom,
                          _ => Icons.pending_actions,
                        },
                        size: 16,
                        color: statusColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '已刷 ¥${progress.amount} / ${progress.target}'
                          '${progress.daysLeft > 0 ? ' · 剩 ${progress.daysLeft} 天' : ''}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.ratio,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(statusColor),
                    ),
                  ),
                ],
              ),
            ),
            if (m.newbieStatus == 0 || m.newbieStatus == 1) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kqwPrimary,
                    side: const BorderSide(color: kqwPrimary),
                    minimumSize: const Size(0, 38),
                  ),
                  onPressed: busy ? null : () => _submitNewbie(m),
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(busy ? '提交中…' : '提交达标'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: Colors.black45),
          const SizedBox(width: 6),
          SizedBox(
              width: 64,
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 13, color: Colors.black54))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 13, color: Colors.black87))),
        ],
      ),
    );
  }
}
