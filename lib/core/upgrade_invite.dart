import 'package:flutter/material.dart';

import 'api/team_api.dart';
import 'api_client.dart';
import 'models/upgrade_prompt.dart';
import 'toast.dart';
import 'widgets/upgrade_prompt_dialog.dart';

/// 站内消息里「升级邀请」的类型值（与后端 `MESSAGE_TYPE.UPGRADE_PROMPT` 对齐）。
///
/// 这类消息的正文只是提醒，真正的二选一在升级弹窗里完成：
/// 所以点它不跳消息详情，而是现拉一次最新的 `GET /team/upgrade-prompt` 再弹窗。
const String kUpgradeInviteMessageType = 'UPGRADE_PROMPT';

/// 点开一条「升级邀请」消息：先取最新提示，有数据才弹现有升级弹窗。
///
/// 提示为空（`null`）说明这条消息已经过期——奖励已被处理或升级条件不再满足，
/// 这时不弹空窗，直接提示一句由调用方刷新消息列表即可。
///
/// 弹窗内部完成 `POST /team/upgrade-prompt/choice`；用户点「稍后再说」直接关窗。
/// 返回 `true` 表示这条消息的状态已经变化（弹过窗或已失效），调用方应刷新列表。
Future<bool> openUpgradeInvite(BuildContext context, {TeamApi? api}) async {
  final client = api ?? teamApi;

  UpgradePrompt? prompt;
  try {
    prompt = await client.upgradePrompt();
  } on ApiException catch (e) {
    if (context.mounted) showToast(context, e.displayMessage);
    return false;
  } catch (_) {
    if (context.mounted) showToast(context, '加载升级信息失败，请稍后重试');
    return false;
  }

  if (!context.mounted) return false;
  if (prompt == null) {
    showToast(context, '升级条件已变化，这条消息已失效');
    return true;
  }

  await showUpgradePromptDialog(context, prompt: prompt, api: client);
  return true;
}
