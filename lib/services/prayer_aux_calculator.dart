import 'package:intl/intl.dart';

/// Auxiliary jamaat-time calculations: offset tables, formatting, and
/// derived jamaat-time maps.
///
/// Renamed from `JamaatTimeUtility` for clarity.  Every screen that needs
/// Maghrib offset logic or jamaat-time formatting should call through this
/// singleton.
class PrayerAuxCalculator {
  static PrayerAuxCalculator? _instance;
  static PrayerAuxCalculator get instance =>
      _instance ??= PrayerAuxCalculator._();

  PrayerAuxCalculator._();

  // ──────────────────────────────────────────────────────────────────────────
  // Jamaat-time formatting
  // ──────────────────────────────────────────────────────────────────────────

  /// Parse and normalise a jamaat-time string to `HH:mm` format.
  ///
  /// Accepts both 24-hour (`"14:30"`) and 12-hour (`"02:30 PM"`) inputs.
  /// Returns `'-'` on empty or unparseable input.
  ///
  /// Previously duplicated in `home_screen._formatJamaatTime`.
  String formatJamaatTime(String value) {
    value = value.trim();
    if (value.isEmpty) return '-';
    try {
      final time = DateFormat('HH:mm').parseStrict(value);
      return DateFormat('HH:mm').format(time);
    } catch (_) {
      try {
        final time = DateFormat('hh:mm a').parseStrict(value);
        return DateFormat('HH:mm').format(time);
      } catch (_) {
        return '-';
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Maghrib offset table  (single source of truth)
  // ──────────────────────────────────────────────────────────────────────────

  /// Get Maghrib offset in minutes based on cantonment name.
  ///
  /// Previously duplicated verbatim in `home_screen._getMaghribOffset` and
  /// `admin_jamaat_panel._getMaghribOffset`.
  int getMaghribOffset(String city) {
    switch (city) {
      case 'Savar Cantt':
      case 'Dhaka Cantt':
      case 'Kumilla Cantt':
        return 13;
      case 'Rangpur Cantt':
      case 'Jashore Cantt':
      case 'Bogra Cantt':
        return 10;
      default:
        return 7;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Maghrib jamaat-time calculation
  // ──────────────────────────────────────────────────────────────────────────

  /// Calculate Maghrib jamaat time from a UTC/local prayer time with the
  /// cantonment-specific offset applied.
  ///
  /// Returns `'-'` when either argument is null.
  ///
  /// Previously duplicated in `home_screen._calculateMaghribJamaatTime` and
  /// (with hardcoded coords) `admin_jamaat_panel._calculateMaghribJamaatTime`.
  String calculateMaghribJamaatTime({
    required DateTime? maghribPrayerTime,
    required String? selectedCity,
  }) {
    if (maghribPrayerTime != null && selectedCity != null) {
      final offset = getMaghribOffset(selectedCity);
      final localMaghribTime = maghribPrayerTime.toLocal();
      final maghribJamaatTime =
          localMaghribTime.add(Duration(minutes: offset));
      return DateFormat('HH:mm').format(maghribJamaatTime);
    }
    return '-';
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Prayer-name ↔ jamaat-key mapping
  // ──────────────────────────────────────────────────────────────────────────

  /// Map a display prayer name (`'Fajr'`, `'Dhuhr'`, …) to the lowercase
  /// key used in the jamaat-times Firestore document.
  String getJamaatTimeKey(String prayerName) {
    switch (prayerName) {
      case 'Fajr':
        return 'fajr';
      case 'Dhuhr':
        return 'dhuhr';
      case 'Asr':
        return 'asr';
      case 'Maghrib':
        return 'maghrib';
      case 'Isha':
        return 'isha';
      case 'Sunrise':
        return prayerName.toLowerCase();
      default:
        return prayerName.toLowerCase();
    }
  }

  /// Look up the formatted jamaat-time string for a given prayer.
  ///
  /// For Maghrib the value is *calculated* from the prayer time + offset;
  /// for all other prayers it is read from the [jamaatTimes] map and
  /// normalised via [formatJamaatTime].
  String getJamaatTimeString({
    required Map<String, dynamic>? jamaatTimes,
    required String prayerName,
    required DateTime? maghribPrayerTime,
    required String? selectedCity,
  }) {
    if (prayerName == 'Maghrib') {
      return calculateMaghribJamaatTime(
        maghribPrayerTime: maghribPrayerTime,
        selectedCity: selectedCity,
      );
    } else {
      final jamaatKey = getJamaatTimeKey(prayerName);
      if (jamaatTimes != null && jamaatTimes.containsKey(jamaatKey)) {
        final value = jamaatTimes[jamaatKey];
        if (value != null && value.toString().isNotEmpty) {
          return formatJamaatTime(value.toString());
        }
      }
      return '-';
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Offset-based jamaat-times builder  (for Saudi / localOffset configs)
  // ──────────────────────────────────────────────────────────────────────────

  /// Build a complete jamaat-times map by adding fixed-minute offsets to each
  /// prayer time.
  ///
  /// Previously a local helper in `calendar_screen._buildOffsetJamaatTimes`.
  /// Now shared so notification/admin/home screens can use the same builder.
  Map<String, dynamic> buildOffsetJamaatTimes({
    required Map<String, DateTime?> prayerTimes,
    required Map<String, int>? offsets,
  }) {
    const keyByPrayer = <String, String>{
      'Fajr': 'fajr',
      'Dhuhr': 'dhuhr',
      'Asr': 'asr',
      'Maghrib': 'maghrib',
      'Isha': 'isha',
    };

    final result = <String, dynamic>{};

    for (final entry in keyByPrayer.entries) {
      final prayerName = entry.key;
      final key = entry.value;
      final prayerTime = prayerTimes[prayerName];
      if (prayerTime == null) continue;

      final offsetMinutes = offsets?[key] ?? 0;
      final jamaatTime =
          prayerTime.toLocal().add(Duration(minutes: offsetMinutes));
      result[key] = DateFormat('HH:mm').format(jamaatTime);
    }

    return result;
  }
}
