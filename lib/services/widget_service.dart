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

    await WidgetService.updateWidgetData(
      times: times,
      locationName: config.cityName,
      date: now,
      hijriOffsetDays: effectiveHijriOffset,
    );
  } catch (e) {
    // Background callback errors are non-fatal
  }
}

class WidgetService {
  static const String _androidWidgetName = 'PrayerWidgetProvider';
  static const _fmt = 'HH:mm';
  static const _prayerOrder = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

  static Future<void> updateWidgetData({
    required Map<String, DateTime?> times,
    required String locationName,
    required DateTime date,
    required int hijriOffsetDays,
  }) async {
    try {
      final now = DateTime.now();
      final nextPrayer = _getNextPrayerName(times, now);
      final nextPrayerTime = times[nextPrayer];

      final remaining = nextPrayerTime != null && now.isBefore(nextPrayerTime)
          ? nextPrayerTime.difference(now)
          : Duration.zero;

      final timeFormat = DateFormat(_fmt);

      await Future.wait([
        HomeWidget.saveWidgetData<String>('prayer_name', nextPrayer),
        HomeWidget.saveWidgetData<String>(
          'prayer_time',
          nextPrayerTime != null
              ? timeFormat.format(nextPrayerTime.toLocal())
              : '-',
        ),
        HomeWidget.saveWidgetData<String>(
          'remaining_label',
          'Until $nextPrayer',
        ),
        HomeWidget.saveWidgetData<String>(
          'remaining_time',
          _formatRemaining(remaining),
        ),
        HomeWidget.saveWidgetData<String>(
          'fajr_time',
          _formatPrayerTime(times['Fajr'], timeFormat),
        ),
        HomeWidget.saveWidgetData<String>(
          'dhuhr_time',
          _formatPrayerTime(times['Dhuhr'], timeFormat),
        ),
        HomeWidget.saveWidgetData<String>(
          'asr_time',
          _formatPrayerTime(times['Asr'], timeFormat),
        ),
        HomeWidget.saveWidgetData<String>(
          'maghrib_time',
          _formatPrayerTime(times['Maghrib'], timeFormat),
        ),
        HomeWidget.saveWidgetData<String>(
          'isha_time',
          _formatPrayerTime(times['Isha'], timeFormat),
        ),
        HomeWidget.saveWidgetData<String>(
          'islamic_date',
          HijriDateConverter.formatHijriDate(date, dayOffset: hijriOffsetDays),
        ),
        HomeWidget.saveWidgetData<String>('location', locationName),
      ]);

      await HomeWidget.updateWidget(androidName: _androidWidgetName);
    } catch (e) {
      // Widget updates are best-effort, never block the app
    }
  }

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
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  static String _formatPrayerTime(DateTime? time, DateFormat fmt) {
    if (time == null) return '-';
    return fmt.format(time.toLocal());
  }
}
