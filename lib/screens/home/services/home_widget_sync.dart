import 'dart:async';

import 'package:adhan_dart/adhan_dart.dart';

import '../../../core/app_locale_controller.dart';
import '../../../models/location_config.dart';
import '../../../services/prayer_time_engine.dart';
import '../../../services/widget_service.dart';

class HomeWidgetSync {
  void update({
    required Map<String, DateTime?> times,
    required DateTime selectedDate,
    required LocationConfig? locationConfig,
    required CalculationParameters? calculationParameters,
    required Coordinates? coordinates,
    required String? currentPlaceName,
    required int bangladeshHijriOffsetDays,
    required Map<String, dynamic>? jamaatTimes,
  }) {
    if (times.isEmpty ||
        locationConfig == null ||
        calculationParameters == null) {
      return;
    }

    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final selectedOnly = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    if (selectedOnly != todayOnly) {
      return;
    }

    final hijriOffset = locationConfig.country == Country.bangladesh
        ? bangladeshHijriOffsetDays
        : 0;
    final resolvedCoords =
        coordinates ??
        Coordinates(locationConfig.latitude, locationConfig.longitude);
    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    final tomorrowTimes = PrayerTimes(
      coordinates: resolvedCoords,
      date: tomorrow,
      calculationParameters: calculationParameters,
      precision: true,
    );
    final tomorrowFajr = PrayerTimeEngine.instance.createPrayerTimesMap(
      tomorrowTimes,
    )['Fajr'];

    unawaited(
      WidgetService.updateWidgetData(
        times: times,
        locale: AppLocaleController.instance.current,
        locationName: currentPlaceName ?? locationConfig.cityName,
        date: selectedDate,
        hijriOffsetDays: hijriOffset,
        tomorrowFajr: tomorrowFajr,
        jamaatTimes: jamaatTimes,
      ),
    );
  }
}
