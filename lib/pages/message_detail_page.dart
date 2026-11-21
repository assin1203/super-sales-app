import 'package:flutter/material.dart';

import '../core/api/message_api.dart';
import '../core/api_client.dart';
import '../core/models/message_item.dart';
import '../core/theme.dart';
import '../core/upgrade_invite.dart';

/// 消息详情（`/messages/:id`）
///
/// 打开即已读（后端在详情接口里标记），页面负责把「谁提交了装机、装的什么机器、
/// 当前审核状态」摆清楚，让装机人不用再跳去别的页面核对。
class MessageDetailPage extends StatefulWidget {
  const MessageDetailPage({super.key, required this.messageId});

  final String messageId;

  @override
  State<MessageDetailPage> createState() => _MessageDetailPageState();
}

class _MessageDetailPageState extends State<MessageDetailPage> {
  MessageDetail? _detail;
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
      final detail = await messageApi.detail(widget.messageId);
      if (!mounted) return;
      setState(() => _detail = detail);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.displayMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 详情页里处理升级邀请：弹窗处理完（或条件已失效）就回列表，由列表刷新
  Future<void> _openUpgrade() async {
    final changed = await openUpgradeInvite(context);
    if (!mounted || !changed) return;
    try {
      await messageApi.markRead([widget.messageId]);
    } catch (_) {
      // 标记已读失败不阻塞返回：列表刷新时会再对齐
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('消息详情')),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Color(0xFF8A94A6))),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    final detail = _detail;
    if (detail == null) return const SizedBox.shrink();
    final message = detail.message;
    final isUpgradeInvite = message.type == kUpgradeInviteMessageType;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (isUpgradeInvite) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kqwPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                message.typeName,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kqwPrimary),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          message.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1F2430)),
        ),
        const SizedBox(height: 6),
        Text(
          _formatDateTime(message.createdAt),
          style: const TextStyle(fontSize: 12, color: Color(0xFF9AA3B2)),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.content,
            style: const TextStyle(fontSize: 14, height: 1.7, color: Color(0xFF3A4250)),
          ),
        ),
        if (detail.apply != null) ...[
          const SizedBox(height: 20),
          const Text(
            '装机申请信息',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F2430)),
          ),
          const SizedBox(height: 10),
          _applyCard(detail.apply!),
        ],
        if (isUpgradeInvite) ...[
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _openUpgrade,
              style: FilledButton.styleFrom(
                backgroundColor: kqwPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('立即处理（升级 / 放弃）'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _applyCard(MessageApply apply) {
    final rows = <Widget>[
      _row('提交人', apply.applicantName.isEmpty
          ? apply.applicantPhone
          : '${apply.applicantName}（${apply.applicantPhone}）'),
      if (apply.applicantLevel > 0) _row('提交人等级', 'L${apply.applicantLevel}'),
      _row('申请单号', apply.requestNo.isEmpty ? '-' : apply.requestNo),
      _row('审核状态', apply.statusName.isEmpty ? '-' : apply.statusName),
      if (apply.contactName.isNotEmpty) _row('使用人', apply.contactName),
      if (apply.phone.isNotEmpty) _row('联系电话', apply.phone),
      if (apply.merchantName.isNotEmpty) _row('商户名称', apply.merchantName),
      if (apply.region.isNotEmpty) _row('所在地区', apply.region),
      if (apply.address.isNotEmpty) _row('详细地址', apply.address),
      if (apply.brand.isNotEmpty || apply.typeName.isNotEmpty)
        _row('机器型号', [apply.brand, apply.typeName].where((e) => e.isNotEmpty).join(' / ')),
      if (apply.machineNo.isNotEmpty) _row('机器号', apply.machineNo),
      _row('提交时间', _formatDateTime(apply.submittedAt)),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDEFF3)),
      ),
      child: Column(children: rows),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF8A94A6))),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF2A3140)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime? time) {
    if (time == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} ${two(time.hour)}:${two(time.minute)}';
  }
}
