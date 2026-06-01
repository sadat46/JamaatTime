import 'package:shared_preferences/shared_preferences.dart';

import 'location_config.dart';

/// How the user's prayer-time location was determined.
///
/// `manualCity` is reserved for Phase 3 (fallback picker when GPS is denied);
/// Phase 1 only writes `gps`.
enum PrayerLocationMode { gps, manualCity }

/// User's prayer-time location, persisted independently from Jamaat state.
///
/// Set only by GPS in Phase 1. Never written by Jamaat-side flows.
class PrayerLocation {
  const PrayerLocation({
    required this.mode,
    this.city,
    required this.latitude,
    required this.longitude,
    required this.locationName,
    required this.timezone,
    required this.country,
    required this.calculationMethodType,
  });

  final PrayerLocationMode mode;
  final String? city;
  final double latitude;
  final double longitude;
  final String locationName;
  final String timezone;
  final Country country;
  final PrayerCalculationMethodType calculationMethodType;

  static const String _prefMode = 'prayer_location_mode';
  static const String _prefCity = 'prayer_city';
  static const String _prefLat = 'prayer_latitude';
  static const String _prefLng = 'prayer_longitude';
  static const String _prefName = 'prayer_location_name';
  static const String _prefTimezone = 'prayer_timezone';
  static const String _prefCountry = 'prayer_country';
  static const String _prefMethod = 'prayer_calculation_method';

  PrayerLocation copyWith({
    PrayerLocationMode? mode,
    String? city,
    double? latitude,
    double? longitude,
    String? locationName,
    String? timezone,
    Country? country,
    PrayerCalculationMethodType? calculationMethodType,
  }) {
    return PrayerLocation(
      mode: mode ?? this.mode,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      timezone: timezone ?? this.timezone,
      country: country ?? this.country,
      calculationMethodType:
          calculationMethodType ?? this.calculationMethodType,
    );
  }

  /// Build a prayer-only `LocationConfig` for prayer math from this location.
  LocationConfig toLocationConfig() {
    return LocationConfig(
      cityName: locationName,
      country: country,
      timezone: timezone,
      calculationMethodType: calculationMethodType,
      latitude: latitude,
      longitude: longitude,
    );
  }

  static PrayerLocation? readFromPrefs(SharedPreferences prefs) {
    final modeRaw = prefs.getString(_prefMode);
    if (modeRaw == null) return null;
    final lat = prefs.getDouble(_prefLat);
    final lng = prefs.getDouble(_prefLng);
    final name = prefs.getString(_prefName);
    final tz = prefs.getString(_prefTimezone);
    final countryRaw = prefs.getString(_prefCountry);
    final methodRaw = prefs.getString(_prefMethod);
    if (lat == null ||
        lng == null ||
        name == null ||
        tz == null ||
        countryRaw == null ||
        methodRaw == null) {
      return null;
    }
    return PrayerLocation(
      mode: _parseMode(modeRaw),
      city: prefs.getString(_prefCity),
      latitude: lat,
      longitude: lng,
      locationName: name,
      timezone: tz,
      country: _parseCountry(countryRaw),
      calculationMethodType: _parseMethod(methodRaw),
    );
  }

  Future<void> writeToPrefs(SharedPreferences prefs) async {
    await prefs.setString(_prefMode, _encodeMode(mode));
    if (city == null || city!.isEmpty) {
      await prefs.remove(_prefCity);
    } else {
      await prefs.setString(_prefCity, city!);
    }
    await prefs.setDouble(_prefLat, latitude);
    await prefs.setDouble(_prefLng, longitude);
    await prefs.setString(_prefName, locationName);
    await prefs.setString(_prefTimezone, timezone);
    await prefs.setString(_prefCountry, country.name);
    await prefs.setString(_prefMethod, calculationMethodType.name);
  }

  static PrayerLocationMode _parseMode(String raw) {
    switch (raw) {
      case 'manual_city':
        return PrayerLocationMode.manualCity;
      case 'gps':
      default:
        return PrayerLocationMode.gps;
    }
  }

  static String _encodeMode(PrayerLocationMode mode) {
    switch (mode) {
      case PrayerLocationMode.gps:
        return 'gps';
      case PrayerLocationMode.manualCity:
        return 'manual_city';
    }
  }

  static Country _parseCountry(String raw) {
    for (final c in Country.values) {
      if (c.name == raw) return c;
    }
    return Country.other;
  }

  static PrayerCalculationMethodType _parseMethod(String raw) {
    for (final m in PrayerCalculationMethodType.values) {
      if (m.name == raw) return m;
    }
    return PrayerCalculationMethodType.muslimWorldLeague;
  }

  @override
  String toString() =>
      'PrayerLocation(mode: $mode, name: $locationName, country: $country, lat: $latitude, lng: $longitude)';
}
