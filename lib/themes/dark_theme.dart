import 'package:flutter/material.dart';

final ThemeData popularDarkTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
  scaffoldBackgroundColor: const Color(0xFF181A1B),
  cardColor: const Color(0xFF23272A),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.white),
    bodyMedium: TextStyle(color: Colors.white70),
    titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
  ),
  useMaterial3: true,
); 