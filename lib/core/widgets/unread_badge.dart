import 'package:flutter/material.dart';

/// 未读红点角标：`count <= 0` 不渲染，超过 99 显示 `99+`。
///
/// 首页消息入口与「我的」宫格原本各写了一份同样的 Stack/Positioned/红底 Container，
/// 调样式或改截断阈值时必须同步两处；抽成组件后只改这里。
///
/// 用法：直接放进 [Stack] 的 children（内部返回 [Positioned]）。
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({
    super.key,
    required this.count,
    this.right = -4,
    this.top = -4,
  });

  final int count;
  final double right;
  final double top;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Positioned(
      right: right,
      top: top,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        constraints: const BoxConstraints(minWidth: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFE53935),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: Colors.white, height: 1.2),
        ),
      ),
    );
  }
}
