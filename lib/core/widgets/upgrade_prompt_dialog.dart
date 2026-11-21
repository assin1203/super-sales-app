import 'package:flutter/material.dart';

import '../api/team_api.dart';
import '../api_client.dart';
import '../models/upgrade_prompt.dart';
import '../toast.dart';

/// 升级提示弹窗：名下有冻结中的装机奖励，问是否升级进房。
///
/// - 「立即升级」：后端自动进下一档房间（扣礼包积分、占位、升 L1/L2），
///   进房升级钩子随即把冻结奖励解冻到本人可用余额；
/// - 「暂不升级」：二次确认后冻结奖励立即转给直接推荐人（无推荐人兜底给自己）；
/// - 右上关闭：本次不处理，下次打开 App / 回到前台还会再问。
///
/// 返回选择结果；用户直接关闭时返回 null。
Future<UpgradeChoiceResult?> showUpgradePromptDialog(
  BuildContext context, {
  required UpgradePrompt prompt,
  TeamApi? api,
}) {
  return showDialog<UpgradeChoiceResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpgradePromptDialog(prompt: prompt, api: api ?? teamApi),
  );
}

class _UpgradePromptDialog extends StatefulWidget {
  const _UpgradePromptDialog({required this.prompt, required this.api});

  final UpgradePrompt prompt;
  final TeamApi api;

  @override
  State<_UpgradePromptDialog> createState() => _UpgradePromptDialogState();
}

class _UpgradePromptDialogState extends State<_UpgradePromptDialog> {
  bool _submitting = false;

  Future<void> _choose({required bool upgrade}) async {
    if (_submitting) return;

    // 放弃升级不可撤回（积分立即转给推荐人），先做一次确认防误触
    if (!upgrade) {
      final confirmed = await _confirmDecline();
      if (confirmed != true || !mounted) return;
    }

    setState(() => _submitting = true);
    try {
      final result = await widget.api.chooseUpgrade(upgrade: upgrade);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showToast(context, e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showToast(context, '操作失败，请稍后重试');
    }
  }

  Future<bool?> _confirmDecline() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃升级'),
        content: Text(
          '放弃后，${widget.prompt.pendingRewardPoints} 积分将立即发放给您的直接推荐人，且无法撤回。确定放弃吗？',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('确定放弃')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.prompt;
    return AlertDialog(
      title: const Text('是否升级'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '您名下 ${p.pendingMachines} 台机器的奖励积分（合计 ${p.pendingRewardPoints} 分）正处于冻结中。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '升级到 ${p.targetLevelName} 并进入「${p.packageName}」房间',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.freeEntry
                        ? '已购买该档位礼包，本次进房不再扣积分'
                        : '需消耗 ${p.entryPoints} 积分（当前可用 ${p.balance} 分）',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '选择升级：冻结的奖励积分立即发放到您的账户。',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
            ),
            Text(
              '选择暂不升级：冻结的奖励积分直接发放给您的推荐人。',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('稍后再说'),
        ),
        TextButton(
          onPressed: _submitting ? null : () => _choose(upgrade: false),
          child: const Text('暂不升级'),
        ),
        FilledButton(
          onPressed: _submitting ? null : () => _choose(upgrade: true),
          child: _submitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('立即升级'),
        ),
      ],
    );
  }
}
