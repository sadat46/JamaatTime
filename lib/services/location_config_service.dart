import '../core/constants.dart';
import '../models/location_config.dart';

/// Service to manage location configurations and provide location-specific settings
class LocationConfigService {
  static final LocationConfigService _instance =
      LocationConfigService._internal();

  factory LocationConfigService() => _instance;

  LocationConfigService._internal();

  LocationConfig? _currentConfig;

  /// Get the current location configuration
  LocationConfig? get currentConfig => _currentConfig;

  /// Get LocationConfig for a city name
  LocationConfig getConfigForCity(String cityName) {
    // Check if it's a Saudi city
    if (AppConstants.saudiCities.contains(cityName)) {
      switch (cityName) {
        case 'Makkah':
          return LocationConfig.makkah();
        case 'Madinah':
          return LocationConfig.madinah();
        case 'Jeddah':
          return LocationConfig.jeddah();
        default:
          // Fallback to Makkah if unknown Saudi city
          return LocationConfig.makkah();
      }
    }

    // Default to Bangladesh cantonment
    return _getBangladeshConfig(cityName);
  }

  /// Get LocationConfig for a Bangladesh cantonment city
  LocationConfig _getBangladeshConfig(String cityName) {
    // Get coordinates from the constants
    final coords = AppConstants.bangladeshCityCoordinates[cityName];

    if (coords != null) {
      return LocationConfig.bangladeshCantt(
        cityName,
        coords['lat']!,
        coords['lng']!,
      );
    }

    // Fallback to default coordinates if city not found
    return LocationConfig.bangladeshCantt(
      cityName,
      AppConstants.defaultLatitude,
      AppConstants.defaultLongitude,
    );
  }

  /// Detect country from coordinates
  Country detectCountryFromCoordinates(double lat, double lng) {
    // Saudi Arabia bounding box: 16.0-32.0°N, 34.5-55.5°E
    if (lat >= 16.0 && lat <= 32.0 && lng >= 34.5 && lng <= 55.5) {
      return Country.saudiArabia;
    }

    // Bangladesh bounding box: 20.5-26.5°N, 88.0-92.5°E
    if (lat >= 20.5 && lat <= 26.5 && lng >= 88.0 && lng <= 92.5) {
      return Country.bangladesh;
    }

    return Country.other;
  }

  /// Set the current location configuration
  void setCurrentConfig(LocationConfig config) {
    _currentConfig = config;
  }

  /// Get nearest Saudi city from coordinates
  String? getNearestSaudiCity(double lat, double lng) {
    if (detectCountryFromCoordinates(lat, lng) != Country.saudiArabia) {
      return null;
    }

    // Simple distance calculation to find nearest city
    String? nearestCity;
    double minDistance = double.infinity;

    for (final entry in AppConstants.saudiCityCoordinates.entries) {
      final cityLat = entry.value['lat']!;
      final cityLng = entry.value['lng']!;
      final distance = _calculateDistance(lat, lng, cityLat, cityLng);

      if (distance < minDistance) {
        minDistance = distance;
        nearestCity = entry.key;
      }
    }

    return nearestCity;
  }

  /// Calculate approximate distance between two coordinates (in degrees)
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    final dLat = lat1 - lat2;
    final dLng = lng1 - lng2;
    return dLat * dLat + dLng * dLng;
  }
}
