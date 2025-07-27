class AppConstants {
  // Default coordinates (Dhaka, Bangladesh)
  static const double defaultLatitude = 23.8376;
  static const double defaultLongitude = 90.2820;
  
  // Time zone
  static const String defaultTimeZone = 'Asia/Dhaka';
  
  // Default city
  static const String defaultCity = 'Savar Cantt';
  
  // Prayer time adjustments
  static const Map<String, int> defaultAdjustments = {
    'asr': 1,
    'isha': 2,
  };
  
  // Cantt names
  static const List<String> canttNames = [
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
} 