import 'package:adhan_dart/adhan_dart.dart';
import 'package:timezone/timezone.dart' as tz;

/// Enum representing supported countries
enum Country { bangladesh, saudiArabia, other }

/// Enum representing prayer calculation methods
enum PrayerCalculationMethodType {
  muslimWorldLeague,
  ummAlQura,
}

/// Configuration used by the prayer-time math layer only.
///
/// Phase 1 refactor: this object no longer carries Jamaat concerns. Jamaat
/// source/city/offsets are owned by `JamaatLocation` and resolved separately.
class LocationConfig {
  final String cityName;
  final Country country;
  final String timezone;  // IANA timezone string (e.g., 'Asia/Dhaka', 'Asia/Riyadh')
  final PrayerCalculationMethodType calculationMethodType;
  final double latitude;
  final double longitude;

  const LocationConfig({
    required this.cityName,
    required this.country,
    required this.timezone,
    required this.calculationMethodType,
    required this.latitude,
    required this.longitude,
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
  factory LocationConfig.makkah() => const LocationConfig(
        cityName: 'Makkah',
        country: Country.saudiArabia,
        timezone: 'Asia/Riyadh',
        calculationMethodType: PrayerCalculationMethodType.ummAlQura,
        latitude: 21.4225,
        longitude: 39.8262,
      );

  /// Factory constructor for Madinah, Saudi Arabia
  factory LocationConfig.madinah() => const LocationConfig(
        cityName: 'Madinah',
        country: Country.saudiArabia,
        timezone: 'Asia/Riyadh',
        calculationMethodType: PrayerCalculationMethodType.ummAlQura,
        latitude: 24.5247,
        longitude: 39.5692,
      );

  /// Factory constructor for Jeddah, Saudi Arabia
  factory LocationConfig.jeddah() => const LocationConfig(
        cityName: 'Jeddah',
        country: Country.saudiArabia,
        timezone: 'Asia/Riyadh',
        calculationMethodType: PrayerCalculationMethodType.ummAlQura,
        latitude: 21.5433,
        longitude: 39.1728,
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
      latitude: lat,
      longitude: lng,
    );
  }

  @override
  String toString() {
    return 'LocationConfig(city: $cityName, country: $country, timezone: $timezone)';
  }
}
