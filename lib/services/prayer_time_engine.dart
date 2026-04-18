import 'package:adhan_dart/adhan_dart.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../models/location_config.dart';
import '../utils/bangla_calendar.dart';
import 'hijri_date_converter.dart';

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
  String toRangeString({String languageCode = 'en'}) {
    final localeCode = languageCode.toLowerCase() == 'bn' ? 'bn' : 'en';
    final startStr = DateFormat('HH:mm', localeCode).format(start.toLocal());
    final endStr = DateFormat('HH:mm', localeCode).format(end.toLocal());
    final range = '$startStr - $endStr';
    if (localeCode == 'bn') {
      return BanglaCalendar.toBanglaDigits(range);
    }
    return range;
  }
}

/// Centralised prayer-time calculation engine.
///
/// Renamed from `PrayerCalculationService` for clarity.  Every screen that
/// needs prayer times, current-prayer resolution, or countdown math should
/// call through this singleton instead of constructing its own
/// `PrayerTimes` / looping over orderings locally.
class PrayerTimeEngine {
  static PrayerTimeEngine? _instance;
  static PrayerTimeEngine get instance => _instance ??= PrayerTimeEngine._();

  PrayerTimeEngine._();

  // ──────────────────────────────────────────────────────────────────────────
  // Prayer orderings (shared constants)
  // ──────────────────────────────────────────────────────────────────────────

  /// 6-prayer order including Sunrise — used by the home countdown ring and
  /// any context where "Coming Dhuhr" must appear between Sunrise and Dhuhr.
  static const List<String> periodOrder = [
    'Fajr',
    'Sunrise',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];

  /// 5-prayer order excluding Sunrise — used by the Android home-screen
  /// widget (which has only 5 prayer rows).
  static const List<String> mainPrayerOrder = [
    'Fajr',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];

  // ──────────────────────────────────────────────────────────────────────────
  // Timezone & parameter helpers  (unchanged from PrayerCalculationService)
  // ──────────────────────────────────────────────────────────────────────────

  /// Get calculation parameters for Bangladesh (legacy helper)
  CalculationParameters getCalculationParameters(Madhab madhab) {
    final params = CalculationMethod.muslimWorldLeague();
    params.madhab = madhab;
    params.adjustments = Map.from(AppConstants.defaultAdjustments);
    return params;
  }

  /// Get calculation parameters based on [LocationConfig].
  CalculationParameters getCalculationParametersForConfig(LocationConfig config) {
    CalculationParameters params = config.getCalculationParameters();

    if (config.country == Country.saudiArabia) {
      if (_isRamadan()) {
        params.adjustments = {'isha': 30};
      }
    } else if (config.country == Country.bangladesh) {
      params.adjustments = Map.from(AppConstants.defaultAdjustments);
    } else {
      params.adjustments = {};
    }

    return params;
  }

