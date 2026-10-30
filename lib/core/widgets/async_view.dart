import 'package:flutter/material.dart';

/// 统一的加载 / 失败 / 空态视图。
///
/// 各页面首次拉取数据时共用：加载中转圈、失败给原因 + 重试按钮、空态给文案。
/// 内部用 LayoutBuilder + 可滚动容器，避免窄屏或键盘弹出时出现溢出。
class AsyncStateView extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.loading,
    required this.error,
    required this.isEmpty,
    required this.onRetry,
    required this.child,
    this.emptyText = '暂无数据',
    this.emptyIcon = Icons.inbox_outlined,
  });

  final bool loading;
  final String? error;
  final bool isEmpty;
  final VoidCallback onRetry;
  final Widget child;
  final String emptyText;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    if (error != null) {
      return _message(
        context,
        icon: Icons.cloud_off_outlined,
        title: '加载失败',
        detail: error!,
        action: TextButton(onPressed: onRetry, child: const Text('重试')),
      );
    }
    if (isEmpty) {
      return _message(
        context,
        icon: emptyIcon,
        title: emptyText,
        detail: '下拉可刷新',
      );
    }
    return child;
  }

  Widget _message(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? detail,
    Widget? action,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 44, color: Colors.black26),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      detail,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.black38),
                    ),
                  ],
                  if (action != null) ...[const SizedBox(height: 4), action],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 时间短格式化：今天显示 HH:mm，其余显示 MM-dd HH:mm
String formatShortTime(DateTime? time) {
  if (time == null) return '';
  final local = time.toLocal();
  final now = DateTime.now();
  final hm =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return hm;
  }
  final md =
      '${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  return '$md $hm';
}

/// 日期短格式化：YYYY-MM-DD
String formatDate(DateTime? time) {
  if (time == null) return '';
  final local = time.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}
