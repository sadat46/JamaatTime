import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import '../core/app_locale_controller.dart';
import '../core/app_text.dart';
import '../core/constants.dart';
import '../core/locale_prefs.dart';
import '../models/location_config.dart';
import '../services/jamaat_service.dart';
import '../services/location_config_service.dart';
import '../services/prayer_aux_calculator.dart';
import '../services/prayer_time_engine.dart';
import '../services/settings_service.dart';
import '../utils/bangla_calendar.dart';
import '../firebase_options.dart';
import 'hijri_date_converter.dart';

/// Top-level background callback for home widget refresh button.
/// Must be top-level (not inside a class) for home_widget background execution.
@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {
    // Firebase is optional for widget refresh; Jamaat data will fall back to N/A.
  }

  try {
    final prefs = await SharedPreferences.getInstance();
    final locale = LocalePrefs.toLocale(LocalePrefs.readFromPrefs(prefs));
    final isGpsMode = prefs.getBool('is_gps_mode') ?? false;
    final savedCity = prefs.getString('selected_city');
    final lastLat = prefs.getDouble('last_latitude');
    final lastLng = prefs.getDouble('last_longitude');
    final madhabStr = prefs.getString('madhab') ?? 'hanafi';
    final hijriOffset =
        prefs.getInt('bangladesh_hijri_offset_days') ??
        SettingsService.defaultBangladeshHijriOffsetDays;

    final configService = LocationConfigService();
    LocationConfig config;
    Coordinates coords;

    if (isGpsMode && lastLat != null && lastLng != null) {
      final locationName =
          prefs.getString('last_location_name') ?? 'GPS Location';
      config = LocationConfig.world(locationName, lastLat, lastLng);
      coords = Coordinates(lastLat, lastLng);
    } else {
      final cityName = savedCity ?? AppConstants.defaultCity;
      config = configService.getConfigForCity(cityName);
      coords = Coordinates(config.latitude, config.longitude);
    }

    final calcService = PrayerTimeEngine.instance;
    final params = calcService.getCalculationParametersForConfig(config);

    if (config.country == Country.bangladesh) {
      params.madhab = madhabStr == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    }

    final now = DateTime.now();
    final prayerTimes = PrayerTimes(
      coordinates: coords,
      date: now,
      calculationParameters: params,
      precision: true,
    );

    final times = calcService.createPrayerTimesMap(prayerTimes);
    final effectiveHijriOffset = config.country == Country.bangladesh
        ? hijriOffset
        : 0;

    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    final tomorrowTimes = PrayerTimes(
      coordinates: coords,
      date: tomorrow,
      calculationParameters: params,
      precision: true,
    );
    final tomorrowMap = calcService.createPrayerTimesMap(tomorrowTimes);
    Map<String, dynamic>? widgetJamaatTimes;

    if (config.jamaatSource == JamaatSource.localOffset) {
      widgetJamaatTimes = PrayerAuxCalculator.instance.buildOffsetJamaatTimes(
        prayerTimes: times,
        offsets: config.jamaatOffsets,
      );
    } else if (config.jamaatSource == JamaatSource.server) {
      final cityForJamaat = savedCity ?? config.cityName;
      final serverTimes = await JamaatService().getJamaatTimes(
        city: cityForJamaat,
        date: now,
      );
      if (serverTimes != null) {
        widgetJamaatTimes = Map<String, dynamic>.from(serverTimes);
        final maghribJamaat = PrayerAuxCalculator.instance
            .calculateMaghribJamaatTime(
              maghribPrayerTime: times['Maghrib'],
              selectedCity: cityForJamaat,
            );
        if (maghribJamaat != '-') {
          widgetJamaatTimes['maghrib'] = maghribJamaat;
        }
      }
    }

    final placeName = prefs.getString('last_location_name');
    await WidgetService.updateWidgetData(
      times: times,
      locale: locale,
      locationName: placeName ?? config.cityName,
      date: now,
      hijriOffsetDays: effectiveHijriOffset,
      tomorrowFajr: tomorrowMap['Fajr'],
      jamaatTimes: widgetJamaatTimes,
    );
  } catch (e) {
    // Background callback errors are non-fatal
  }
}

class WidgetService {
  static const String _androidWidgetName = 'PrayerWidgetProvider';
  static const _fmt = 'hh:mm a';

