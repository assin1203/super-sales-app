import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api/pos_api.dart';
import '../core/api_client.dart';
import '../core/models/machine.dart';
import '../core/theme.dart';
import '../core/toast.dart';
import '../core/widgets/async_view.dart';

/// 我的机器（FR-3.x：机器编号 / 开机时间 / 推荐人 / 新手任务完成状态）
///
/// 数据源 `GET /pos/machines`；提交达标走 `POST /pos/newbie/submit`，
/// 装机申请走 `POST /pos/apply`（同手机号 7 天内重复申请会被拦截）。
class MachinesPage extends StatefulWidget {
  const MachinesPage({super.key, this.autoApply = false});

  /// 「我的 → 安装POS」入口带 `?apply=1` 进入时为 true：进页后自动弹出申请装机表单
  final bool autoApply;

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
    if (widget.autoApply) {
      // 等首帧结束再弹，避免在 initState 期间 push 路由/开弹窗
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showApplyForm();
      });
    }
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
        onPressed: _showApplyForm,
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

  Future<void> _showApplyForm() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final merchantCtrl = TextEditingController();
    final regionCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    var submitting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> submit() async {
            final name = nameCtrl.text.trim();
            final phone = phoneCtrl.text.trim();
            if (name.isEmpty || phone.length < 11) {
              showToast(ctx, '请填写联系人和 11 位手机号');
              return;
            }
            setDialogState(() => submitting = true);
            try {
              final res = await posApi.apply(
                contactName: name,
                phone: phone,
                merchantName: merchantCtrl.text.trim(),
                region: regionCtrl.text.trim(),
                address: addressCtrl.text.trim(),
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              showToast(context, '申请已提交（${res.statusName}），客服会尽快联系您');
              await _load();
            } on ApiException catch (e) {
              if (!ctx.mounted) return;
              setDialogState(() => submitting = false);
              showToast(ctx, e.displayMessage);
            }
          }

          return AlertDialog(
            title: const Text('申请装机'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      maxLength: 20,
                      decoration: const InputDecoration(
                        labelText: '联系人',
                        prefixIcon: Icon(Icons.person_outline),
                        counter: SizedBox.shrink(),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      maxLength: 11,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: '联系手机号',
                        prefixIcon: Icon(Icons.phone_outlined),
                        counter: SizedBox.shrink(),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: merchantCtrl,
                      maxLength: 40,
                      decoration: const InputDecoration(
                        labelText: '商户名称（选填）',
                        prefixIcon: Icon(Icons.storefront_outlined),
                        counter: SizedBox.shrink(),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: regionCtrl,
                      maxLength: 30,
                      decoration: const InputDecoration(
                        labelText: '所在地区（省 市 区）',
                        prefixIcon: Icon(Icons.place_outlined),
                        counter: SizedBox.shrink(),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressCtrl,
                      maxLength: 60,
                      decoration: const InputDecoration(
                        labelText: '详细地址（选填）',
                        prefixIcon: Icon(Icons.home_outlined),
                        counter: SizedBox.shrink(),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              FilledButton(
                onPressed: submitting ? null : submit,
                child: Text(submitting ? '提交中…' : '提交申请'),
              ),
            ],
          );
        },
      ),
    );
  }
}
