import 'package:flutter/material.dart';

import '../api/pos_api.dart';
import '../api_client.dart';
import '../models/machine.dart';
import '../toast.dart';

/// 新手达标「双方确认」弹窗：一次可勾选多台机器确认。
///
/// - 点「确认所选」逐台提交，后端逐台返回结果（自动达标 / 等待对方 / 流水不足）
/// - 用户可以「稍后再说」关闭：下次打开 App 或回到前台还会再弹，
///   但自己已经确认过的那台不会再出现在列表里
/// - 返回确认结果；用户直接关闭时返回 null
Future<NewbieConfirmResponse?> showNewbieConfirmDialog(
  BuildContext context, {
  required List<NewbieConfirmPending> pending,
  PosApi? api,
}) {
  return showDialog<NewbieConfirmResponse>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _NewbieConfirmDialog(pending: pending, api: api ?? posApi),
  );
}

class _NewbieConfirmDialog extends StatefulWidget {
  const _NewbieConfirmDialog({required this.pending, required this.api});

  final List<NewbieConfirmPending> pending;
  final PosApi api;

  @override
  State<_NewbieConfirmDialog> createState() => _NewbieConfirmDialogState();
}

class _NewbieConfirmDialogState extends State<_NewbieConfirmDialog> {
  /// 默认全选：弹窗本身就是提醒「这些机器等你确认」，逐个取消比逐个勾更省事
  late final Set<String> _selected = widget.pending.map((item) => item.sn).toSet();
  bool _submitting = false;

  Future<void> _submit() async {
    if (_submitting || _selected.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final result = await widget.api.confirmNewbie(_selected.toList());
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showToast(context, e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showToast(context, '确认失败，请稍后重试');
    }
  }

  void _toggle(String sn, bool? checked) {
    if (_submitting) return;
    setState(() {
      if (checked == true) {
        _selected.add(sn);
      } else {
        _selected.remove(sn);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('机器达标确认'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '以下机器已提交达标，需要你确认。双方确认且累计流水达门槛后自动通过。',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.pending.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) => _item(widget.pending[index], theme),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('稍后再说'),
        ),
        FilledButton(
          onPressed: _submitting || _selected.isEmpty ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('确认所选（${_selected.length}）'),
        ),
      ],
    );
  }

  Widget _item(NewbieConfirmPending item, ThemeData theme) {
    final days = item.daysLeftLive;
    final counterpart = item.counterpartConfirmed ? '对方已确认' : '等待对方确认';
    return CheckboxListTile(
      value: _selected.contains(item.sn),
      onChanged: _submitting ? null : (checked) => _toggle(item.sn, checked),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      title: Text('${item.storeLabel} · ${item.sn}', style: theme.textTheme.bodyMedium),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            '累计流水 ¥${item.amount} / 门槛 ¥${item.target}'
            '${item.reachedTarget ? '' : '（流水未达门槛）'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: item.reachedTarget ? theme.hintColor : theme.colorScheme.error,
            ),
          ),
          Text(
            days == null ? counterpart : '剩余 $days 天 · $counterpart',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
      isThreeLine: true,
    );
  }
}