  static Future<void> updateWidgetData({
    required Map<String, DateTime?> times,
    required Locale locale,
    required String locationName,
    required DateTime date,
    required int hijriOffsetDays,
    DateTime? tomorrowFajr,
    Map<String, dynamic>? jamaatTimes,
  }) async {
    try {
      final now = DateTime.now();
      final timeFormat = DateFormat(_fmt);
      final widgetData = computeWidgetPreviewData(
        times: times,
        locale: locale,
        now: now,
        timeFormat: timeFormat,
        tomorrowFajr: tomorrowFajr,
        jamaatTimes: jamaatTimes,
      );

      final hijriDate = HijriDateConverter.formatHijriDate(
        date,
        dayOffset: hijriOffsetDays,
      );
      final banglaDate = BanglaCalendar.fromGregorian(date);

      await Future.wait([
        HomeWidget.saveWidgetData<String>('prayer_name', widgetData.prayerName),
        HomeWidget.saveWidgetData<String>('prayer_time', widgetData.prayerTime),
        HomeWidget.saveWidgetData<String>(
          'remaining_label',
          widgetData.remainingLabel,
        ),
        HomeWidget.saveWidgetData<int>(
          'next_prayer_epoch_millis',
          widgetData.nextPrayerEpochMillis,
        ),
        HomeWidget.saveWidgetData<bool>(
          'countdown_running',
          widgetData.countdownRunning,
        ),
        HomeWidget.saveWidgetData<String>('jamaat_label', widgetData.jamaatLabel),
        HomeWidget.saveWidgetData<int>(
          'jamaat_epoch_millis',
          widgetData.jamaatEpochMillis,
        ),
        HomeWidget.saveWidgetData<bool>(
          'jamaat_countdown_running',
          widgetData.jamaatCountdownRunning,
        ),
        // 4 dynamic prayer row slots
        HomeWidget.saveWidgetData<String>(
          'row_label_1',
          widgetData.rowLabels[0],
        ),
        HomeWidget.saveWidgetData<String>('row_time_1', widgetData.rowTimes[0]),
        HomeWidget.saveWidgetData<String>(
          'row_label_2',
          widgetData.rowLabels[1],
        ),
        HomeWidget.saveWidgetData<String>('row_time_2', widgetData.rowTimes[1]),
        HomeWidget.saveWidgetData<String>(
          'row_label_3',
          widgetData.rowLabels[2],
        ),
        HomeWidget.saveWidgetData<String>('row_time_3', widgetData.rowTimes[2]),
        HomeWidget.saveWidgetData<String>(
          'row_label_4',
          widgetData.rowLabels[3],
        ),
        HomeWidget.saveWidgetData<String>('row_time_4', widgetData.rowTimes[3]),
        HomeWidget.saveWidgetData<String>(
          'islamic_date',
          '$hijriDate  |  $banglaDate',
        ),
        HomeWidget.saveWidgetData<String>('location', locationName),
      ]);

      await HomeWidget.updateWidget(androidName: _androidWidgetName);
    } catch (e) {
      // Widget updates are best-effort, never block the app
    }
  }

  static Future<void> forceRefresh({
    required Map<String, DateTime?> times,
    required String locationName,
    required DateTime date,
    required int hijriOffsetDays,
    DateTime? tomorrowFajr,
    Map<String, dynamic>? jamaatTimes,
  }) async {
    Locale locale;
    try {
      locale = AppLocaleController.instance.current;
    } catch (_) {
      final code = await LocalePrefs.read();
      locale = LocalePrefs.toLocale(code);
    }

    await updateWidgetData(
      times: times,
      locale: locale,
      locationName: locationName,
      date: date,
      hijriOffsetDays: hijriOffsetDays,
      tomorrowFajr: tomorrowFajr,
      jamaatTimes: jamaatTimes,
    );
  }

  @visibleForTesting
  static WidgetPreviewData computeWidgetPreviewData({
    required Map<String, DateTime?> times,
    required Locale locale,
    required DateTime now,
    required DateFormat timeFormat,
    DateTime? tomorrowFajr,
    Map<String, dynamic>? jamaatTimes,
  }) {
    final strings = AppText.of(locale);
    final engine = PrayerTimeEngine.instance;
    final currentPeriod = engine.getCurrentPrayerPeriod(times: times, now: now);
    final nextPeriod = engine.getNextPrayerForWidget(times: times, now: now);
    final currentMainPrayer = engine.getCurrentPrayerForWidget(
      times: times,
      now: now,
    );
    final currentPeriodTime = times[currentPeriod];
    final todayNextTime = times[nextPeriod];

    // After Isha, next period falls back to "Fajr" but today's Fajr is in the
    // past. Use tomorrow's Fajr so the countdown remains valid.
    final effectiveNextTime =
        (todayNextTime != null && now.isBefore(todayNextTime))
        ? todayNextTime
        : tomorrowFajr;
    final countdownRunning =
        effectiveNextTime != null && now.isBefore(effectiveNextTime);
    final nextEpochMillis = countdownRunning
        ? effectiveNextTime.millisecondsSinceEpoch
        : 0;

    // Row 2 remains main-prayer focused and excludes the current main prayer.
    final rowPrayers = PrayerTimeEngine.mainPrayerOrder
        .where((p) => p != currentMainPrayer)
        .take(4)
        .toList();
    while (rowPrayers.length < 4) {
      rowPrayers.add('-');
    }
    final rowLabels = rowPrayers
        .map((name) => name == '-' ? '-' : _localizedPrayerName(locale, name))
        .toList(growable: false);
    final rowTimes = rowPrayers
        .map((name) => _formatPrayerTime(times[name], timeFormat))
        .toList(growable: false);

    final remainingLabel = currentPeriod == 'Sunrise'
        ? strings.widget_comingDhuhr
        : strings.widget_timeRemaining(_localizedPrayerName(locale, currentPeriod));
    final jamaatPrayerName = currentPeriod == 'Sunrise'
        ? 'Dhuhr'
        : currentMainPrayer;
    final jamaatStatus = _computeJamaatWidgetState(
      now: now,
      locale: locale,
      jamaatPrayerName: jamaatPrayerName,
      jamaatTimes: jamaatTimes,
    );

    return WidgetPreviewData(
      prayerName: _localizedPrayerName(locale, currentPeriod),
      prayerTime: _formatPrayerTime(currentPeriodTime, timeFormat),
      remainingLabel: remainingLabel,
      nextPrayerEpochMillis: nextEpochMillis,
      countdownRunning: countdownRunning,
      jamaatLabel: jamaatStatus.label,
      jamaatEpochMillis: jamaatStatus.epochMillis,
      jamaatCountdownRunning: jamaatStatus.countdownRunning,
      rowLabels: rowLabels,
      rowTimes: rowTimes,
    );
  }

