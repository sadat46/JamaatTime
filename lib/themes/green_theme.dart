import 'package:flutter/material.dart';
import '../core/constants.dart';

final ThemeData greenTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppConstants.brandGreen,
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: AppConstants.brandGreenLight,
  appBarTheme: const AppBarTheme(
    backgroundColor: AppConstants.brandGreen,
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.black87),
    bodyMedium: TextStyle(color: Colors.black87),
    titleMedium: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
  ),
  useMaterial3: true,
); 