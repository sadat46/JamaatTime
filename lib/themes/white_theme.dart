import 'package:flutter/material.dart';

final ThemeData whiteTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.white, brightness: Brightness.light),
  scaffoldBackgroundColor: Colors.white,
  cardColor: Colors.white,
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.black87),
    bodyMedium: TextStyle(color: Colors.black87),
    titleMedium: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
  ),
  useMaterial3: true,
); 