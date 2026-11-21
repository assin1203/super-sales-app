import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api/message_api.dart';
import '../core/api_client.dart';
import '../core/models/message_item.dart';
import '../core/theme.dart';
import '../core/toast.dart';
import '../core/upgrade_invite.dart';

/// 站内消息列表（`/messages`）
///
/// 触发来源：后台把某会员设为团队长并绑定装机人后，该会员伞下有人提交装机申请，
/// 系统就给这名装机人落一条消息（同时推企微群提醒）。点开详情能看到提交人与申请单。
///
/// 交互口径：
/// - 未读用红点标记；点进详情后由后端自动置为已读，返回列表时刷新一次；
/// - 右上角提供「全部已读」，解决消息堆积后逐条点开的负担。
class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  static const _pageSize = 20;

  final List<MessageItem> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _unreadOnly = false;
  bool _markingAll = false;
  String? _error;
  int _unread = 0;
  int _pageNum = 1;
  bool _hasMore = true;

  /// 请求代次：切筛选/刷新会自增，旧响应回来时代次不匹配就丢弃
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final reqId = ++_requestId;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
    });
    try {
      final page =
          await messageApi.list(unreadOnly: _unreadOnly, pageNum: 1, pageSize: _pageSize);
      if (!mounted || reqId != _requestId) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _unread = page.unread;
        _pageNum = 1;
        _hasMore = _items.length < page.total;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted && reqId == _requestId) setState(() => _error = e.displayMessage);
    } finally {
      if (mounted && reqId == _requestId) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final reqId = _requestId;
    setState(() => _loadingMore = true);
    try {
      final page = await messageApi.list(
        unreadOnly: _unreadOnly,
        pageNum: _pageNum + 1,
        pageSize: _pageSize,
      );
      if (!mounted || reqId != _requestId) return;
      setState(() {
        _pageNum += 1;
        _items.addAll(page.items);
        _unread = page.unread;
        _hasMore = _items.length < page.total;
      });
    } on ApiException catch (e) {
      if (mounted && reqId == _requestId) showToast(context, e.displayMessage);
    } finally {
      if (mounted && reqId == _requestId) setState(() => _loadingMore = false);
    }
  }

  Future<void> _switchFilter(bool unreadOnly) async {
    if (_unreadOnly == unreadOnly) return;
    setState(() => _unreadOnly = unreadOnly);
    await _loadAll();
  }

  Future<void> _markAllRead() async {
    if (_unread == 0) {
      showToast(context, '没有未读消息');
      return;
    }
    setState(() => _markingAll = true);
    try {
      await messageApi.markAllRead();
      if (!mounted) return;
      showToast(context, '已全部标记为已读');
      await _loadAll();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.displayMessage);
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  /// 点开详情：后端在详情接口里顺手置为已读，返回后重载一次保证红点准确
  Future<void> _openDetail(MessageItem item) async {
    await context.push('/messages/${item.id}');
    if (!mounted) return;
    await _loadAll();
  }

  /// 列表点击：升级邀请不跳详情，直接弹升级二选一
  ///
  /// 弹过窗（或提示已失效）后把这条标记已读再刷新列表：奖励一旦处理完，
  /// 后端不会再给升级条件，未读红点留着只会让用户反复点进来。
  Future<void> _open(MessageItem item) async {
    if (item.type != kUpgradeInviteMessageType) {
      await _openDetail(item);
      return;
    }
    final changed = await openUpgradeInvite(context);
    if (!mounted || !changed) return;
    try {
      await messageApi.markRead([item.id]);
    } catch (_) {
      // 标记已读失败不影响主流程：下次刷新列表时红点会再对齐
    }
    if (!mounted) return;
    await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_unread > 0 ? '站内消息（$_unread）' : '站内消息'),
        actions: [
          TextButton(
            onPressed: _markingAll ? null : _markAllRead,
            child: _markingAll
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('全部已读'),
          ),
        ],
      ),
      body: Column(
        children: [
          _filterBar(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          _filterChip('全部', !_unreadOnly, () => _switchFilter(false)),
          const SizedBox(width: 8),
          _filterChip(
            _unread > 0 ? '未读 $_unread' : '未读',
            _unreadOnly,
            () => _switchFilter(true),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? kqwPrimary.withValues(alpha: 0.1) : const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? kqwPrimary : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: active ? kqwPrimary : const Color(0xFF4A5160),
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Color(0xFF8A94A6))),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _loadAll, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          _unreadOnly ? '没有未读消息' : '还没有收到消息',
          style: const TextStyle(color: Color(0xFF8A94A6)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          // 距底部 200px 内开始加载下一页，避免滑到底才等
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) _loadMore();
          return false;
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: _items.length + (_loadingMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index >= _items.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            return _messageCard(_items[index]);
          },
        ),
      ),
    );
  }

  Widget _messageCard(MessageItem item) {
    final isUpgradeInvite = item.type == kUpgradeInviteMessageType;
    return GestureDetector(
      onTap: () => _open(item),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.read ? Colors.white : const Color(0xFFFFF7F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.read ? const Color(0xFFEDEFF3) : kqwPrimary.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!item.read)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(color: kqwPrimary, shape: BoxShape.circle),
                  ),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: item.read ? FontWeight.w500 : FontWeight.w700,
                      color: const Color(0xFF1F2430),
                    ),
                  ),
                ),
                Text(
                  _formatTime(item.createdAt),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9AA3B2)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF5A6478)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isUpgradeInvite
                        ? kqwPrimary.withValues(alpha: 0.1)
                        : const Color(0xFFF2F4F7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.typeName,
                    style: TextStyle(
                      fontSize: 11,
                      color: isUpgradeInvite ? kqwPrimary : const Color(0xFF6B7686),
                      fontWeight: isUpgradeInvite ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  isUpgradeInvite ? '去选择' : '查看详情',
                  style: const TextStyle(fontSize: 12, color: kqwPrimary),
                ),
                Icon(
                  isUpgradeInvite ? Icons.arrow_circle_right_outlined : Icons.chevron_right,
                  size: isUpgradeInvite ? 17 : 16,
                  color: kqwPrimary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final isSameDay = time.year == now.year && time.month == now.month && time.day == now.day;
    String two(int n) => n.toString().padLeft(2, '0');
    if (isSameDay) return '${two(time.hour)}:${two(time.minute)}';
    if (time.year == now.year) return '${two(time.month)}-${two(time.day)} ${two(time.hour)}:${two(time.minute)}';
    return '${time.year}-${two(time.month)}-${two(time.day)}';
  }
}
