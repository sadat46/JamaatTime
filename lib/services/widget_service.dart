import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import '../core/constants.dart';
import '../models/location_config.dart';
import '../services/location_config_service.dart';
import '../services/prayer_calculation_service.dart';
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
    final hijriOffset = prefs.getInt('bangladesh_hijri_offset_days') ??
        SettingsService.defaultBangladeshHijriOffsetDays;

    final configService = LocationConfigService();
    LocationConfig config;
    Coordinates coords;

    if (isGpsMode && lastLat != null && lastLng != null) {
      final locationName = prefs.getString('last_location_name') ?? 'GPS Location';
      config = LocationConfig.world(locationName, lastLat, lastLng);
      coords = Coordinates(lastLat, lastLng);
    } else {
      final cityName = savedCity ?? AppConstants.defaultCity;
      config = configService.getConfigForCity(cityName);
      coords = Coordinates(config.latitude, config.longitude);
    }

    final calcService = PrayerCalculationService.instance;
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
    final effectiveHijriOffset =
        config.country == Country.bangladesh ? hijriOffset : 0;

    final placeName = prefs.getString('last_location_name');
    await WidgetService.updateWidgetData(
      times: times,
      locationName: placeName ?? config.cityName,
      date: now,
      hijriOffsetDays: effectiveHijriOffset,
    );
  } catch (e) {
    // Background callback errors are non-fatal
  }
}

class WidgetService {
  static const String _androidWidgetName = 'PrayerWidgetProvider';
  static const _fmt = 'hh:mm a';
  static const _prayerOrder = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

  static Future<void> updateWidgetData({
    required Map<String, DateTime?> times,
    required String locationName,
    required DateTime date,
    required int hijriOffsetDays,
  }) async {
    try {
      final now = DateTime.now();
      final currentPrayer = _getCurrentPrayerName(times, now);
      final nextPrayer = _getNextPrayerName(times, now);
      final currentPrayerTime = times[currentPrayer];
      final nextPrayerTime = times[nextPrayer];

      final remaining = nextPrayerTime != null && now.isBefore(nextPrayerTime)
          ? nextPrayerTime.difference(now)
          : Duration.zero;

      final timeFormat = DateFormat(_fmt);

      // Build 4-prayer row excluding current prayer
      final rowPrayers = _prayerOrder.where((p) => p != currentPrayer).toList();
      // Ensure exactly 4 entries (fallback if current prayer not in list)
      while (rowPrayers.length < 4) {
        rowPrayers.add('-');
      }

      final hijriDate = HijriDateConverter.formatHijriDate(date, dayOffset: hijriOffsetDays);
      final banglaDate = BanglaCalendar.fromGregorian(date);

      await Future.wait([
        HomeWidget.saveWidgetData<String>('prayer_name', currentPrayer),
        HomeWidget.saveWidgetData<String>(
          'prayer_time',
          currentPrayerTime != null
              ? timeFormat.format(currentPrayerTime.toLocal())
              : '-',
        ),
        HomeWidget.saveWidgetData<String>(
          'remaining_label',
          '$currentPrayer Time Remaining',
        ),
        HomeWidget.saveWidgetData<String>(
          'remaining_time',
          _formatRemaining(remaining),
        ),
        // 4 dynamic prayer row slots
        HomeWidget.saveWidgetData<String>('row_label_1', rowPrayers[0]),
        HomeWidget.saveWidgetData<String>('row_time_1', _formatPrayerTime(times[rowPrayers[0]], timeFormat)),
        HomeWidget.saveWidgetData<String>('row_label_2', rowPrayers[1]),
        HomeWidget.saveWidgetData<String>('row_time_2', _formatPrayerTime(times[rowPrayers[1]], timeFormat)),
        HomeWidget.saveWidgetData<String>('row_label_3', rowPrayers[2]),
        HomeWidget.saveWidgetData<String>('row_time_3', _formatPrayerTime(times[rowPrayers[2]], timeFormat)),
        HomeWidget.saveWidgetData<String>('row_label_4', rowPrayers[3]),
        HomeWidget.saveWidgetData<String>('row_time_4', _formatPrayerTime(times[rowPrayers[3]], timeFormat)),
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

  /// Current prayer = the last prayer whose time has already passed.
  static String _getCurrentPrayerName(
      Map<String, DateTime?> times, DateTime now) {
    String current = 'Isha'; // default: after all prayers
    for (final name in _prayerOrder) {
      final t = times[name];
      if (t != null && now.isBefore(t)) {
        break;
      }
      current = name;
    }
    return current;
  }

  /// Next prayer = the first prayer whose time hasn't passed yet.
  static String _getNextPrayerName(
      Map<String, DateTime?> times, DateTime now) {
    for (final name in _prayerOrder) {
      final t = times[name];
      if (t != null && now.isBefore(t)) {
        return name;
      }
    }
    return 'Fajr';
  }

  static String _formatRemaining(Duration duration) {
    if (duration <= Duration.zero) return '-';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) return '${hours.toString().padLeft(2, '0')}hrs, ${minutes.toString().padLeft(2, '0')}mins';
    return '${minutes}mins';
  }

  static String _formatPrayerTime(DateTime? time, DateFormat fmt) {
    if (time == null) return '-';
    return fmt.format(time.toLocal());
  }
}
