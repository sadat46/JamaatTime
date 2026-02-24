import 'package:flutter/material.dart';

class AppConstants {
  // ══════════════════════════════════════════════════════════════════════════
  // BRAND COLORS
  // ══════════════════════════════════════════════════════════════════════════

  /// Primary brand green - used for AppBar, buttons, accents
  static const Color brandGreen = Color(0xFF388E3C);

  /// Dark green variant - for dark mode highlights
  static const Color brandGreenDark = Color(0xFF145A32);

  /// Light green variant - for backgrounds
  static const Color brandGreenLight = Color(0xFFE8F5E9);

  /// Dua/Hadith accent purple
  static const Color brandPurple = Color(0xFF6A1B9A);

  /// Ayat/Quran accent blue
  static const Color brandBlue = Color(0xFF1565C0);

  // ══════════════════════════════════════════════════════════════════════════
  // LOCATION DEFAULTS
  // ══════════════════════════════════════════════════════════════════════════

  // Default coordinates (Dhaka, Bangladesh)
  static const double defaultLatitude = 23.8376;
  static const double defaultLongitude = 90.2820;

  // Time zone - REMOVED to support global usage (device local time will be used)
  // static const String defaultTimeZone = 'Asia/Dhaka';

  // Default city
  static const String defaultCity = 'Savar Cantt';
  
  // Prayer time adjustments
  static const Map<String, int> defaultAdjustments = {
    'asr': 1,
    'isha': 2,
  };
  
  // Bangladesh city coordinates
  static const Map<String, Map<String, double>> bangladeshCityCoordinates = {
    'Barishal Cantt': {'lat': 22.7010, 'lng': 90.3535},
    'Bogra Cantt': {'lat': 24.8465, 'lng': 89.3770},
    'Chittagong Cantt': {'lat': 22.3569, 'lng': 91.7832},
    'Dhaka Cantt': {'lat': 23.8103, 'lng': 90.4125},
    'Ghatail Cantt': {'lat': 24.4500, 'lng': 90.1167},
    'Jashore Cantt': {'lat': 23.1667, 'lng': 89.2167},
    'Kumilla Cantt': {'lat': 23.4607, 'lng': 91.1809},
    'Ramu Cantt': {'lat': 21.2000, 'lng': 92.3000},
    'Rangpur Cantt': {'lat': 25.7439, 'lng': 89.2752},
    'Savar Cantt': {'lat': 23.8376, 'lng': 90.2820},
    'Sylhet Cantt': {'lat': 24.8949, 'lng': 91.8687},
  };

  // Saudi Arabia city coordinates
  static const Map<String, Map<String, double>> saudiCityCoordinates = {
    'Makkah': {'lat': 21.4225, 'lng': 39.8262},
    'Madinah': {'lat': 24.5247, 'lng': 39.5692},
    'Jeddah': {'lat': 21.5433, 'lng': 39.1728},
  };

  // Saudi jamaat offsets (minutes after prayer time)
  static const Map<String, int> saudiJamaatOffsets = {
    'fajr': 20,
    'dhuhr': 20,
    'asr': 20,
    'maghrib': 10,
    'isha': 20,
  };

  // Bangladesh city list
  static const List<String> bangladeshCities = [
    'Barishal Cantt',
    'Bogra Cantt',
    'Chittagong Cantt',
    'Dhaka Cantt',
    'Ghatail Cantt',
    'Jashore Cantt',
    'Kumilla Cantt',
    'Ramu Cantt',
    'Rangpur Cantt',
    'Savar Cantt',
    'Sylhet Cantt',
  ];

  // Saudi Arabia city list
  static const List<String> saudiCities = [
    'Makkah',
    'Madinah',
    'Jeddah',
  ];

  // Legacy: Backwards compatibility for canttNames
  static const List<String> canttNames = bangladeshCities;
} 