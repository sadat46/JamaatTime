import 'dart:async';

import '../../../core/app_locale_controller.dart';
import '../../../core/timezone_bootstrap.dart';
import '../../../models/location_config.dart';
import '../../../services/auto_vibration_service.dart';
import '../../../services/notification_service.dart';

typedef ScheduleAllNotifications =
    Future<bool> Function(
      Map<String, DateTime?> prayerTimes,
      Map<String, dynamic>? jamaatTimes,
    );
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
      jamaatTimes: jamaatTimes,
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
    final scheduled =
        await (_scheduleAllNotifications ??
                _notificationService.scheduleAllNotifications)
            .call(schedule.prayerTimes, schedule.jamaatTimes);

    final isLatestRequest = _pendingSchedule == null;
    final isIncompleteServerJamaat =
        schedule.locationConfig?.jamaatSource == JamaatSource.server &&
        schedule.jamaatTimes == null;

    if (scheduled && isLatestRequest && !isIncompleteServerJamaat) {
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

class _PendingNotificationSchedule {
  const _PendingNotificationSchedule({
    required this.today,
    required this.scheduleKey,
    required this.prayerTimes,
    required this.jamaatTimes,
    required this.locationConfig,
  });

  final DateTime today;
  final String scheduleKey;
  final Map<String, DateTime?> prayerTimes;
  final Map<String, dynamic>? jamaatTimes;
  final LocationConfig? locationConfig;
}
