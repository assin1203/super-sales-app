import 'package:flutter/material.dart';

/// 品牌主色（与 antd #1677ff 对齐，C 端/后台视觉统一）
const Color kqwPrimary = Color(0xFF1677FF);

final ThemeData kqwTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: kqwPrimary),
  appBarTheme: const AppBarTheme(centerTitle: true),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
  ),
);

/// 积分文字：绿色加粗
TextStyle pointsTextStyle({double size = 16, Color color = const Color(0xFF3F8600)}) =>
    TextStyle(fontSize: size, fontWeight: FontWeight.bold, color: color);
