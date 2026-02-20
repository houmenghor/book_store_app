import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF61B012); // The green from your request
  static const Color textMain = Colors.black87;
  static const Color textSecondary = Colors.grey;
}

final ThemeData appTheme = ThemeData(
  primaryColor: AppColors.primary,
  scaffoldBackgroundColor: Colors.white,
  colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
  useMaterial3: true,
);