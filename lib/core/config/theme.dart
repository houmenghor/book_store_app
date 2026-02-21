import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF8226F9);
  static const Color secondary = Color(0xFF9514FB);
  static const Color background = Color(0xFFF5F5F8);
  static const Color card = Colors.white;
  static const Color textMain = Colors.black87;
  static const Color textSecondary = Color(0xFF80889B);
}

final ThemeData appTheme = ThemeData(
  primaryColor: AppColors.primary,
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: const ColorScheme.light(
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    surface: AppColors.card,
  ),
  cardColor: AppColors.card,
  useMaterial3: true,
);
