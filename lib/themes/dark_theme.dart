import 'package:flutter/material.dart';

final ThemeData darkTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF388E3C), // Brand Green
    brightness: Brightness.dark,
    surface: const Color(0xFF23272A),
  ),
  scaffoldBackgroundColor: const Color(0xFF181A1B),
  cardColor: const Color(0xFF23272A),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF23272A),
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.white),
    bodyMedium: TextStyle(color: Colors.white70),
    titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
  ),
  useMaterial3: true,
);
