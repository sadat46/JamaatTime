import 'package:adhan_dart/adhan_dart.dart';
import 'package:timezone/timezone.dart' as tz;

/// Enum representing supported countries
enum Country { bangladesh, saudiArabia, other }

/// Enum representing jamaat time data sources
enum JamaatSource {
  server,      // Fetch from Firebase server
  localOffset, // Calculate using fixed offsets from prayer times
  none,        // No jamaat times available
}

/// Enum representing prayer calculation methods
enum PrayerCalculationMethodType {
  muslimWorldLeague,
  ummAlQura,
}

/// Configuration for a specific location including timezone, calculation method, and jamaat source
class LocationConfig {
  final String cityName;
  final Country country;
  final String timezone;  // IANA timezone string (e.g., 'Asia/Dhaka', 'Asia/Riyadh')
  final PrayerCalculationMethodType calculationMethodType;
  final JamaatSource jamaatSource;
  final double latitude;
  final double longitude;
  final Map<String, int>? jamaatOffsets;  // Minutes after prayer time (for localOffset source)

  const LocationConfig({
    required this.cityName,
    required this.country,
    required this.timezone,
    required this.calculationMethodType,
    required this.jamaatSource,
    required this.latitude,
    required this.longitude,
    this.jamaatOffsets,
  });

  /// Get the actual CalculationParameters for this location
  CalculationParameters getCalculationParameters() {
    switch (calculationMethodType) {
      case PrayerCalculationMethodType.muslimWorldLeague:
        return CalculationMethod.muslimWorldLeague();
      case PrayerCalculationMethodType.ummAlQura:
        return CalculationMethod.ummAlQura();
    }
  }

  /// Factory constructor for Makkah, Saudi Arabia
  factory LocationConfig.makkah() => LocationConfig(
        cityName: 'Makkah',
        country: Country.saudiArabia,
        timezone: 'Asia/Riyadh',
        calculationMethodType: PrayerCalculationMethodType.ummAlQura,
        jamaatSource: JamaatSource.localOffset,
        latitude: 21.4225,
        longitude: 39.8262,
        jamaatOffsets: {
          'fajr': 20,
          'dhuhr': 20,
          'asr': 20,
          'maghrib': 10,
          'isha': 20
        },
      );

  /// Factory constructor for Madinah, Saudi Arabia
  factory LocationConfig.madinah() => LocationConfig(
        cityName: 'Madinah',
        country: Country.saudiArabia,
        timezone: 'Asia/Riyadh',
        calculationMethodType: PrayerCalculationMethodType.ummAlQura,
        jamaatSource: JamaatSource.localOffset,
        latitude: 24.5247,
        longitude: 39.5692,
        jamaatOffsets: {
          'fajr': 20,
          'dhuhr': 20,
          'asr': 20,
          'maghrib': 10,
          'isha': 20
        },
      );

  /// Factory constructor for Jeddah, Saudi Arabia
  factory LocationConfig.jeddah() => LocationConfig(
        cityName: 'Jeddah',
        country: Country.saudiArabia,
        timezone: 'Asia/Riyadh',
        calculationMethodType: PrayerCalculationMethodType.ummAlQura,
        jamaatSource: JamaatSource.localOffset,
        latitude: 21.5433,
        longitude: 39.1728,
        jamaatOffsets: {
          'fajr': 20,
          'dhuhr': 20,
          'asr': 20,
          'maghrib': 10,
          'isha': 20
        },
      );

  /// Factory constructor for Bangladesh cantonment cities
  factory LocationConfig.bangladeshCantt(
    String cityName,
    double lat,
    double lng,
  ) =>
      LocationConfig(
        cityName: cityName,
        country: Country.bangladesh,
        timezone: 'Asia/Dhaka',
        calculationMethodType: PrayerCalculationMethodType.muslimWorldLeague,
        jamaatSource: JamaatSource.server,
        latitude: lat,
        longitude: lng,
      );

  /// Factory constructor for generic world locations (GPS mode)
  /// Uses device local timezone and neutral calculation method
  factory LocationConfig.world(
    String cityName,
    double lat,
    double lng, {
    String? timezone,
  }) {
    // Use provided timezone or detect from device
    final tz.Location location = timezone != null
        ? tz.getLocation(timezone)
        : tz.local;

    return LocationConfig(
      cityName: cityName,
      country: Country.other,
      timezone: location.name,
      calculationMethodType: PrayerCalculationMethodType.muslimWorldLeague,
      jamaatSource: JamaatSource.none,
      latitude: lat,
      longitude: lng,
    );
  }

  @override
  String toString() {
    return 'LocationConfig(city: $cityName, country: $country, timezone: $timezone, source: $jamaatSource)';
  }
}
