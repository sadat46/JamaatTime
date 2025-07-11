import 'package:flutter/material.dart';

final ThemeData popularLightTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
  scaffoldBackgroundColor: const Color(0xFFF5F5F5),
  cardColor: Colors.white,
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Color(0xFF22223B)),
    bodyMedium: TextStyle(color: Color(0xFF22223B)),
    titleMedium: TextStyle(color: Color(0xFF22223B), fontWeight: FontWeight.bold),
  ),
  useMaterial3: true,
); 