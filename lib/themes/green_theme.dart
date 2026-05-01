import 'package:flutter/material.dart';
import '../core/app_theme_tokens.dart';

final ThemeData greenTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primaryGreen,
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: AppColors.pageBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.primaryGreen,
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: AppColors.textPrimary),
    bodyMedium: TextStyle(color: AppColors.textPrimary),
    titleMedium: TextStyle(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.bold,
    ),
  ),
  useMaterial3: true,
);
