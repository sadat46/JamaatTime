import 'package:intl/intl.dart';

class JamaatTimeUtility {
  static JamaatTimeUtility? _instance;
  static JamaatTimeUtility get instance => _instance ??= JamaatTimeUtility._();
  
  JamaatTimeUtility._();

  /// Format jamaat time string to HH:mm format
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

  /// Get Maghrib offset in minutes based on cantt name
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

  /// Calculate Maghrib jamaat time from prayer time with cantt-specific offset
  String calculateMaghribJamaatTime({
    required DateTime? maghribPrayerTime,
    required String? selectedCity,
  }) {
    if (maghribPrayerTime != null && selectedCity != null) {
      final offset = getMaghribOffset(selectedCity);
      
      // Convert to local time before adding offset
      final localMaghribTime = maghribPrayerTime.toLocal();
      final maghribJamaatTime = localMaghribTime.add(Duration(minutes: offset));
      
      return DateFormat('HH:mm').format(maghribJamaatTime);
    }
    return '-';
  }

  /// Map prayer names to jamaat time keys
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
      case 'Dahwah-e-kubrah':
        return prayerName.toLowerCase();
      default:
        return prayerName.toLowerCase();
    }
  }

  /// Get jamaat time string from jamaat times map
  String getJamaatTimeString({
    required Map<String, dynamic>? jamaatTimes,
    required String prayerName,
    required DateTime? maghribPrayerTime,
    required String? selectedCity,
  }) {
    if (prayerName == 'Maghrib') {
      // For Maghrib, use calculated time from prayer time
      return calculateMaghribJamaatTime(
        maghribPrayerTime: maghribPrayerTime,
        selectedCity: selectedCity,
      );
    } else {
      // For other prayers, get from jamaat times map
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
} 