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
/// 数据源 `GET /pos/machines`：已装机机器分页 + `applies`（申请中的新增机器）。
/// 同一用户/同一客户手机号可以有多台，申请中的记录在装机完成前也能看到。
/// 提交达标走 `POST /pos/newbie/submit`，新增机器跳 `/machine/add`。
class MachinesPage extends StatefulWidget {
  const MachinesPage({super.key});

  @override
  State<MachinesPage> createState() => _MachinesPageState();
}

class _MachinesPageState extends State<MachinesPage> {
  List<Machine> _machines = const [];
  List<MachineApply> _applies = const [];
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
      final list = await posApi.machines();
      if (!mounted) return;
      setState(() {
        _machines = list.items;
        _applies = list.applies;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _machines = const [];
        _applies = const [];
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
          isEmpty: _machines.isEmpty && _applies.isEmpty,
          onRetry: _load,
          emptyText: '还没有机器，点右下角添加新机器',
          emptyIcon: Icons.point_of_sale_outlined,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (_applies.isNotEmpty) ...[
                _sectionTitle('申请中的机器（${_applies.length}）'),
                for (final apply in _applies) ...[
                  _applyCard(apply),
                  const SizedBox(height: 12),
                ],
              ],
              if (_machines.isNotEmpty) ...[
                _sectionTitle('已装机机器（${_machines.length}）'),
                for (final machine in _machines) ...[
                  _machineCard(machine),
                  const SizedBox(height: 12),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54),
      ),
    );
  }

  /// 申请中的机器：还没落到 pos_task，只展示机号/品牌类型/客户手机号/状态
  Widget _applyCard(MachineApply a) {
    final (statusColor, statusText) = switch (a.status) {
      1 => (const Color(0xFF3F8600), '已通过'),
      2 => (const Color(0xFFE53935), '已拒绝'),
      _ => (const Color(0xFFB25E00), '待处理'),
    };
    final meta = [a.brandName, a.typeName].where((v) => v != null && v.isNotEmpty).join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.qr_code_2, size: 18, color: kqwPrimary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(a.machineNo,
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
                    a.statusName.isEmpty ? statusText : a.statusName,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _infoItem(Icons.phone_iphone, '客户手机号',
                a.customerPhone.isEmpty ? '—' : a.customerPhone),
            _infoItem(Icons.dvr, '品牌/类型', meta.isEmpty ? '—' : meta),
            _infoItem(Icons.schedule, '提交时间', formatShortTime(a.submittedAt)),
          ],
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
