import 'dart:async';

import '../../../core/app_locale_controller.dart';
import '../../../core/timezone_bootstrap.dart';
import '../../../models/location_config.dart';
import '../../../services/auto_vibration_service.dart';
import '../../../services/notifications/notification_service.dart';

typedef ScheduleAllNotifications =
    Future<bool> Function({
      required Map<String, DateTime?> todayPrayerTimes,
      Map<String, DateTime?>? tomorrowPrayerTimes,
    });
typedef RescheduleAutoVibration =
    Future<void> Function(Map<String, dynamic>? jamaatTimes);

class HomeNotificationScheduler {
  HomeNotificationScheduler({
    required NotificationService notificationService,
    ScheduleAllNotifications? scheduleAllNotifications,
    RescheduleAutoVibration? rescheduleAutoVibration,
  }) : _notificationService = notificationService,
       _scheduleAllNotifications = scheduleAllNotifications,
       _rescheduleAutoVibration = rescheduleAutoVibration;

  final NotificationService _notificationService;
  final ScheduleAllNotifications? _scheduleAllNotifications;
  final RescheduleAutoVibration? _rescheduleAutoVibration;

  String? _lastScheduleKey;
  String? _activeScheduleKey;
  _PendingNotificationSchedule? _pendingSchedule;
  bool _isDrainingScheduleQueue = false;
  Completer<void>? _scheduleQueueCompleter;
  int _scheduleVersion = 0;
  DateTime _lastScheduledDate = DateTime.now().subtract(
    const Duration(days: 1),
  );

  void invalidate() {
    _lastScheduleKey = null;
    // Bump the version so the next scheduleKey is distinct from any in-flight
    // request — required now that jamaat data lives in the cache (not the
    // key). Without this, a fresh-from-fetch invalidate() would collide with
    // an in-progress schedule and be dropped by the active-key dedup.
    _scheduleVersion++;
  }

  Future<void> handleSettingsChange({
    required DateTime selectedDate,
    required Map<String, DateTime?> prayerTimes,
    required Map<String, DateTime?>? tomorrowPrayerTimes,
    required Map<String, dynamic>? jamaatTimes,
    required String? selectedCity,
    required String? currentPlaceName,
    required LocationConfig? locationConfig,
  }) async {
    invalidate();
    await scheduleIfNeeded(
      selectedDate: selectedDate,
      prayerTimes: prayerTimes,
      tomorrowPrayerTimes: tomorrowPrayerTimes,
      jamaatTimes: jamaatTimes,
      selectedCity: selectedCity,
      currentPlaceName: currentPlaceName,
      locationConfig: locationConfig,
    );
  }

  Future<void> scheduleIfNeeded({
    required DateTime selectedDate,
    required Map<String, DateTime?> prayerTimes,
    required Map<String, DateTime?>? tomorrowPrayerTimes,
    required Map<String, dynamic>? jamaatTimes,
    required String? selectedCity,
    required String? currentPlaceName,
    required LocationConfig? locationConfig,
  }) async {
    ensureTimeZonesInitialized();
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
      tomorrowPrayerTimes: tomorrowPrayerTimes,
      selectedCity: selectedCity,
      currentPlaceName: currentPlaceName,
      locationConfig: locationConfig,
    );
    if (_lastScheduleKey == scheduleKey &&
        !_lastScheduledDate.isBefore(today)) {
      return;
    }

    if (_activeScheduleKey == scheduleKey && _pendingSchedule == null) {
      return _scheduleQueueCompleter?.future ?? Future<void>.value();
    }
    if (_pendingSchedule?.scheduleKey == scheduleKey) {
      return _scheduleQueueCompleter?.future ?? Future<void>.value();
    }

    _pendingSchedule = _PendingNotificationSchedule(
      today: today,
      scheduleKey: scheduleKey,
      prayerTimes: Map<String, DateTime?>.from(prayerTimes),
      tomorrowPrayerTimes: tomorrowPrayerTimes == null
          ? null
          : Map<String, DateTime?>.from(tomorrowPrayerTimes),
      jamaatTimes: jamaatTimes == null
          ? null
          : Map<String, dynamic>.from(jamaatTimes),
      locationConfig: locationConfig,
    );

    if (_isDrainingScheduleQueue) {
      return _scheduleQueueCompleter?.future ?? Future<void>.value();
    }

    return _drainScheduleQueue();
  }

  Future<void> _drainScheduleQueue() async {
    _isDrainingScheduleQueue = true;
    final completer = Completer<void>();
    _scheduleQueueCompleter = completer;

    try {
      while (_pendingSchedule != null) {
        final schedule = _pendingSchedule!;
        _pendingSchedule = null;
        _activeScheduleKey = schedule.scheduleKey;

        try {
          await _executeSchedule(schedule);
        } catch (_) {
          // Notification scheduling is best-effort from the home screen.
        }
      }

      completer.complete();
    } catch (_) {
      // Notification scheduling is best-effort from the home screen.
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
      _activeScheduleKey = null;
      _isDrainingScheduleQueue = false;
      _scheduleQueueCompleter = null;
    }
  }

  Future<void> _executeSchedule(_PendingNotificationSchedule schedule) async {
    final scheduleAll =
        _scheduleAllNotifications ?? _notificationService.scheduleAllNotifications;
    final scheduled = await scheduleAll(
      todayPrayerTimes: schedule.prayerTimes,
      tomorrowPrayerTimes: schedule.tomorrowPrayerTimes,
    );

    final isLatestRequest = _pendingSchedule == null;

    if (scheduled && isLatestRequest) {
      _lastScheduleKey = schedule.scheduleKey;
      _lastScheduledDate = schedule.today;
    }

    if (isLatestRequest) {
      await (_rescheduleAutoVibration ?? AutoVibrationService().reschedule)
          .call(schedule.jamaatTimes);
    }
  }

  String _buildScheduleKey({
    required DateTime today,
    required Map<String, DateTime?> prayerTimes,
    required Map<String, DateTime?>? tomorrowPrayerTimes,
    required String? selectedCity,
    required String? currentPlaceName,
    required LocationConfig? locationConfig,
  }) {
    final prayerPart = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']
        .map(
          (name) => '$name:${prayerTimes[name]?.millisecondsSinceEpoch ?? 0}',
        )
        .join('|');
    final tomorrowPart = tomorrowPrayerTimes == null
        ? 'no-tomorrow'
        : ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']
              .map(
                (name) =>
                    '$name:${tomorrowPrayerTimes[name]?.millisecondsSinceEpoch ?? 0}',
              )
              .join('|');
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
      tomorrowPart,
    ].join('::');
  }
}

class _PendingNotificationSchedule {
  const _PendingNotificationSchedule({
    required this.today,
    required this.scheduleKey,
    required this.prayerTimes,
    required this.tomorrowPrayerTimes,
    required this.jamaatTimes,
    required this.locationConfig,
  });

  final DateTime today;
  final String scheduleKey;
  final Map<String, DateTime?> prayerTimes;
  final Map<String, DateTime?>? tomorrowPrayerTimes;
  final Map<String, dynamic>? jamaatTimes;
  final LocationConfig? locationConfig;
}
