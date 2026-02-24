import 'package:flutter/material.dart';

final ThemeData whiteTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF388E3C), // Brand Green
    brightness: Brightness.light,
    surface: Colors.white,
    onSurface: Colors.black87,
  ),
  scaffoldBackgroundColor: Colors.white,
  cardColor: Colors.white,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Color(0xFF388E3C),
    elevation: 0,
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.black87),
    bodyMedium: TextStyle(color: Colors.black87),
    titleMedium: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
  ),
  useMaterial3: true,
);
