import 'package:flutter/material.dart';

/// 页面居中的轻提示（替代底部 SnackBar，避免被底部导航/手势区挡住不易看到）
void showToast(BuildContext context, String message) {
  final height = MediaQuery.of(context).size.height;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: Colors.white),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.black87,
        // 本版本 SnackBar 无 alignment 参数，用 margin 手动垂直居中
        margin: EdgeInsets.only(top: (height - 48) / 2, left: 48, right: 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
}