  static String _localizedPrayerName(Locale locale, String prayerKey) {
    final strings = AppText.of(locale);
    switch (prayerKey) {
      case 'Fajr':
        return strings.prayer_fajr;
      case 'Sunrise':
        return strings.prayer_sunrise;
      case 'Dhuhr':
        return strings.prayer_dhuhr;
      case 'Asr':
        return strings.prayer_asr;
      case 'Maghrib':
        return strings.prayer_maghrib;
      case 'Isha':
        return strings.prayer_isha;
      default:
        return prayerKey;
    }
  }

  static String _formatPrayerTime(DateTime? time, DateFormat fmt) {
    if (time == null) return '-';
    return fmt.format(time.toLocal());
  }

  static _JamaatWidgetState _computeJamaatWidgetState({
    required DateTime now,
    required Locale locale,
    required String jamaatPrayerName,
    required Map<String, dynamic>? jamaatTimes,
  }) {
    if (jamaatTimes == null || jamaatTimes.isEmpty) {
      return _JamaatWidgetState.na(locale);
    }

    final jamaatKey = PrayerAuxCalculator.instance.getJamaatTimeKey(
      jamaatPrayerName,
    );
    final raw = jamaatTimes[jamaatKey];
    if (raw == null || raw.toString().trim().isEmpty) {
      return _JamaatWidgetState.na(locale);
    }

    final normalized = PrayerAuxCalculator.instance.formatJamaatTime(
      raw.toString(),
    );
    final jamaatTime = _parseTodayJamaatTime(now, normalized);
    if (jamaatTime == null) {
      return _JamaatWidgetState.na(locale);
    }

    if (now.isBefore(jamaatTime)) {
      final strings = AppText.of(locale);
      final prayerLabel = _localizedPrayerName(locale, jamaatPrayerName);
      return _JamaatWidgetState(
        label: '$prayerLabel ${strings.widget_jamaatInSuffix}',
        epochMillis: jamaatTime.millisecondsSinceEpoch,
        countdownRunning: true,
      );
    }
    return _JamaatWidgetState.over(locale);
  }

  static DateTime? _parseTodayJamaatTime(DateTime now, String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return DateTime(now.year, now.month, now.day, hour, minute);
  }
}

@immutable
class WidgetPreviewData {
  final String prayerName;
  final String prayerTime;
  final String remainingLabel;
  final int nextPrayerEpochMillis;
  final bool countdownRunning;
  final String jamaatLabel;
  final int jamaatEpochMillis;
  final bool jamaatCountdownRunning;
  final List<String> rowLabels;
  final List<String> rowTimes;

  const WidgetPreviewData({
    required this.prayerName,
    required this.prayerTime,
    required this.remainingLabel,
    required this.nextPrayerEpochMillis,
    required this.countdownRunning,
    required this.jamaatLabel,
    required this.jamaatEpochMillis,
    required this.jamaatCountdownRunning,
    required this.rowLabels,
    required this.rowTimes,
  });
}

@immutable
class _JamaatWidgetState {
  final String label;
  final int epochMillis;
  final bool countdownRunning;

  const _JamaatWidgetState({
    required this.label,
    required this.epochMillis,
    required this.countdownRunning,
  });

  factory _JamaatWidgetState.na(Locale locale) {
    final strings = AppText.of(locale);
    return _JamaatWidgetState(
      label: strings.widget_jamaatNA,
      epochMillis: 0,
      countdownRunning: false,
    );
  }

  factory _JamaatWidgetState.over(Locale locale) {
    final strings = AppText.of(locale);
    return _JamaatWidgetState(
      label: strings.widget_jamaatOver,
      epochMillis: 0,
      countdownRunning: false,
    );
  }
}
