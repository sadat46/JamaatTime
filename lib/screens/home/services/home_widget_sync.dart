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
    final tomorrowMap = PrayerTimeEngine.instance.createPrayerTimesMap(
      tomorrowTimes,
    );
    final dayAfterTomorrow = tomorrow.add(const Duration(days: 1));
    final dayAfterTomorrowTimes = PrayerTimes(
      coordinates: resolvedCoords,
      date: dayAfterTomorrow,
      calculationParameters: calculationParameters,
      precision: true,
    );
    final dayAfterTomorrowMap = PrayerTimeEngine.instance.createPrayerTimesMap(
      dayAfterTomorrowTimes,
    );

    unawaited(
      _updateWithNextDayPayload(
        times: times,
        date: selectedDate,
        locationConfig: locationConfig,
        locationName: currentPlaceName ?? locationConfig.cityName,
        hijriOffsetDays: hijriOffset,
        tomorrow: tomorrow,
        tomorrowTimes: tomorrowMap,
        dayAfterTomorrowFajr: dayAfterTomorrowMap['Fajr'],
        jamaatTimes: jamaatTimes,
      ),
    );
  }

  Future<void> _updateWithNextDayPayload({
    required Map<String, DateTime?> times,
    required DateTime date,
    required LocationConfig locationConfig,
    required String locationName,
    required int hijriOffsetDays,
    required DateTime tomorrow,
    required Map<String, DateTime?> tomorrowTimes,
    required DateTime? dayAfterTomorrowFajr,
    required Map<String, dynamic>? jamaatTimes,
  }) async {
    final tomorrowJamaatTimes = await WidgetService.resolveWidgetJamaatTimes(
      config: locationConfig,
      cityForJamaat: locationConfig.cityName,
      date: tomorrow,
      prayerTimes: tomorrowTimes,
    );

    await WidgetService.updateWidgetData(
      times: times,
      locale: AppLocaleController.instance.current,
      locationName: locationName,
      date: date,
      hijriOffsetDays: hijriOffsetDays,
      tomorrowFajr: tomorrowTimes['Fajr'],
      tomorrowTimes: tomorrowTimes,
      tomorrowJamaatTimes: tomorrowJamaatTimes,
      dayAfterTomorrowFajr: dayAfterTomorrowFajr,
      jamaatTimes: jamaatTimes,
    );
  }
}
