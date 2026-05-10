import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/app_locale_controller.dart';
import '../../core/locale_prefs.dart';
import '../../core/timezone_bootstrap.dart';
import '../../models/location_config.dart';
import '../settings_service.dart';
import 'fajr_voice_notification_scheduler.dart';
import 'jamaat_reminder_scheduler.dart';
import 'notification_channel_service.dart';
import 'notification_permission_service.dart';
import 'notification_schedule_gateway.dart';
import 'prayer_end_reminder_scheduler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final SettingsService _settingsService = SettingsService();

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
      );
  late final FajrVoiceNotificationScheduler _fajrVoiceNotificationScheduler =
      FajrVoiceNotificationScheduler(
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
      return const Locale('bn');
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

  Future<void> schedulePrayerNotifications(Map<String, DateTime?> prayerTimes) {
    return _prayerEndReminderScheduler.schedule(prayerTimes);
  }

  Future<void> scheduleJamaatNotifications(Map<String, dynamic>? jamaatTimes) {
    return _jamaatReminderScheduler.schedule(jamaatTimes);
  }

  Future<void> scheduleFajrVoiceNotification(
    Map<String, DateTime?> prayerTimes,
  ) {
    return _fajrVoiceNotificationScheduler.schedule(prayerTimes);
  }

  @visibleForTesting
  static tz.TZDateTime nextFajrVoiceNotificationTime({
    required DateTime fajrTime,
    required tz.TZDateTime now,
    required tz.Location location,
  }) {
    return FajrVoiceNotificationScheduler.nextFajrVoiceNotificationTime(
      fajrTime: fajrTime,
      now: now,
      location: location,
    );
  }

  Future<bool> scheduleAllNotifications(
    Map<String, DateTime?> prayerTimes,
    Map<String, dynamic>? jamaatTimes,
  ) async {
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
        'JT_NOTIFY scheduleAll called exact=$exactAlarmsAvailable',
        name: 'NotificationService',
      );
      await cancelAllNotifications();
      await schedulePrayerNotifications(prayerTimes);
      await scheduleJamaatNotifications(jamaatTimes);
      await scheduleFajrVoiceNotification(prayerTimes);
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

  Future<void> handleNotificationSoundModeChange() async {
    try {
      await recreateNotificationChannel();
      await cancelAllNotifications();
    } catch (e) {
      developer.log(
        'Error handling notification sound mode change: $e',
        name: 'NotificationService',
        error: e,
      );
      rethrow;
    }
  }
}
