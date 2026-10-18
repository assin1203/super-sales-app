import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/toast.dart';

/// 我的机器（FR-3.x：机器编号 / 开机时间 / 推荐人 / 新手任务完成状态）
class MachinesPage extends StatefulWidget {
  const MachinesPage({super.key});

  @override
  State<MachinesPage> createState() => _MachinesPageState();
}

class _MachinesPageState extends State<MachinesPage> {
  final List<_Machine> _machines = [
    _Machine(
      sn: 'SN20261001',
      model: 'KQW-POS A1',
      bootedAt: '2026-10-01 09:12',
      referredBy: '138****1002（L1）',
      status: NewbieStatus.done,
      progress: '25 天内刷满 1000 元',
    ),
    _Machine(
      sn: 'SN20261005',
      model: 'KQW-POS A1',
      bootedAt: '2026-10-05 11:20',
      referredBy: '138****1005（L1）',
      status: NewbieStatus.reviewing,
      progress: '已提交达标申请 · 10-09 16:02',
    ),
    _Machine(
      sn: 'SN20261008',
      model: 'KQW-POS A1',
      bootedAt: '2026-10-08 15:40',
      referredBy: '—（自装机）',
      status: NewbieStatus.doing,
      progress: '已刷 ¥320 / 1000 · 剩 9 天',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的机器')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _submitAddRequest(context),
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('添加新机器'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: _machines.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _machineCard(_machines[i]),
      ),
    );
  }

  Widget _machineCard(_Machine m) {
    final (statusColor, statusText) = switch (m.status) {
      NewbieStatus.done => (const Color(0xFF3F8600), '新手任务已完成'),
      NewbieStatus.reviewing => (const Color(0xFF1677FF), '审核中'),
      NewbieStatus.doing => (const Color(0xFFB25E00), '新手任务进行中'),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 编号 + 新手任务状态
            Row(
              children: [
                const Icon(Icons.point_of_sale, size: 18, color: kqwPrimary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(m.sn, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 信息两列
            _infoItem(Icons.schedule, '开机时间', m.bootedAt),
            _infoItem(Icons.dvr, '机器型号', m.model),
            _infoItem(Icons.person_outline, '推荐人', m.referredBy),
            const SizedBox(height: 4),
            // 新手任务进度
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    switch (m.status) {
                      NewbieStatus.done => Icons.task_alt,
                      NewbieStatus.reviewing => Icons.hourglass_bottom,
                      NewbieStatus.doing => Icons.pending_actions,
                    },
                    size: 16,
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      m.status == NewbieStatus.done
                          ? '新手任务达标：${m.progress}，已入队'
                          : m.status == NewbieStatus.reviewing
                              ? '展时无法自动获取刷卡数据，已提交达标申请待人工审核：${m.progress}'
                              : m.progress,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
            if (m.status == NewbieStatus.doing) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kqwPrimary,
                    side: const BorderSide(color: kqwPrimary),
                    minimumSize: const Size(0, 38),
                  ),
                  onPressed: () => _submitNewbieDone(m),
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text('提交达标'),
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
          SizedBox(width: 64, child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: Colors.black87))),
        ],
      ),
    );
  }

  void _submitAddRequest(BuildContext context) {
    // TODO: 接入 api.post('/machine/apply') 提交装机申请
    showToast(context, '信息已发送到后台，客服会尽快联系您');
  }

  void _submitNewbieDone(_Machine m) {
    // TODO: 接入 api.post('/machine/newbie-submit', body: {sn}) 提交达标申请（无需证明材料，后台人工核实）
    setState(() {
      final now = DateTime.now();
      final pad = (n) => n.toString().padLeft(2, '0');
      m.status = NewbieStatus.reviewing;
      m.progress = '已提交达标申请 · ${now.month}-${pad(now.day)} ${pad(now.hour)}:${pad(now.minute)}';
    });
    showToast(context, '达标申请已提交，后台人工审核通过后会发放奖励（mock）');
  }
}
class _Machine {
  _Machine({
    required this.sn,
    required this.model,
    required this.bootedAt,
    required this.referredBy,
    required this.status,
    required this.progress,
  });

  final String sn; // 机器编号
  final String model;
  final String bootedAt; // 开机时间
  final String referredBy; // 推荐人
  NewbieStatus status; // 新手任务状态
  String progress;
}

/// 新手任务状态（展时无法自动获取刷卡数据，达标需手动提交、后台人工确认）
enum NewbieStatus { doing, reviewing, done }
