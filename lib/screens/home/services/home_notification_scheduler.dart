import 'dart:async';

import '../../../core/app_locale_controller.dart';
import '../../../models/location_config.dart';
import '../../../services/auto_vibration_service.dart';
import '../../../services/notification_service.dart';

class HomeNotificationScheduler {
  HomeNotificationScheduler({required NotificationService notificationService})
    : _notificationService = notificationService;

  final NotificationService _notificationService;

  String? _lastScheduleKey;
  String? _inFlightScheduleKey;
  int _scheduleVersion = 0;
  DateTime _lastScheduledDate = DateTime.now().subtract(
    const Duration(days: 1),
  );

  void invalidate() {
    _lastScheduleKey = null;
  }

  Future<void> handleSettingsChange({
    required DateTime selectedDate,
    required Map<String, DateTime?> prayerTimes,
    required Map<String, dynamic>? jamaatTimes,
    required String? selectedCity,
    required String? currentPlaceName,
    required LocationConfig? locationConfig,
  }) async {
    invalidate();
    _scheduleVersion++;
    await scheduleIfNeeded(
      selectedDate: selectedDate,
      prayerTimes: prayerTimes,
      jamaatTimes: jamaatTimes,
      selectedCity: selectedCity,
      currentPlaceName: currentPlaceName,
      locationConfig: locationConfig,
    );
  }

  Future<void> scheduleIfNeeded({
    required DateTime selectedDate,
    required Map<String, DateTime?> prayerTimes,
    required Map<String, dynamic>? jamaatTimes,
    required String? selectedCity,
    required String? currentPlaceName,
    required LocationConfig? locationConfig,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDateOnly = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    if (selectedDateOnly != today) {
      return;
    }

    final scheduleKey = _buildScheduleKey(
      today: today,
      prayerTimes: prayerTimes,
      jamaatTimes: jamaatTimes,
      selectedCity: selectedCity,
      currentPlaceName: currentPlaceName,
      locationConfig: locationConfig,
    );
    if (_lastScheduleKey == scheduleKey &&
        !_lastScheduledDate.isBefore(today)) {
      return;
    }
    if (_inFlightScheduleKey == scheduleKey) {
      return;
    }

    _inFlightScheduleKey = scheduleKey;
    try {
      final scheduled = await _notificationService.scheduleAllNotifications(
        prayerTimes,
        jamaatTimes,
      );
      if (scheduled) {
        _lastScheduleKey = scheduleKey;
        _lastScheduledDate = today;
      }
      unawaited(AutoVibrationService().reschedule(jamaatTimes));
    } catch (_) {
      // Notification scheduling is best-effort from the home screen.
    } finally {
      if (_inFlightScheduleKey == scheduleKey) {
        _inFlightScheduleKey = null;
      }
    }
  }

  String _buildScheduleKey({
    required DateTime today,
    required Map<String, DateTime?> prayerTimes,
    required Map<String, dynamic>? jamaatTimes,
    required String? selectedCity,
    required String? currentPlaceName,
    required LocationConfig? locationConfig,
  }) {
    final prayerPart = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']
        .map(
          (name) => '$name:${prayerTimes[name]?.millisecondsSinceEpoch ?? 0}',
        )
        .join('|');
    final jamaatEntries =
        (jamaatTimes ?? <String, dynamic>{}).entries
            .map((entry) => '${entry.key}:${entry.value}')
            .toList()
          ..sort();
    final configPart = locationConfig == null
        ? 'no-config'
        : [
            locationConfig.country.name,
            locationConfig.cityName,
            locationConfig.latitude,
            locationConfig.longitude,
            locationConfig.timezone,
          ].join(':');
    return [
      today.millisecondsSinceEpoch,
      selectedCity ?? 'gps',
      currentPlaceName ?? '',
      AppLocaleController.instance.current.languageCode,
      _scheduleVersion,
      configPart,
      prayerPart,
      jamaatEntries.join('|'),
    ].join('::');
  }
}
