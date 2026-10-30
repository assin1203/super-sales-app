import 'package:flutter/material.dart';

import '../../core/api/task_api.dart';
import '../../core/api_client.dart';
import '../../core/models/task_item.dart';
import '../../core/theme.dart';
import '../../core/toast.dart';
import '../../core/widgets/async_view.dart';

/// 任务中心（FR-7.x：新手 30 天包 + 普通周期/成就任务）
///
/// 数据源 `GET /tasks?category=1|2`；领取走 `POST /tasks/{code}/claim`
/// （同 requestNo 重放返回首次结果，重复领取报 42002）。
class TaskTab extends StatefulWidget {
  const TaskTab({super.key});

  @override
  State<TaskTab> createState() => _TaskTabState();
}

class _TaskTabState extends State<TaskTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  /// 分类 → 任务列表（1 新手 / 2 日常）
  final Map<int, List<TaskItem>> _byCategory = {1: const [], 2: const []};
  final Set<int> _loadingCategories = {};
  final Map<int, String?> _errors = {};
  String? _claimingCode;

  @override
  void initState() {
    super.initState();
    _load(1);
    _load(2);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load(int category) async {
    setState(() {
      _loadingCategories.add(category);
      _errors[category] = null;
    });
    try {
      final items = await taskApi.list(category: category);
      if (!mounted) return;
      setState(() => _byCategory[category] = items);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _byCategory[category] = const [];
        _errors[category] = e.displayMessage;
      });
    } finally {
      if (mounted) setState(() => _loadingCategories.remove(category));
    }
  }

  Future<void> _claim(TaskItem task) async {
    if (_claimingCode != null) return;
    setState(() => _claimingCode = task.code);
    try {
      final res = await taskApi.claim(task.code);
      if (!mounted) return;
      showToast(context, '已领取 ${res.rewardPoints} 积分，余额 ${res.pointsBalance}');
      await _load(task.category);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.displayMessage);
    } finally {
      if (mounted) setState(() => _claimingCode = null);
    }
  }

  /// 新手任务剩余天数（取未完成任务里最小的 expireAt）
  String get _newbieCountdown {
    DateTime? nearest;
    for (final task in _byCategory[1] ?? const <TaskItem>[]) {
      if (task.claimed) continue;
      final expire = task.expireAt;
      if (expire == null) continue;
      if (nearest == null || expire.isBefore(nearest)) nearest = expire;
    }
    if (nearest == null) return '新手任务';
    final days = nearest.difference(DateTime.now()).inDays;
    return '新手任务（剩 ${days < 0 ? 0 : days} 天）';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('任务中心'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: kqwPrimary,
          unselectedLabelColor: Colors.black54,
          indicatorColor: kqwPrimary,
          tabs: [Tab(text: _newbieCountdown), const Tab(text: '普通任务')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_list(1), _list(2)],
      ),
    );
  }

  Widget _list(int category) {
    final items = _byCategory[category] ?? const <TaskItem>[];
    return RefreshIndicator(
      onRefresh: () => _load(category),
      child: AsyncStateView(
        loading: _loadingCategories.contains(category),
        error: _errors[category],
        isEmpty: items.isEmpty,
        onRetry: () => _load(category),
        emptyText: category == 1 ? '暂无新手任务' : '暂无日常任务',
        emptyIcon: Icons.task_alt_outlined,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _taskCard(items[i]),
        ),
      ),
    );
  }

  Widget _taskCard(TaskItem task) {
    final claimed = task.claimed;
    final claimable = task.claimable;
    final busy = _claimingCode == task.code;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: claimed
                      ? const Color(0xFF3F8600)
                      : claimable
                          ? kqwPrimary
                          : Colors.grey.shade300,
                  child: Icon(
                    claimed
                        ? Icons.check
                        : claimable
                            ? Icons.redeem
                            : Icons.radio_button_unchecked,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          decoration: claimed ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (task.description.isNotEmpty)
                        Text(
                          task.description,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black45),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('${task.rewardPoints} 分',
                    style: pointsTextStyle(size: 14)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: task.progress.ratio,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation(kqwPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${task.progress.current}/${task.progress.target}',
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
                const SizedBox(width: 8),
                Text(task.periodLabel,
                    style: const TextStyle(fontSize: 11, color: Colors.black38)),
              ],
            ),
            if (claimable) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: busy ? null : () => _claim(task),
                  style: FilledButton.styleFrom(
                    backgroundColor: kqwPrimary,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(busy ? '领取中…' : '领取奖励'),
                ),
              ),
            ] else if (claimed) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '已领取 ${formatShortTime(task.claimedAt)}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF3F8600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
