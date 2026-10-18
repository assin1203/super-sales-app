import 'package:flutter/material.dart';

/// 品牌主色：科技蓝
const Color kqwPrimary = Color(0xFF2B5BFF);

/// 辅助色：科技青（用于渐变与点缀）
const Color kqwAccent = Color(0xFF00CFFF);

/// 个人中心头部渐变（深空蓝 → 科技青，科技感）
const LinearGradient kqwHeaderGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF1B3BD4), Color(0xFF2B5BFF), Color(0xFF00A9E8)],
);

/// 页面浅色背景
const Color kqwPageBg = Color(0xFFF4F6FA);

/// 次要文字
const Color kqwTextSecondary = Color(0xFF8A93A6);

final ThemeData kqwTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: kqwPrimary),
  scaffoldBackgroundColor: kqwPageBg,
  appBarTheme: const AppBarTheme(
    centerTitle: true,
    backgroundColor: kqwPageBg,
    foregroundColor: const Color(0xFF1F2430),
    elevation: 0,
    scrolledUnderElevation: 0,
    titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF1F2430)),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFEDF0F5)),
    ),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Colors.white,
    selectedItemColor: kqwPrimary,
    unselectedItemColor: Color(0xFF9AA3B2),
    type: BottomNavigationBarType.fixed,
    showUnselectedLabels: true,
    selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    unselectedLabelStyle: TextStyle(fontSize: 12),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(64, 48),
      backgroundColor: kqwPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
);

/// 积分文字：品牌蓝加粗
TextStyle pointsTextStyle({double size = 16, Color color = kqwPrimary}) =>
    TextStyle(fontSize: size, fontWeight: FontWeight.bold, color: color);
