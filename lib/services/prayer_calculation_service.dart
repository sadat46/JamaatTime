import 'package:adhan_dart/adhan_dart.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import '../core/constants.dart';

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

  /// Calculate Dahwah-e-kubrah (midpoint between Fajr and Maghrib)
  /// Represents the midpoint of the Islamic legal day (from start to end of fast)
  /// Formula: Fajr + ((Maghrib - Fajr) / 2)
  DateTime? calculateDahwahKubrah(DateTime? fajr, DateTime? maghrib) {
    if (fajr != null && maghrib != null) {
      final diff = maghrib.difference(fajr);
      return fajr.add(
        Duration(milliseconds: diff.inMilliseconds ~/ 2),
      );
    }
    return null;
  }

  /// Create prayer times map from PrayerTimes object
  Map<String, DateTime?> createPrayerTimesMap(PrayerTimes prayerTimes) {
    final fajr = prayerTimes.fajr;
    final sunrise = prayerTimes.sunrise;
    final dhuhr = prayerTimes.dhuhr;
    final asr = prayerTimes.asr;
    final maghrib = prayerTimes.maghrib;
    final isha = prayerTimes.isha;

    // Calculate Dahwah-e-kubrah (midpoint between Fajr and Maghrib)
    final dahwaKubrah = calculateDahwahKubrah(fajr, maghrib);

    return {
      'Fajr': fajr,
      'Sunrise': sunrise,
      'Dahwah-e-kubrah': dahwaKubrah,
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
      final order = ['Fajr', 'Sunrise', 'Dahwah-e-kubrah', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
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
    final order = ['Fajr', 'Sunrise', 'Dahwah-e-kubrah', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
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
        return 'Coming Dahwa-e-kubrah';
      } else if (currentPrayer == 'Dahwah-e-kubrah') {
        return 'Coming Dhuhr';
      } else {
        String countdown = timeToNext.isNegative
            ? '--:--'
            : '${timeToNext.inHours.toString().padLeft(2, '0')}:${(timeToNext.inMinutes.remainder(60)).toString().padLeft(2, '0')}';
        return '$currentPrayer time remaining: $countdown';
      }
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
} 