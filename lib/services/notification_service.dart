import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';
import '../core/app_locale_controller.dart';
import '../core/app_text.dart';
import '../core/locale_prefs.dart';
import '../services/settings_service.dart';
import '../models/location_config.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final SettingsService _settingsService = SettingsService();
  bool _isInitialized = false;
  Future<void>? _initializeFuture;

  // Fixed notification IDs. Required architecture mandates stable numeric
  // ranges so cancellation and dedupe behave deterministically across builds.
  static const Map<String, int> _prayerNotificationIds = {
    'Fajr': 1101,
    'Dhuhr': 1102,
    'Asr': 1103,
    'Maghrib': 1104,
    'Isha': 1105,
  };
  static const Map<String, int> _jamaatNotificationIds = {
    'Fajr': 2101,
    'Dhuhr': 2102,
    'Asr': 2103,
    'Maghrib': 2104,
    'Isha': 2105,
  };
  static const int _fajrVoiceNotificationId = 3101;

  // Cached state of SCHEDULE_EXACT_ALARM. On Android 12+ the user must grant
  // this from system "Alarms & reminders"; without it `setExactAndAllowWhileIdle`
  // throws SecurityException. We pick exact mode when granted (prayer/jamaat
  // and Fajr voice arrive on the dot) and fall back to inexact otherwise so
  // reminders still fire within ~10 min of target.
  bool _exactAlarmsAvailable = false;
  bool get exactAlarmsAvailable => _exactAlarmsAvailable;

  /// Notification-channel IDs already created on the OS during this process.
  /// Used by [_ensureChannelById] to skip redundant platform-channel calls.
  /// Channels persist across app launches at the OS level; this set only
  /// tracks per-process duplicates.
  final Set<String> _createdChannelIds = <String>{};

  AndroidScheduleMode get _androidScheduleMode => _exactAlarmsAvailable
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  AndroidFlutterLocalNotificationsPlugin? _androidPlugin() =>
      flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

  /// Refresh the cached SCHEDULE_EXACT_ALARM state and return it.
  /// Returns true on non-Android platforms (no equivalent restriction).
  Future<bool> refreshExactAlarmsAvailable() async {
    if (!Platform.isAndroid) {
      _exactAlarmsAvailable = true;
      return true;
    }
    try {
      final granted =
          await _androidPlugin()?.canScheduleExactNotifications() ?? false;
      _exactAlarmsAvailable = granted;
      return granted;
    } catch (e) {
      developer.log(
        'canScheduleExactNotifications failed: $e',
        name: 'NotificationService',
      );
      _exactAlarmsAvailable = false;
      return false;
    }
  }

  /// Open the system "Alarms & reminders" page so the user can grant
  /// SCHEDULE_EXACT_ALARM. Returns the resulting permission state, and
  /// updates the cached value.
  Future<bool> requestExactAlarmsPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final result =
          await _androidPlugin()?.requestExactAlarmsPermission() ?? false;
      _exactAlarmsAvailable = result;
      return result;
    } catch (e) {
      developer.log(
        'requestExactAlarmsPermission failed: $e',
        name: 'NotificationService',
      );
      return false;
    }
  }

  // Location configuration for timezone handling
  LocationConfig? _currentLocationConfig;

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

  String _localizedPrayerName(Locale locale, String prayerKey) {
    final strings = AppText.of(locale);
    switch (prayerKey) {
      case 'Fajr':
        return strings.prayer_fajr;
      case 'Sunrise':
        return strings.prayer_sunrise;
      case 'Dhuhr':
        return strings.prayer_dhuhr;
      case 'Asr':
        return strings.prayer_asr;
      case 'Maghrib':
        return strings.prayer_maghrib;
      case 'Isha':
        return strings.prayer_isha;
      default:
        return prayerKey;
    }
  }

  String _canonicalPrayerNameFromJamaatKey(String key) {
    switch (key.toLowerCase()) {
      case 'fajr':
        return 'Fajr';
      case 'dhuhr':
      case 'zuhr':
        return 'Dhuhr';
      case 'asr':
        return 'Asr';
      case 'maghrib':
      case 'magrib':
        return 'Maghrib';
      case 'isha':
        return 'Isha';
      default:
        return key;
    }
  }

  /// Set the current location configuration
  void setLocationConfig(LocationConfig config) {
    _currentLocationConfig = config;
  }

  /// Get the timezone string for the current location
  String _getTimezone() {
    return _currentLocationConfig?.timezone ?? 'Asia/Dhaka';
  }

  /// Get the timezone location object
  tz.Location _getLocation() {
    return tz.getLocation(_getTimezone());
  }

  /// Initialize notification service
  Future<void> initialize([BuildContext? context]) {
    if (_isInitialized) return Future<void>.value();
    return _initializeFuture ??= _initialize(context);
  }

  Future<void> _initialize(BuildContext? context) async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification tap
        },
      );

      // Create notification channels for Android.
      //
      // Phase 2.3: only create the channels matching the user's current
      // sound modes (plus the Fajr voice channel). The other 8 channels
      // are dead weight at boot and get lazily created on demand by
      // [_ensureChannelById] in [scheduleNotification], or when the user
      // changes sound modes via [handleNotificationSoundModeChange].
      if (Platform.isAndroid) {
        await _createActiveChannelsForBoot();
      }

      // Request notification permissions for Android 13+ and iOS
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _androidPlugin();
        if (androidImplementation != null) {
          await androidImplementation.requestNotificationsPermission();
        }
        await refreshExactAlarmsAvailable();
      }

      _isInitialized = true;
    } catch (e) {
      // Don't set _isInitialized to true if initialization failed
      developer.log(
        'JT_NOTIFY initialize failed $e',
        name: 'NotificationService',
        error: e,
      );
    } finally {
      _initializeFuture = null;
    }
  }

  /// Get the appropriate channel ID for prayer notifications
  String _getPrayerChannelId(int soundMode) {
    switch (soundMode) {
      case 0:
        return 'prayer_channel_custom';
      case 1:
        return 'prayer_channel_system';
      case 2:
        return 'prayer_channel_silent';
      case 3:
        return 'prayer_channel_custom_2';
      case 4:
        return 'prayer_channel_custom_3';
      default:
        return 'prayer_channel_custom';
    }
  }

  /// Get the appropriate channel ID for jamaat notifications
  String _getJamaatChannelId(int soundMode) {
    switch (soundMode) {
      case 0:
        return 'jamaat_channel_custom';
      case 1:
        return 'jamaat_channel_system';
      case 2:
        return 'jamaat_channel_silent';
      case 3:
        return 'jamaat_channel_custom_2';
      case 4:
        return 'jamaat_channel_custom_3';
      default:
        return 'jamaat_channel_custom';
    }
  }

  /// Resolve custom sound resource by notification type and selected sound mode.
  String? _getCustomSoundResource({
    required String notificationType,
    required int soundMode,
  }) {
    final isPrayer = notificationType == 'prayer';

    switch (soundMode) {
      case 0:
        return isPrayer ? 'prayer_allahu_akbar' : 'jamaat_allahu_akbar';
      case 3:
        return isPrayer ? 'prayer_custom_2' : 'jamaat_custom_2';
      case 4:
        return isPrayer ? 'prayer_custom_3' : 'jamaat_custom_3';
      default:
        return null;
    }
  }

  /// Get notification configuration based on type and sound mode
  Map<String, dynamic> _getNotificationConfig({
    required String notificationType,
    required int soundMode,
  }) {
    final isPrayer = notificationType == 'prayer';
    final channelId = isPrayer
        ? _getPrayerChannelId(soundMode)
        : _getJamaatChannelId(soundMode);

    return {
      'channelId': channelId,
      'playSound': soundMode != 2,
      'enableVibration': soundMode != 2,
    };
  }

  /// Single source of truth for notification-channel definitions.
  ///
  /// Returns `null` for unknown IDs (callers should treat that as "skip").
  /// Building the channel object is cheap (it's just a Dart constructor); the
  /// expensive part is the platform-channel call inside
  /// [AndroidFlutterLocalNotificationsPlugin.createNotificationChannel].
  AndroidNotificationChannel? _buildChannelById(String id) {
    switch (id) {
      case 'prayer_channel_custom':
        return AndroidNotificationChannel(
          'prayer_channel_custom',
          'Prayer Notifications (Custom Sound)',
          description: 'Prayer notifications with custom adhan sound',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: RawResourceAndroidNotificationSound('prayer_allahu_akbar'),
        );
      case 'prayer_channel_custom_2':
        return AndroidNotificationChannel(
          'prayer_channel_custom_2',
          'Prayer Notifications (Custom Sound 2)',
          description: 'Prayer notifications with custom adhan sound 2',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: RawResourceAndroidNotificationSound('prayer_custom_2'),
        );
      case 'prayer_channel_custom_3':
        return AndroidNotificationChannel(
          'prayer_channel_custom_3',
          'Prayer Notifications (Custom Sound 3)',
          description: 'Prayer notifications with custom adhan sound 3',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: RawResourceAndroidNotificationSound('prayer_custom_3'),
        );
      case 'prayer_channel_system':
        return const AndroidNotificationChannel(
          'prayer_channel_system',
          'Prayer Notifications (System Sound)',
          description: 'Prayer notifications with system default sound',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: null,
        );
      case 'prayer_channel_silent':
        return const AndroidNotificationChannel(
          'prayer_channel_silent',
          'Prayer Notifications (Silent)',
          description: 'Prayer notifications without sound',
          importance: Importance.max,
          playSound: false,
          enableVibration: false,
          showBadge: true,
          sound: null,
        );
      case 'jamaat_channel_custom':
        return AndroidNotificationChannel(
          'jamaat_channel_custom',
          'Jamaat Notifications (Custom Sound)',
          description: 'Jamaat notifications with custom adhan sound',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: RawResourceAndroidNotificationSound('jamaat_allahu_akbar'),
        );
      case 'jamaat_channel_custom_2':
        return AndroidNotificationChannel(
          'jamaat_channel_custom_2',
          'Jamaat Notifications (Custom Sound 2)',
          description: 'Jamaat notifications with custom adhan sound 2',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: RawResourceAndroidNotificationSound('jamaat_custom_2'),
        );
      case 'jamaat_channel_custom_3':
        return AndroidNotificationChannel(
          'jamaat_channel_custom_3',
          'Jamaat Notifications (Custom Sound 3)',
          description: 'Jamaat notifications with custom adhan sound 3',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: RawResourceAndroidNotificationSound('jamaat_custom_3'),
        );
      case 'jamaat_channel_system':
        return const AndroidNotificationChannel(
          'jamaat_channel_system',
          'Jamaat Notifications (System Sound)',
          description: 'Jamaat notifications with system default sound',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: null,
        );
      case 'jamaat_channel_silent':
        return const AndroidNotificationChannel(
          'jamaat_channel_silent',
          'Jamaat Notifications (Silent)',
          description: 'Jamaat notifications without sound',
          importance: Importance.max,
          playSound: false,
          enableVibration: false,
          showBadge: true,
          sound: null,
        );
      case 'fajr_voice_channel_v1':
        return AndroidNotificationChannel(
          'fajr_voice_channel_v1',
          'Fajr Voice Notification',
          description: 'Plays voice reminder at Fajr prayer start time',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: RawResourceAndroidNotificationSound('fajr_prayer_voice'),
        );
      default:
        return null;
    }
  }

  /// Lazily create a single notification channel by ID. Idempotent within
  /// this process via [_createdChannelIds].
  ///
  /// Safe to call from [scheduleNotification] right before each schedule:
  /// the first call creates the channel, subsequent calls are O(1) set
  /// lookups. No-op on non-Android.
  Future<void> _ensureChannelById(String id) async {
    if (_createdChannelIds.contains(id)) return;
    if (!Platform.isAndroid) return;
    final channel = _buildChannelById(id);
    if (channel == null) {
      developer.log(
        'JT_NOTIFY ensureChannel unknown id=$id',
        name: 'NotificationService',
      );
      return;
    }
    final androidImpl = _androidPlugin();
    if (androidImpl == null) return;
    await androidImpl.createNotificationChannel(channel);
    _createdChannelIds.add(id);
  }

  /// All known channel IDs. Used by [_createAllNotificationChannels] when a
  /// caller (e.g. sound-mode-change recovery) wants to refresh every channel.
  static const List<String> _allChannelIds = <String>[
    'prayer_channel_custom',
    'prayer_channel_custom_2',
    'prayer_channel_custom_3',
    'prayer_channel_system',
    'prayer_channel_silent',
    'jamaat_channel_custom',
    'jamaat_channel_custom_2',
    'jamaat_channel_custom_3',
    'jamaat_channel_system',
    'jamaat_channel_silent',
    'fajr_voice_channel_v1',
  ];

  /// Boot-time channel creation: only the channels matching the user's
  /// CURRENT prayer + jamaat sound modes, plus the Fajr voice channel.
  ///
  /// The other 8 channels are dead weight at boot; only one prayer + one
  /// jamaat channel ever fire at a time, determined by sound mode in
  /// settings. Channels for other sound modes are created lazily on demand
  /// when the user switches modes (via [handleNotificationSoundModeChange],
  /// which still goes through [_createAllNotificationChannels]) or, as a
  /// safety net, when [scheduleNotification] is called.
  Future<void> _createActiveChannelsForBoot() async {
    if (!Platform.isAndroid) return;
    int prayerSoundMode;
    int jamaatSoundMode;
    try {
      prayerSoundMode = await _settingsService.getPrayerNotificationSoundMode();
    } catch (_) {
      prayerSoundMode = 3;
    }
    try {
      jamaatSoundMode = await _settingsService.getJamaatNotificationSoundMode();
    } catch (_) {
      jamaatSoundMode = 3;
    }
    await _ensureChannelById(_getPrayerChannelId(prayerSoundMode));
    await _ensureChannelById(_getJamaatChannelId(jamaatSoundMode));
    await _ensureChannelById('fajr_voice_channel_v1');
  }

  /// Create every known notification channel.
  ///
  /// Used by recovery / migration paths (e.g. [recreateNotificationChannel]).
  /// Boot does NOT use this; boot uses [_createActiveChannelsForBoot] for a
  /// minimal startup cost. Channel definitions live in [_buildChannelById]
  /// (single source of truth).
  Future<void> _createAllNotificationChannels() async {
    try {
      if (!Platform.isAndroid) return;
      for (final id in _allChannelIds) {
        await _ensureChannelById(id);
      }
    } catch (e) {
      developer.log(
        'Error creating notification channels: $e',
        name: 'NotificationService',
        error: e,
      );
      rethrow;
    }
  }

  /// Schedule notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String notificationType = 'prayer', // 'prayer' or 'jamaat'
  }) async {
    try {
      // Check if service is initialized
      if (!_isInitialized) {
        developer.log(
          'JT_NOTIFY skipped id=$id reason=not_initialized',
          name: 'NotificationService',
        );
        return;
      }

      if (scheduledTime.isBefore(DateTime.now())) {
        developer.log(
          'JT_NOTIFY skipped id=$id reason=in_past',
          name: 'NotificationService',
        );
        return;
      }

      final tz.TZDateTime scheduledDate = tz.TZDateTime.from(
        scheduledTime,
        tz.local,
      );

      // Get the appropriate sound mode based on notification type
      int soundMode;
      try {
        if (notificationType == 'jamaat') {
          soundMode = await _settingsService.getJamaatNotificationSoundMode();
        } else {
          soundMode = await _settingsService.getPrayerNotificationSoundMode();
        }
      } catch (e) {
        soundMode = 3; // Default to custom sound 2
      }

      // Get notification configuration
      final config = _getNotificationConfig(
        notificationType: notificationType,
        soundMode: soundMode,
      );
      final customSoundResource = _getCustomSoundResource(
        notificationType: notificationType,
        soundMode: soundMode,
      );

      // Phase 2.3: lazily create the channel for this sound mode if it
      // wasn't already created at boot. Idempotent and O(1) on cache hit.
      await _ensureChannelById(config['channelId'] as String);

      // Schedule the notification
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            config['channelId'],
            notificationType == 'prayer'
                ? 'Prayer Notifications'
                : 'Jamaat Notifications',
            channelDescription:
                'Notifications for ${notificationType == 'prayer' ? 'prayer' : 'jamaat'} times',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            enableVibration: config['enableVibration'],
            playSound: config['playSound'],
            icon: '@mipmap/launcher_icon',
            color: const Color(0xFF388E3C),
            sound: customSoundResource != null
                ? RawResourceAndroidNotificationSound(customSoundResource)
                : null,
            vibrationPattern: config['enableVibration']
                ? Int64List.fromList([0, 5000])
                : null,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: _androidScheduleMode,
      );
      developer.log(
        'JT_NOTIFY scheduled id=$id type=$notificationType at=${scheduledDate.toIso8601String()} mode=${_exactAlarmsAvailable ? "exact" : "inexact"}',
        name: 'NotificationService',
      );
    } catch (e) {
      developer.log(
        'JT_NOTIFY error id=$id $e',
        name: 'NotificationService',
        error: e,
      );
      rethrow;
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
    } catch (e) {
      developer.log(
        'Error cancelling notifications: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  /// Calculate prayer notification times without scheduling them
  /// Returns a map of prayer names to their notification times
  Map<String, DateTime?> calculatePrayerNotificationTimes(
    Map<String, DateTime?> prayerTimes,
  ) {
    try {
      final Map<String, DateTime?> notificationTimes = {};

      // Convert prayer times to Bangladesh timezone before calculation
      final Map<String, DateTime> localPrayerTimes = {};
      for (final entry in prayerTimes.entries) {
        if (entry.value != null) {
          // Convert to Bangladesh timezone
          final localTime = tz.TZDateTime.from(
            entry.value!,
            tz.getLocation('Asia/Dhaka'),
          );
          localPrayerTimes[entry.key] = localTime;
        }
      }

      // Calculate notification times with correct logic using local prayer times:
      // Fajr notification = 20 minutes before Sunrise
      if (localPrayerTimes.containsKey('Fajr') &&
          localPrayerTimes.containsKey('Sunrise')) {
        final sunriseTime = localPrayerTimes['Sunrise']!;
        final notifyTime = sunriseTime.subtract(const Duration(minutes: 20));
        notificationTimes['Fajr'] = notifyTime;
      }

      // Dhuhr notification = 20 minutes before Asr
      if (localPrayerTimes.containsKey('Dhuhr') &&
          localPrayerTimes.containsKey('Asr')) {
        final asrTime = localPrayerTimes['Asr']!;
        final notifyTime = asrTime.subtract(const Duration(minutes: 20));
        notificationTimes['Dhuhr'] = notifyTime;
      }

      // Asr notification = 20 minutes before Maghrib
      if (localPrayerTimes.containsKey('Asr') &&
          localPrayerTimes.containsKey('Maghrib')) {
        final maghribTime = localPrayerTimes['Maghrib']!;
        final notifyTime = maghribTime.subtract(const Duration(minutes: 20));
        notificationTimes['Asr'] = notifyTime;
      }

      // Maghrib notification = 20 minutes before Isha
      if (localPrayerTimes.containsKey('Maghrib') &&
          localPrayerTimes.containsKey('Isha')) {
        final ishaTime = localPrayerTimes['Isha']!;
        final notifyTime = ishaTime.subtract(const Duration(minutes: 20));
        notificationTimes['Maghrib'] = notifyTime;
      }

      // Isha notification = 20 minutes before next day's Fajr
      if (localPrayerTimes.containsKey('Isha') &&
          localPrayerTimes.containsKey('Fajr')) {
        final fajrTime = localPrayerTimes['Fajr']!;
        // Add 1 day to Fajr time for next day
        final nextDayFajr = fajrTime.add(const Duration(days: 1));
        final notifyTime = nextDayFajr.subtract(const Duration(minutes: 20));
        notificationTimes['Isha'] = notifyTime;
      }

      return notificationTimes;
    } catch (e) {
      return {};
    }
  }

  /// Calculate jamaat notification times without scheduling them
  /// Returns a map of prayer names to their jamaat notification times
  Map<String, DateTime?> calculateJamaatNotificationTimes(
    Map<String, dynamic>? jamaatTimes,
  ) {
    try {
      final Map<String, DateTime?> notificationTimes = {};

      if (jamaatTimes != null) {
        // Use the configured location's timezone consistently
        final location = _getLocation();
        final now = tz.TZDateTime.now(location);

        for (final entry in jamaatTimes.entries) {
          final name = entry.key;
          final value = entry.value;

          if (value != null &&
              value is String &&
              value.isNotEmpty &&
              value != '-') {
            try {
              final parts = value.split(':');
              if (parts.length != 2) {
                developer.log(
                  'Invalid jamaat time format for $name: "$value" (expected HH:mm)',
                  name: 'NotificationService',
                );
                continue;
              }

              final hour = int.tryParse(parts[0]);
              final minute = int.tryParse(parts[1]);

              // Validate parsed values
              if (hour == null || minute == null) {
                developer.log(
                  'Failed to parse time components for $name: "$value"',
                  name: 'NotificationService',
                );
                continue;
              }

              // Validate time ranges
              if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
                developer.log(
                  'Time out of range for $name: hour=$hour, minute=$minute',
                  name: 'NotificationService',
                );
                continue;
              }

              // Create jamaat time in the configured location's timezone
              final jamaatTime = tz.TZDateTime(
                location,
                now.year,
                now.month,
                now.day,
                hour,
                minute,
              );
              final notifyTime = jamaatTime.subtract(
                const Duration(minutes: 10),
              );

              // Store the notification time (convert to regular DateTime for display)
              // This preserves the actual time in the location's timezone
              notificationTimes[name] = DateTime(
                notifyTime.year,
                notifyTime.month,
                notifyTime.day,
                notifyTime.hour,
                notifyTime.minute,
              );
            } catch (e) {
              developer.log(
                'Error calculating notification time for $name: "$value" - $e',
                name: 'NotificationService',
                error: e,
              );
            }
          }
        }
      }

      return notificationTimes;
    } catch (e) {
      developer.log(
        'Error in calculateJamaatNotificationTimes: $e',
        name: 'NotificationService',
        error: e,
      );
      return {};
    }
  }

  /// Schedule prayer notifications
  Future<void> schedulePrayerNotifications(
    Map<String, DateTime?> prayerTimes,
  ) async {
    try {
      final locale = await _resolveLocale();
      final strings = AppText.of(locale);

      // Use the configured location's timezone for all comparisons
      final location = _getLocation();
      final now = tz.TZDateTime.now(location);

      // Convert prayer times to the configured location's timezone
      final Map<String, tz.TZDateTime> localPrayerTimes = {};
      for (final entry in prayerTimes.entries) {
        if (entry.value != null) {
          // Convert to the correct timezone
          final localTime = tz.TZDateTime.from(entry.value!, location);
          localPrayerTimes[entry.key] = localTime;
        }
      }

      // Schedule notifications with correct logic using local prayer times:
      // Fajr notification = 20 minutes before Sunrise
      if (localPrayerTimes.containsKey('Fajr') &&
          localPrayerTimes.containsKey('Sunrise')) {
        final sunriseTime = localPrayerTimes['Sunrise']!;
        final notifyTime = sunriseTime.subtract(const Duration(minutes: 20));

        // Compare TZDateTime objects directly in the same timezone
        if (notifyTime.isAfter(now)) {
          final prayerLabel = _localizedPrayerName(locale, 'Fajr');
          await scheduleNotification(
            id: _prayerNotificationIds['Fajr']!,
            title: strings.notification_prayerTitle(prayerLabel),
            body: strings.notification_prayerBody(prayerLabel),
            scheduledTime: notifyTime,
            notificationType: 'prayer',
          );
        }
      }

      // Dhuhr notification = 20 minutes before Asr
      if (localPrayerTimes.containsKey('Dhuhr') &&
          localPrayerTimes.containsKey('Asr')) {
        final asrTime = localPrayerTimes['Asr']!;
        final notifyTime = asrTime.subtract(const Duration(minutes: 20));

        if (notifyTime.isAfter(now)) {
          final prayerLabel = _localizedPrayerName(locale, 'Dhuhr');
          await scheduleNotification(
            id: _prayerNotificationIds['Dhuhr']!,
            title: strings.notification_prayerTitle(prayerLabel),
            body: strings.notification_prayerBody(prayerLabel),
            scheduledTime: notifyTime,
            notificationType: 'prayer',
          );
        }
      }

      // Asr notification = 20 minutes before Maghrib
      if (localPrayerTimes.containsKey('Asr') &&
          localPrayerTimes.containsKey('Maghrib')) {
        final maghribTime = localPrayerTimes['Maghrib']!;
        final notifyTime = maghribTime.subtract(const Duration(minutes: 20));

        if (notifyTime.isAfter(now)) {
          final prayerLabel = _localizedPrayerName(locale, 'Asr');
          await scheduleNotification(
            id: _prayerNotificationIds['Asr']!,
            title: strings.notification_prayerTitle(prayerLabel),
            body: strings.notification_prayerBody(prayerLabel),
            scheduledTime: notifyTime,
            notificationType: 'prayer',
          );
        }
      }

      // Maghrib notification = 20 minutes before Isha
      if (localPrayerTimes.containsKey('Maghrib') &&
          localPrayerTimes.containsKey('Isha')) {
        final ishaTime = localPrayerTimes['Isha']!;
        final notifyTime = ishaTime.subtract(const Duration(minutes: 20));

        if (notifyTime.isAfter(now)) {
          final prayerLabel = _localizedPrayerName(locale, 'Maghrib');
          await scheduleNotification(
            id: _prayerNotificationIds['Maghrib']!,
            title: strings.notification_prayerTitle(prayerLabel),
            body: strings.notification_prayerBody(prayerLabel),
            scheduledTime: notifyTime,
            notificationType: 'prayer',
          );
        }
      }

      // Isha notification = 20 minutes before next day's Fajr
      if (localPrayerTimes.containsKey('Isha') &&
          localPrayerTimes.containsKey('Fajr')) {
        final fajrTime = localPrayerTimes['Fajr']!;
        // Add 1 day to Fajr time for next day
        final nextDayFajr = fajrTime.add(const Duration(days: 1));
        final notifyTime = nextDayFajr.subtract(const Duration(minutes: 20));

        if (notifyTime.isAfter(now)) {
          final prayerLabel = _localizedPrayerName(locale, 'Isha');
          await scheduleNotification(
            id: _prayerNotificationIds['Isha']!,
            title: strings.notification_prayerTitle(prayerLabel),
            body: strings.notification_prayerBody(prayerLabel),
            scheduledTime: notifyTime,
            notificationType: 'prayer',
          );
        }
      }
    } catch (e) {
      developer.log(
        'Error in schedulePrayerNotifications: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  /// Schedule Jamaat notifications with separate sound settings
  Future<void> scheduleJamaatNotifications(
    Map<String, dynamic>? jamaatTimes,
  ) async {
    try {
      final locale = await _resolveLocale();
      final strings = AppText.of(locale);

      if (jamaatTimes != null) {
        // Use the configured location's timezone for all time comparisons
        final location = _getLocation();
        final now = tz.TZDateTime.now(location);

        for (final entry in jamaatTimes.entries) {
          final name = entry.key;
          final value = entry.value;

          if (value != null &&
              value is String &&
              value.isNotEmpty &&
              value != '-') {
            try {
              final parts = value.split(':');
              if (parts.length != 2) {
                developer.log(
                  'Invalid jamaat time format for $name: "$value" (expected HH:mm)',
                  name: 'NotificationService',
                );
                continue;
              }

              final hour = int.tryParse(parts[0]);
              final minute = int.tryParse(parts[1]);

              // Validate parsed values
              if (hour == null || minute == null) {
                developer.log(
                  'Failed to parse time components for $name: "$value"',
                  name: 'NotificationService',
                );
                continue;
              }

              // Validate time ranges
              if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
                developer.log(
                  'Time out of range for $name: hour=$hour, minute=$minute',
                  name: 'NotificationService',
                );
                continue;
              }

              // Create jamaat time in the configured location's timezone
              final jamaatTime = tz.TZDateTime(
                location,
                now.year,
                now.month,
                now.day,
                hour,
                minute,
              );
              final notifyTime = jamaatTime.subtract(
                const Duration(minutes: 10),
              );

              // Compare TZDateTime objects directly in the same timezone
              // This fixes the midnight comparison issue
              if (notifyTime.isAfter(now)) {
                final canonicalPrayerName = _canonicalPrayerNameFromJamaatKey(
                  name,
                );
                final jamaatId = _jamaatNotificationIds[canonicalPrayerName];
                if (jamaatId == null) {
                  developer.log(
                    'JT_NOTIFY skipped jamaat=$name reason=unknown_prayer_key',
                    name: 'NotificationService',
                  );
                  continue;
                }
                final displayName = _localizedPrayerName(
                  locale,
                  canonicalPrayerName,
                );
                await scheduleNotification(
                  id: jamaatId,
                  title: strings.notification_jamaatTitle(displayName),
                  body: strings.notification_jamaatBody(displayName),
                  scheduledTime: notifyTime,
                  notificationType: 'jamaat',
                );
              }
            } catch (e) {
              developer.log(
                'Error parsing jamaat time for $name: "$value" - $e',
                name: 'NotificationService',
                error: e,
              );
            }
          }
        }
      }
    } catch (e) {
      developer.log(
        'Error in scheduleJamaatNotifications: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  /// Schedule Fajr voice notification exactly at Fajr start time (if enabled)
  Future<void> scheduleFajrVoiceNotification(
    Map<String, DateTime?> prayerTimes,
  ) async {
    try {
      final enabled = await _settingsService.getFajrVoiceNotificationEnabled();

      if (!enabled) {
        await flutterLocalNotificationsPlugin.cancel(_fajrVoiceNotificationId);
        developer.log(
          'JT_NOTIFY skipped id=$_fajrVoiceNotificationId reason=disabled',
          name: 'NotificationService',
        );
        return;
      }

      final fajrTime = prayerTimes['Fajr'];
      if (fajrTime == null) {
        developer.log(
          'JT_NOTIFY skipped id=$_fajrVoiceNotificationId reason=no_fajr_time',
          name: 'NotificationService',
        );
        return;
      }

      final location = _getLocation();
      final now = tz.TZDateTime.now(location);
      final fajrLocal = nextFajrVoiceNotificationTime(
        fajrTime: fajrTime,
        now: now,
        location: location,
      );

      final locale = await _resolveLocale();
      final strings = AppText.of(locale);
      final prayerLabel = _localizedPrayerName(locale, 'Fajr');

      await flutterLocalNotificationsPlugin.zonedSchedule(
        _fajrVoiceNotificationId,
        strings.notification_prayerTitle(prayerLabel),
        strings.notification_fajrStartBody(prayerLabel),
        fajrLocal,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'fajr_voice_channel_v1',
            'Fajr Voice Notification',
            channelDescription:
                'Plays voice reminder at Fajr prayer start time',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            enableVibration: true,
            playSound: true,
            icon: '@mipmap/launcher_icon',
            color: const Color(0xFF388E3C),
            sound: RawResourceAndroidNotificationSound('fajr_prayer_voice'),
            vibrationPattern: Int64List.fromList([0, 5000]),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: _androidScheduleMode,
      );
      developer.log(
        'JT_NOTIFY scheduled id=$_fajrVoiceNotificationId at=${fajrLocal.toIso8601String()} mode=${_exactAlarmsAvailable ? "exact" : "inexact"}',
        name: 'NotificationService',
      );
    } catch (e) {
      developer.log(
        'JT_NOTIFY error id=$_fajrVoiceNotificationId $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  @visibleForTesting
  static tz.TZDateTime nextFajrVoiceNotificationTime({
    required DateTime fajrTime,
    required tz.TZDateTime now,
    required tz.Location location,
  }) {
    final fajrLocal = tz.TZDateTime.from(fajrTime, location);
    return fajrLocal.isAfter(now)
        ? fajrLocal
        : fajrLocal.add(const Duration(days: 1));
  }

  /// Schedule all notifications (prayer and Jamaat)
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

      // The user may have toggled the OS-level "Alarms & reminders"
      // permission since last schedule; re-check before picking a mode.
      await refreshExactAlarmsAvailable();
      developer.log(
        'JT_NOTIFY scheduleAll called exact=$_exactAlarmsAvailable',
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

  /// Get pending notifications for debugging
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await flutterLocalNotificationsPlugin
          .pendingNotificationRequests();
    } catch (e) {
      developer.log(
        'Error getting pending notifications: $e',
        name: 'NotificationService',
        error: e,
      );
      return [];
    }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidImplementation != null) {
        return await androidImplementation.areNotificationsEnabled() ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get initialization status
  bool get isInitialized => _isInitialized;

  /// Reset notification service
  Future<void> reset() async {
    _isInitialized = false;
    _initializeFuture = null;
    await initialize(null);
  }

  /// Check if notification service is ready
  Future<bool> isReady() async {
    if (!_isInitialized) {
      return false;
    }

    return await areNotificationsEnabled();
  }

  /// Recreate notification channel with new settings
  Future<void> recreateNotificationChannel() async {
    try {
      // Recreate channels with new settings
      await _createAllNotificationChannels();
    } catch (e) {
      developer.log(
        'Error recreating notification channels: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  /// Handle notification sound mode change - recreate channel and reschedule notifications
  Future<void> handleNotificationSoundModeChange() async {
    try {
      // First, recreate the notification channel with new settings
      await recreateNotificationChannel();

      // Cancel all existing notifications to ensure they use the new channel settings
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
