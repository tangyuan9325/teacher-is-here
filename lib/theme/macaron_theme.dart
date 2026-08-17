import 'package:flutter/material.dart';

/// 马卡龙色系配色方案
class MacaronColors {
  // 基础马卡龙色
  static const Color pink = Color(0xFFFFB5C5);       // 草莓粉
  static const Color peach = Color(0xFFFFD4B5);      // 蜜桃橙
  static const Color mint = Color(0xFFA8E6CF);       // 薄荷绿
  static const Color lavender = Color(0xFFD4B5E8);   // 薰衣草紫
  static const Color sky = Color(0xFFB5D4E8);        // 天空蓝
  static const Color lemon = Color(0xFFFFF0B5);      // 柠檬黄
  static const Color coral = Color(0xFFFFB5A8);      // 珊瑚色

  // 深色马卡龙（用于文字）
  static const Color darkPink = Color(0xFFE89AAE);
  static const Color darkMint = Color(0xFF7FCFB0);
  static const Color darkLavender = Color(0xFFB89AD4);

  // 中性色
  static const Color textPrimary = Color(0xFF4A4A5A);
  static const Color textSecondary = Color(0xFF8A8A9A);
  static const Color textLight = Color(0xFFB0B0C0);

  // 玻璃效果
  static const Color glassWhite = Color(0x66FFFFFF);
  static const Color glassBorder = Color(0x99FFFFFF);
  static const Color glassHighlight = Color(0xCCFFFFFF);

  /// 渐变背景色组
  static const List<Color> backgroundGradient = [
    Color(0xFFFFE4F0),  // 淡粉
    Color(0xFFE4F0FF),  // 淡蓝
    Color(0xFFF0FFE4),  // 淡绿
    Color(0xFFFFF0E4),  // 淡橙
  ];

  /// 卡片渐变
  static const List<Color> cardGradient = [
    Color(0x80FFFFFF),
    Color(0x40FFFFFF),
  ];

  /// 按钮渐变
  static const List<Color> buttonGradient = [
    Color(0xFFFFB5C5),
    Color(0xFFFFD4B5),
  ];

  /// 启动按钮渐变
  static const List<Color> startButtonGradient = [
    Color(0xFFA8E6CF),
    Color(0xFFB5E8D4),
  ];

  /// 停止按钮渐变
  static const List<Color> stopButtonGradient = [
    Color(0xFFFFB5A8),
    Color(0xFFFFC4B5),
  ];
}

/// 马卡龙主题
class MacaronTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: MacaronColors.pink,
        primary: MacaronColors.pink,
        secondary: MacaronColors.mint,
        surface: Colors.white.withValues(alpha: 0.7),
      ),
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: MacaronColors.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: MacaronColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: MacaronColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: MacaronColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: MacaronColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: MacaronColors.textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
