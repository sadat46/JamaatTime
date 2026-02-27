import 'package:adhan_dart/adhan_dart.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../models/location_config.dart';

/// Represents a forbidden prayer time window
class ForbiddenWindow {
  final String name;
  final DateTime start;
  final DateTime end;

  const ForbiddenWindow({
    required this.name,
    required this.start,
    required this.end,
  });

  /// Check if current time falls within this forbidden window
  bool isActive(DateTime now) {
    return now.isAfter(start) && now.isBefore(end);
  }

  /// Format as time range string (e.g., "05:45 - 06:00")
  String toRangeString() {
    final startStr = DateFormat('HH:mm').format(start.toLocal());
    final endStr = DateFormat('HH:mm').format(end.toLocal());
    return '$startStr - $endStr';
  }
}

class PrayerCalculationService {
  static PrayerCalculationService? _instance;
  static PrayerCalculationService get instance => _instance ??= PrayerCalculationService._();
  
  PrayerCalculationService._();

  /// Initialize timezone data
  void initializeTimeZones() {
    tzdata.initializeTimeZones();
    // Removed timezone forcing to support global usage - device local time will be used
  }

  /// Get calculation parameters for Bangladesh
  CalculationParameters getCalculationParameters(Madhab madhab) {
    final params = CalculationMethod.muslimWorldLeague();
    params.madhab = madhab;
    params.adjustments = Map.from(AppConstants.defaultAdjustments);
    return params;
  }

  /// Get calculation parameters based on LocationConfig
  CalculationParameters getCalculationParametersForConfig(LocationConfig config) {
    // Get the base calculation parameters from the config
    CalculationParameters params = config.getCalculationParameters();

    if (config.country == Country.saudiArabia) {
      // Apply Ramadan adjustment if needed for Saudi Arabia
      if (_isRamadan()) {
        // Isha is 120 min after Maghrib during Ramadan (default is 90)
        // Add an additional 30 minutes adjustment
        params.adjustments = {'isha': 30};
      }
    } else if (config.country == Country.bangladesh) {
      // For Bangladesh, apply default adjustments
      params.adjustments = Map.from(AppConstants.defaultAdjustments);
    } else {
      // For rest of the world (Country.other):
      // Use pure calculation without country-specific adjustments
      // This gives neutral, astronomically accurate prayer times
      params.adjustments = {};
    }

    return params;
  }

  /// Check if current date is during Ramadan (Hijri month 9)
  /// TODO: Implement proper Hijri calendar conversion or use package:hijri_calendar
  bool _isRamadan() {
    // Simplified check - always returns false for now
    // In production, this should use a proper Hijri calendar library
    return false;
  }

  /// Calculate prayer times for given coordinates and date
  PrayerTimes calculatePrayerTimes({
    required Coordinates coordinates,
    required DateTime date,
    required CalculationParameters parameters,
  }) {
    return PrayerTimes(
      coordinates: coordinates,
      date: date,
      calculationParameters: parameters,
      precision: true,
    );
  }

  /// Get default coordinates (Dhaka, Bangladesh)
  Coordinates getDefaultCoordinates() {
    return Coordinates(
      AppConstants.defaultLatitude,
      AppConstants.defaultLongitude,
    );
  }

  /// Create prayer times map from PrayerTimes object
  Map<String, DateTime?> createPrayerTimesMap(PrayerTimes prayerTimes) {
    final fajr = prayerTimes.fajr;
    final sunrise = prayerTimes.sunrise;
    final dhuhr = prayerTimes.dhuhr;
    final asr = prayerTimes.asr;
    final maghrib = prayerTimes.maghrib;
    final isha = prayerTimes.isha;

    return {
      'Fajr': fajr,
      'Sunrise': sunrise,
      'Dhuhr': dhuhr,
      'Asr': asr,
      'Maghrib': maghrib,
      'Isha': isha,
    };
  }

