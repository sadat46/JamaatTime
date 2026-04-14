import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import '../core/constants.dart';
import '../models/location_config.dart';
import '../services/location_config_service.dart';
import '../services/prayer_time_engine.dart';
import '../services/settings_service.dart';
import '../utils/bangla_calendar.dart';
import 'hijri_date_converter.dart';

/// Top-level background callback for home widget refresh button.
/// Must be top-level (not inside a class) for home_widget background execution.
@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();

  try {
    final prefs = await SharedPreferences.getInstance();
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

    final placeName = prefs.getString('last_location_name');
    await WidgetService.updateWidgetData(
      times: times,
      locationName: placeName ?? config.cityName,
      date: now,
      hijriOffsetDays: effectiveHijriOffset,
      tomorrowFajr: tomorrowMap['Fajr'],
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
    required String locationName,
    required DateTime date,
    required int hijriOffsetDays,
    DateTime? tomorrowFajr,
  }) async {
    try {
      final now = DateTime.now();
      final timeFormat = DateFormat(_fmt);
      final widgetData = computeWidgetPreviewData(
        times: times,
        now: now,
        timeFormat: timeFormat,
        tomorrowFajr: tomorrowFajr,
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

  @visibleForTesting
  static WidgetPreviewData computeWidgetPreviewData({
    required Map<String, DateTime?> times,
    required DateTime now,
    required DateFormat timeFormat,
    DateTime? tomorrowFajr,
  }) {
    final engine = PrayerTimeEngine.instance;
    final currentPeriod = engine.getCurrentPrayerPeriod(times: times, now: now);
    final nextPeriod = engine.getNextPrayerForWidget(times: times, now: now);
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
    final currentMainPrayer = engine.getCurrentPrayerForWidget(
      times: times,
      now: now,
    );
    final rowPrayers = PrayerTimeEngine.mainPrayerOrder
        .where((p) => p != currentMainPrayer)
        .take(4)
        .toList();
    while (rowPrayers.length < 4) {
      rowPrayers.add('-');
    }
    final rowTimes = rowPrayers
        .map((name) => _formatPrayerTime(times[name], timeFormat))
        .toList(growable: false);

    final remainingLabel = currentPeriod == 'Sunrise'
        ? 'Coming Dhuhr'
        : '$currentPeriod Time Remaining';

    return WidgetPreviewData(
      prayerName: currentPeriod,
      prayerTime: _formatPrayerTime(currentPeriodTime, timeFormat),
      remainingLabel: remainingLabel,
      nextPrayerEpochMillis: nextEpochMillis,
      countdownRunning: countdownRunning,
      rowLabels: rowPrayers,
      rowTimes: rowTimes,
    );
  }

  static String _formatPrayerTime(DateTime? time, DateFormat fmt) {
    if (time == null) return '-';
    return fmt.format(time.toLocal());
  }
}

@immutable
class WidgetPreviewData {
  final String prayerName;
  final String prayerTime;
  final String remainingLabel;
  final int nextPrayerEpochMillis;
  final bool countdownRunning;
  final List<String> rowLabels;
  final List<String> rowTimes;

  const WidgetPreviewData({
    required this.prayerName,
    required this.prayerTime,
    required this.remainingLabel,
    required this.nextPrayerEpochMillis,
    required this.countdownRunning,
    required this.rowLabels,
    required this.rowTimes,
  });
}
