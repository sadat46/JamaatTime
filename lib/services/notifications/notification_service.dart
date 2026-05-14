// ignore_for_file: avoid_print

import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/app_locale_controller.dart';
import '../../core/locale_prefs.dart';
import '../../core/timezone_bootstrap.dart';
import '../../models/location_config.dart';
import '../settings_service.dart';
import 'notification_channel_service.dart';
import 'notification_ids.dart';
import 'notification_permission_service.dart';
import 'notification_schedule_gateway.dart';
import 'reminders/jamaat_reminder_scheduler.dart';
import 'reminders/jamaat_schedule_cache.dart';
import 'reminders/prayer_end_reminder_scheduler.dart';
import 'reminders/tahajjud_end_fajr_start_notification_scheduler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final SettingsService _settingsService = SettingsService();
  final JamaatScheduleCache _jamaatCache = JamaatScheduleCache.instance;

  bool _isInitialized = false;
  Future<void>? _initializeFuture;
  LocationConfig? _currentLocationConfig;

  late final NotificationPermissionService _permissionService =
      NotificationPermissionService(flutterLocalNotificationsPlugin);
  late final NotificationChannelService _channelService =
      NotificationChannelService(
        plugin: flutterLocalNotificationsPlugin,
        settingsService: _settingsService,
      );
  late final NotificationScheduleGateway _scheduleGateway =
      NotificationScheduleGateway(
        plugin: flutterLocalNotificationsPlugin,
        settingsService: _settingsService,
        channelService: _channelService,
        permissionService: _permissionService,
        isInitialized: () => _isInitialized,
      );
  late final PrayerEndReminderScheduler _prayerEndReminderScheduler =
      PrayerEndReminderScheduler(
        scheduleGateway: _scheduleGateway,
        localeResolver: _resolveLocale,
        locationResolver: _getLocation,
      );
  late final JamaatReminderScheduler _jamaatReminderScheduler =
      JamaatReminderScheduler(
        scheduleGateway: _scheduleGateway,
        localeResolver: _resolveLocale,
        locationResolver: _getLocation,
        cache: _jamaatCache,
      );
  late final TahajjudEndFajrStartNotificationScheduler
  _tahajjudEndFajrStartNotificationScheduler =
      TahajjudEndFajrStartNotificationScheduler(
        scheduleGateway: _scheduleGateway,
        settingsService: _settingsService,
        localeResolver: _resolveLocale,
        locationResolver: _getLocation,
      );

  bool get exactAlarmsAvailable => _permissionService.exactAlarmsAvailable;

  Future<Locale> _resolveLocale() async {
    try {
      return AppLocaleController.instance.current;
    } catch (_) {
      // AppLocaleController might not be bootstrapped in some early paths.
    }

    try {
      final code = await LocalePrefs.read();
      return LocalePrefs.toLocale(code);
    } catch (_) {
      return LocalePrefs.toLocale(LocalePrefs.defaultCode);
    }
  }

  void setLocationConfig(LocationConfig config) {
    _currentLocationConfig = config;
  }

  String _getTimezone() {
    return _currentLocationConfig?.timezone ?? 'Asia/Dhaka';
  }

  tz.Location _getLocation() {
    return tz.getLocation(_getTimezone());
  }

  Future<void> initialize([BuildContext? context]) {
    if (_isInitialized) return Future<void>.value();
    return _initializeFuture ??= _initialize(context);
  }

  Future<void> _initialize(BuildContext? context) async {
    try {
      ensureTimeZonesInitialized();
      const initializationSettingsAndroid = AndroidInitializationSettings(
        '@mipmap/launcher_icon',
      );

      const initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification tap.
        },
      );

      await _channelService.createActiveChannelsForBoot();
      await _permissionService.requestNotificationsPermission();
      await _permissionService.refreshExactAlarmsAvailable();
      await _pruneStaleJamaatCache();

      _isInitialized = true;
    } catch (e) {
      developer.log(
        'JT_NOTIFY initialize failed $e',
        name: 'NotificationService',
        error: e,
      );
    } finally {
      _initializeFuture = null;
    }
  }

  Future<void> _pruneStaleJamaatCache() async {
    try {
      final now = tz.TZDateTime.now(_getLocation());
      final cutoff = DateTime(now.year, now.month, now.day);
      await _jamaatCache.pruneOlderThan(cutoff);
    } catch (_) {
      // Best-effort cleanup.
    }
  }

  Future<bool> refreshExactAlarmsAvailable() {
    return _permissionService.refreshExactAlarmsAvailable();
  }

  Future<bool> requestExactAlarmsPermission() {
    return _permissionService.requestExactAlarmsPermission();
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String notificationType = 'prayer',
  }) {
    return _scheduleGateway.scheduleStandard(
      id: id,
      title: title,
      body: body,
      scheduledTime: scheduledTime,
      notificationType: notificationType,
    );
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _scheduleGateway.cancelAll();
    } catch (e) {
      developer.log(
        'Error cancelling notifications: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  /// Cancel every jamaat reminder slot (today + tomorrow). Used when the user
  /// disables jamaat notifications entirely.
  Future<void> cancelAllJamaatReminders() async {
    try {
      for (final id in NotificationIds.jamaatReminders.values) {
        await _scheduleGateway.cancel(id);
      }
      for (final id in NotificationIds.jamaatRemindersTomorrow.values) {
        await _scheduleGateway.cancel(id);
      }
    } catch (e) {
      developer.log(
        'Error cancelling jamaat reminders: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  Map<String, DateTime?> calculatePrayerNotificationTimes(
    Map<String, DateTime?> prayerTimes,
  ) {
    ensureTimeZonesInitialized();
    return PrayerEndReminderScheduler.calculateNotificationTimes(
      prayerTimes,
      location: tz.getLocation('Asia/Dhaka'),
    );
  }

  Map<String, DateTime?> calculateJamaatNotificationTimes(
    Map<String, dynamic>? jamaatTimes,
  ) {
    ensureTimeZonesInitialized();
    return JamaatReminderScheduler.calculateNotificationTimes(
      jamaatTimes,
      location: _getLocation(),
    );
  }

  Future<void> schedulePrayerNotifications({
    required Map<String, DateTime?> todayPrayerTimes,
    Map<String, DateTime?>? tomorrowPrayerTimes,
  }) {
    return _prayerEndReminderScheduler.schedule(
      todayPrayerTimes: todayPrayerTimes,
      tomorrowPrayerTimes: tomorrowPrayerTimes,
    );
  }

  /// Reads jamaat times for today and tomorrow from [JamaatScheduleCache] and
  /// arms reminders for both date ranges. Idempotent — re-arming the same ID
  /// atomically replaces the prior alarm via `zonedSchedule`, so a no-data
  /// run leaves previously armed alarms untouched.
  Future<void> scheduleJamaatNotifications({
    Map<String, dynamic>? todayJamaatTimes,
    Map<String, dynamic>? tomorrowJamaatTimes,
  }) {
    return _jamaatReminderScheduler.schedule(
      todayJamaatTimes: todayJamaatTimes,
      tomorrowJamaatTimes: tomorrowJamaatTimes,
    );
  }

  Future<void> scheduleTahajjudEndFajrStartNotification({
    required Map<String, DateTime?> todayPrayerTimes,
    Map<String, DateTime?>? tomorrowPrayerTimes,
  }) {
    return _tahajjudEndFajrStartNotificationScheduler.schedule(
      todayPrayerTimes: todayPrayerTimes,
      tomorrowPrayerTimes: tomorrowPrayerTimes,
    );
  }

  @visibleForTesting
  static tz.TZDateTime nextTahajjudEndFajrStartNotificationTime({
    required DateTime fajrTime,
    required tz.TZDateTime now,
    required tz.Location location,
  }) {
    return TahajjudEndFajrStartNotificationScheduler.nextTahajjudEndFajrStartNotificationTime(
      fajrTime: fajrTime,
      now: now,
      location: location,
    );
  }

  /// Single entry point for re-arming every scheduled notification this app
  /// owns. Replaces each alarm by ID (`zonedSchedule` is replace-by-id), so
  /// this call is idempotent and safe to invoke repeatedly. Notably it does
  /// NOT call `cancelAllNotifications()` — that would create a wipe window
  /// during which previously armed jamaat alarms are gone.
  Future<bool> scheduleAllNotifications({
    required Map<String, DateTime?> todayPrayerTimes,
    Map<String, DateTime?>? tomorrowPrayerTimes,
    Map<String, dynamic>? todayJamaatTimes,
    Map<String, dynamic>? tomorrowJamaatTimes,
  }) async {
    try {
      await initialize(null);
      if (!_isInitialized) {
        developer.log(
          'JT_NOTIFY scheduleAll skipped reason=not_initialized',
          name: 'NotificationService',
        );
        return false;
      }

      await refreshExactAlarmsAvailable();
      developer.log(
        'JT_NOTIFY scheduleAll called exact=$exactAlarmsAvailable '
        'tomorrow=${tomorrowPrayerTimes != null}',
        name: 'NotificationService',
      );
      await recreateNotificationChannel();
      await _runScheduleStep(
        'prayer_end',
        () => schedulePrayerNotifications(
          todayPrayerTimes: todayPrayerTimes,
          tomorrowPrayerTimes: tomorrowPrayerTimes,
        ),
      );
      // Treat empty maps as null so the scheduler falls back to the persistent
      // JamaatScheduleCache rather than producing zero candidates silently.
      final effectiveTodayJamaat =
          (todayJamaatTimes == null || todayJamaatTimes.isEmpty)
          ? null
          : todayJamaatTimes;
      final effectiveTomorrowJamaat =
          (tomorrowJamaatTimes == null || tomorrowJamaatTimes.isEmpty)
          ? null
          : tomorrowJamaatTimes;
      await _runScheduleStep(
        'jamaat_reminder',
        () => scheduleJamaatNotifications(
          todayJamaatTimes: effectiveTodayJamaat,
          tomorrowJamaatTimes: effectiveTomorrowJamaat,
        ),
      );
      await _runScheduleStep(
        'fajr_voice',
        () => scheduleTahajjudEndFajrStartNotification(
          todayPrayerTimes: todayPrayerTimes,
          tomorrowPrayerTimes: tomorrowPrayerTimes,
        ),
      );
      return true;
    } catch (e) {
      developer.log(
        'JT_NOTIFY error scheduleAll $e',
        name: 'NotificationService',
        error: e,
      );
      return false;
    }
  }

  Future<void> _runScheduleStep(
    String step,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e, st) {
      print('JT_NOTIFY scheduleAll step=$step error $e\n$st');
      developer.log(
        'JT_NOTIFY scheduleAll step=$step error $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _scheduleGateway.pendingNotificationRequests();
    } catch (e) {
      developer.log(
        'Error getting pending notifications: $e',
        name: 'NotificationService',
        error: e,
      );
      return [];
    }
  }

  Future<bool> areNotificationsEnabled() {
    return _permissionService.areNotificationsEnabled();
  }

  bool get isInitialized => _isInitialized;

  Future<void> reset() async {
    _isInitialized = false;
    _initializeFuture = null;
    await initialize(null);
  }

  Future<bool> isReady() async {
    if (!_isInitialized) {
      return false;
    }

    return areNotificationsEnabled();
  }

  Future<void> recreateNotificationChannel() async {
    try {
      await _channelService.recreateAllChannels();
    } catch (e) {
      developer.log(
        'Error recreating notification channels: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }
}