  bool _isRamadan() {
    return HijriDateConverter.isRamadan(DateTime.now());
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Core calculation
  // ──────────────────────────────────────────────────────────────────────────

  /// Calculate prayer times for given coordinates and date.
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

  /// Get default coordinates (Dhaka, Bangladesh).
  Coordinates getDefaultCoordinates() {
    return Coordinates(
      AppConstants.defaultLatitude,
      AppConstants.defaultLongitude,
    );
  }

  /// Create prayer times map from [PrayerTimes] object.
  Map<String, DateTime?> createPrayerTimesMap(PrayerTimes prayerTimes) {
    return {
      'Fajr': prayerTimes.fajr,
      'Sunrise': prayerTimes.sunrise,
      'Dhuhr': prayerTimes.dhuhr,
      'Asr': prayerTimes.asr,
      'Maghrib': prayerTimes.maghrib,
      'Isha': prayerTimes.isha,
    };
  }

  // ──────────────────────────────────────────────────────────────────────────
  // "Upcoming prayer" (original semantics from PrayerCalculationService)
  // ──────────────────────────────────────────────────────────────────────────

  /// Returns the *upcoming* prayer name — the first prayer whose time has NOT
  /// yet passed.  For past dates returns `'Isha'`; for future dates `'Fajr'`.
  ///
  /// Used by the home-screen table to format the countdown text below the
  /// header.  **Do NOT confuse** with [getCurrentPrayerPeriod] (which returns
  /// the *currently-active* period).
  String getCurrentPrayerName({
    required Map<String, DateTime?> times,
    required DateTime now,
    required DateTime selectedDate,
  }) {
    final selectedDateOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final todayOnly = DateTime(now.year, now.month, now.day);

    if (selectedDateOnly.isBefore(todayOnly)) return 'Isha';
    if (selectedDateOnly.isAfter(todayOnly)) return 'Fajr';

    for (final name in periodOrder) {
      final t = times[name];
      if (t != null && now.isBefore(t)) return name;
    }
    return 'Fajr';
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Current-prayer resolution  (single core algorithm, thin wrappers)
  // ──────────────────────────────────────────────────────────────────────────

  /// Core: returns the last prayer in [order] whose time has already passed.
  /// Every public "current prayer" method delegates here — the only
  /// difference between call-sites is which prayer list they pass in.
  String _getLastPassedPrayer({
    required List<String> order,
    required Map<String, DateTime?> times,
    required DateTime now,
  }) {
    String current = 'Isha'; // default: after all prayers/periods
    for (final name in order) {
      final t = times[name];
      if (t != null && now.isBefore(t)) break;
      current = name;
    }
    return current;
  }

  /// Returns the last prayer/period whose time has already passed, using the
  /// 6-prayer ordering that *includes* Sunrise.
  ///
  /// This is the **home countdown ring** semantic — when `now` is between
  /// Sunrise and Dhuhr the caller can render "Coming Dhuhr".
  ///
  /// Migrated from `prayer_countdown_widget._getCurrentPrayerPeriodName` and
  /// `widget_service._getCurrentPeriodName`.
  String getCurrentPrayerPeriod({
    required Map<String, DateTime?> times,
    required DateTime now,
  }) {
    return _getLastPassedPrayer(
      order: periodOrder,
      times: times,
      now: now,
    );
  }

  /// Returns the last *main* prayer (5-prayer order, no Sunrise) whose time
  /// has already passed.  Used by the Android home-screen widget to determine
  /// which prayer row to exclude from the 4-row grid.
  ///
  /// Migrated from `widget_service._getCurrentMainPrayerName`.
  String getCurrentPrayerForWidget({
    required Map<String, DateTime?> times,
    required DateTime now,
  }) {
    return _getLastPassedPrayer(
      order: mainPrayerOrder,
      times: times,
      now: now,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Next-prayer resolution
  // ──────────────────────────────────────────────────────────────────────────

  /// Core: returns the first prayer in [order] whose time has NOT yet passed.
  String _getNextUpcomingPrayer({
    required List<String> order,
    required Map<String, DateTime?> times,
    required DateTime now,
  }) {
    for (final name in order) {
      final t = times[name];
      if (t != null && now.isBefore(t)) return name;
    }
    return 'Fajr';
  }

  /// Returns the next period boundary (6-prayer order including Sunrise).
  /// Used by the Android widget to determine the countdown target.
  ///
  /// Migrated from `widget_service._getNextPeriodName`.
  String getNextPrayerForWidget({
    required Map<String, DateTime?> times,
    required DateTime now,
  }) {
    return _getNextUpcomingPrayer(
      order: periodOrder,
      times: times,
      now: now,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Time-to-next-prayer
  // ──────────────────────────────────────────────────────────────────────────

  /// Calculate time remaining until the next prayer.
  ///
  /// Requires non-null [coordinates] and [params].  Falls back to
  /// tomorrow's Fajr when all of today's prayers have passed.
  Duration getTimeToNextPrayer({
    required Map<String, DateTime?> times,
    required DateTime now,
    required Coordinates coordinates,
    required CalculationParameters params,
  }) {
    for (final name in periodOrder) {
      final t = times[name];
      if (t != null && now.isBefore(t)) return t.difference(now);
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
    return tomorrowFajr != null ? tomorrowFajr.difference(now) : Duration.zero;
  }

  /// Null-safe variant of [getTimeToNextPrayer].
  ///
  /// Behaviour mirrors the original `prayer_countdown_widget._getTimeToNextPrayer`:
  ///   - If [coordinates] is null → use [AppConstants.defaultLatitude/defaultLongitude].
  ///   - If [params] is null → return [Duration.zero] (do NOT invent a
  ///     MuslimWorldLeague fallback — the widget doesn't do that today).
  ///
  /// Migrated from `prayer_countdown_widget._getTimeToNextPrayer`.
  Duration getTimeToNextPrayerSafe({
    required Map<String, DateTime?> times,
    required DateTime now,
    Coordinates? coordinates,
    CalculationParameters? params,
  }) {
    for (final name in periodOrder) {
      final t = times[name];
      if (t != null && now.isBefore(t)) return t.difference(now);
    }

    // All prayers passed — calculate tomorrow's Fajr
    final coords = coordinates ??
        Coordinates(AppConstants.defaultLatitude, AppConstants.defaultLongitude);

    if (params != null) {
      final tomorrow = now.add(const Duration(days: 1));
      final tomorrowPrayerTimes = PrayerTimes(
        coordinates: coords,
        date: tomorrow,
        calculationParameters: params,
        precision: true,
      );
      final tomorrowFajr = tomorrowPrayerTimes.fajr;
      if (tomorrowFajr != null) return tomorrowFajr.difference(now);
    }

    return Duration.zero;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Display helpers
  // ──────────────────────────────────────────────────────────────────────────

  /// Get countdown text for display.
  String getCountdownText({
    required String currentPrayer,
    required Duration timeToNext,
    required DateTime now,
    required DateTime selectedDate,
  }) {
    final selectedDateOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final todayOnly = DateTime(now.year, now.month, now.day);

    if (selectedDateOnly.isBefore(todayOnly)) {
      return 'Viewing past date: ${selectedDate.day} ${_getMonthName(selectedDate.month)} ${selectedDate.year}';
    } else if (selectedDateOnly.isAfter(todayOnly)) {
      return 'Viewing future date: ${selectedDate.day} ${_getMonthName(selectedDate.month)} ${selectedDate.year}';
    } else {
      if (currentPrayer == 'Sunrise') return 'Coming Dhuhr';
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

  /// Format a display time and localize digits when needed.
  String formatDisplayTime(
    DateTime? time, {
    String pattern = 'HH:mm',
    String languageCode = 'en',
  }) {
    if (time == null) return '-';
    final localeCode = languageCode.toLowerCase() == 'bn' ? 'bn' : 'en';
    final formatted = DateFormat(pattern, localeCode).format(time.toLocal());
    if (localeCode == 'bn') {
      return BanglaCalendar.toBanglaDigits(formatted);
    }
    return formatted;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Forbidden windows
  // ──────────────────────────────────────────────────────────────────────────

  /// Calculate forbidden prayer time windows.
  List<ForbiddenWindow> calculateForbiddenWindows(PrayerTimes pt) {
    final windows = <ForbiddenWindow>[];

    if (pt.sunrise != null) {
      windows.add(ForbiddenWindow(
        name: 'After Sunrise',
        start: pt.sunrise!,
        end: pt.sunrise!.add(const Duration(minutes: 15)),
      ));
    }

    if (pt.dhuhr != null) {
      windows.add(ForbiddenWindow(
        name: 'Zawal (Zenith)',
        start: pt.dhuhr!.subtract(const Duration(minutes: 5)),
        end: pt.dhuhr!.add(const Duration(minutes: 5)),
      ));
    }

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