  /// Get current prayer name based on current time and prayer times
  String getCurrentPrayerName({
    required Map<String, DateTime?> times,
    required DateTime now,
    required DateTime selectedDate,
  }) {
    final selectedDateOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final todayOnly = DateTime(now.year, now.month, now.day);
    
    if (selectedDateOnly.isBefore(todayOnly)) {
      // Past date - show last prayer (Isha)
      return 'Isha';
    } else if (selectedDateOnly.isAfter(todayOnly)) {
      // Future date - show first prayer (Fajr)
      return 'Fajr';
    } else {
      // Today - show current prayer
      final order = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
      for (final name in order) {
        final t = times[name];
        if (t != null && now.isBefore(t)) {
          return name;
        }
      }
      return 'Fajr';
    }
  }

  /// Calculate time to next prayer
  Duration getTimeToNextPrayer({
    required Map<String, DateTime?> times,
    required DateTime now,
    required Coordinates coordinates,
    required CalculationParameters params,
  }) {
    final order = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    for (final name in order) {
      final t = times[name];
      if (t != null && now.isBefore(t)) {
        return t.difference(now);
      }
    }
    // Next day's Fajr
    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowPrayerTimes = PrayerTimes(
      coordinates: coordinates,
      date: tomorrow,
      calculationParameters: params,
      precision: true,
    );
    final tomorrowFajr = tomorrowPrayerTimes.fajr;
    return tomorrowFajr != null
        ? tomorrowFajr.difference(now)
        : const Duration();
  }

  /// Get countdown text for display
  String getCountdownText({
    required String currentPrayer,
    required Duration timeToNext,
    required DateTime now,
    required DateTime selectedDate,
  }) {
    final selectedDateOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final todayOnly = DateTime(now.year, now.month, now.day);
    
    if (selectedDateOnly.isBefore(todayOnly)) {
      // Past date
      return 'Viewing past date: ${selectedDate.day} ${_getMonthName(selectedDate.month)} ${selectedDate.year}';
    } else if (selectedDateOnly.isAfter(todayOnly)) {
      // Future date
      return 'Viewing future date: ${selectedDate.day} ${_getMonthName(selectedDate.month)} ${selectedDate.year}';
    } else {
      // Today
      if (currentPrayer == 'Sunrise') {
        return 'Coming Dhuhr';
      }
      String countdown = timeToNext.isNegative
          ? '--:--'
          : '${timeToNext.inHours.toString().padLeft(2, '0')}:${(timeToNext.inMinutes.remainder(60)).toString().padLeft(2, '0')}';
      return '$currentPrayer time remaining: $countdown';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  /// Calculate forbidden prayer time windows
  /// Returns list of ForbiddenWindow objects for the given prayer times
  List<ForbiddenWindow> calculateForbiddenWindows(PrayerTimes pt) {
    final windows = <ForbiddenWindow>[];

    // 1. Sunrise Window: From sunrise for ~15 minutes
    if (pt.sunrise != null) {
      windows.add(ForbiddenWindow(
        name: 'After Sunrise',
        start: pt.sunrise!,
        end: pt.sunrise!.add(const Duration(minutes: 15)),
      ));
    }

    // 2. Zawal Window: ~5 minutes before and after solar zenith (Dhuhr)
    if (pt.dhuhr != null) {
      windows.add(ForbiddenWindow(
        name: 'Zawal (Zenith)',
        start: pt.dhuhr!.subtract(const Duration(minutes: 5)),
        end: pt.dhuhr!.add(const Duration(minutes: 5)),
      ));
    }

    // 3. Sunset Window: ~15 minutes before Maghrib
    if (pt.maghrib != null) {
      windows.add(ForbiddenWindow(
        name: 'Before Sunset',
        start: pt.maghrib!.subtract(const Duration(minutes: 15)),
        end: pt.maghrib!,
      ));
    }

    return windows;
  }
} 