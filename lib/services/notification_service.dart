import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:jamaat_time/services/settings_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  final SettingsService _settingsService = SettingsService();

  /// Call this at app startup to ensure notifications are ready before scheduling.
  Future<void> initialize(BuildContext? context) async {
    if (_isInitialized) return;
    developer.log(
      'Initializing notification service',
      name: 'NotificationService',
    );
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsIOS =
        const DarwinInitializationSettings();
    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    final bool? initialized = await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        developer.log(
          'Notification tapped: ${response.payload}',
          name: 'NotificationService',
        );
      },
    );

    developer.log(
      'Notification plugin initialized: $initialized',
      name: 'NotificationService',
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      await _createNotificationChannel();
    }

    // Request notification permissions for Android 13+ and iOS
    try {
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();
        if (androidImplementation != null) {
          final granted = await androidImplementation
              .requestNotificationsPermission();
          developer.log(
            'Android notification permission granted: $granted',
            name: 'NotificationService',
          );
          if (context != null && granted != true && context.mounted) {
            _showPermissionDialog(context);
          }
        }
      } else if (Platform.isIOS) {
        final IOSFlutterLocalNotificationsPlugin? iosImplementation =
            flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >();
        if (iosImplementation != null) {
          final granted = await iosImplementation.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          developer.log(
            'iOS notification permission granted: $granted',
            name: 'NotificationService',
          );
          if (context != null && granted != true && context.mounted) {
            _showPermissionDialog(context);
          }
        }
      }
    } catch (e) {
      developer.log(
        'Error requesting notification permissions: $e',
        name: 'NotificationService',
        error: e,
      );
    }

    _isInitialized = true;
    developer.log(
      'Notification service initialized',
      name: 'NotificationService',
    );
    developer.log(
      'Custom adhan sound configured: adhan.mp3',
      name: 'NotificationService',
    );
  }

  /// Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    try {
      // Get user's sound mode preference
      final mode = await _settingsService.getNotificationSoundMode();
      RawResourceAndroidNotificationSound? customSound;
      bool playSound = mode != 2;

      // Only use custom sound if mode is 0 (custom) and we're on Android
      if (mode == 0 && Platform.isAndroid) {
        try {
          customSound = RawResourceAndroidNotificationSound('allahu_akbar');
          developer.log(
            'Custom sound configured: allahu_akbar',
            name: 'NotificationService',
          );
        } catch (e) {
          developer.log(
            'Error configuring custom sound, using system default: $e',
            name: 'NotificationService',
            error: e,
          );
          customSound = null;
        }
      }

      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        'prayer_channel',
        'Prayer Times',
        description: 'Notifications for prayer and Jamaat times',
        importance: Importance.max,
        playSound: playSound,
        enableVibration: playSound,
        showBadge: true,
        sound: customSound,
      );

      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(channel);
        developer.log(
          'Notification channel created successfully with sound mode: $mode',
          name: 'NotificationService',
        );
      }
    } catch (e) {
      developer.log(
        'Error creating notification channel: $e',
        name: 'NotificationService',
        error: e,
      );
      // Fallback: create channel without custom sound
      try {
        const AndroidNotificationChannel fallbackChannel =
            AndroidNotificationChannel(
              'prayer_channel',
              'Prayer Times',
              description: 'Notifications for prayer and Jamaat times',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
              showBadge: true,
              sound: null, // Use system default
            );

        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();

        if (androidImplementation != null) {
          await androidImplementation.createNotificationChannel(
            fallbackChannel,
          );
          developer.log(
            'Notification channel created with fallback settings',
            name: 'NotificationService',
          );
        }
      } catch (fallbackError) {
        developer.log(
          'Error creating fallback notification channel: $fallbackError',
          name: 'NotificationService',
          error: fallbackError,
        );
      }
    }
  }

  /// Show a dialog to inform the user that notification permissions are needed.
  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notification Permission Required'),
        content: const Text(
          'To receive prayer and Jamaat time reminders, please enable notification permissions for this app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Open app settings to allow user to enable notifications
  void _openAppSettings() {
    // This will open the app's notification settings
    // Note: This is a simplified approach - in a real app you might want to use a package like app_settings
    developer.log(
      'User should manually open app settings to enable notifications',
      name: 'NotificationService',
    );
  }

  Future<AndroidNotificationDetails> _androidDetails({
    required String channelId,
    required String channelName,
    required String? channelDescription,
    Color? color,
    Int64List? vibrationPattern,
  }) async {
    final mode = await _settingsService.getNotificationSoundMode();
    RawResourceAndroidNotificationSound? customSound;
    bool playSound = mode != 2;

    // Only use custom sound if mode is 0 (custom) and we're on Android
    if (mode == 0 && Platform.isAndroid) {
      try {
        customSound = RawResourceAndroidNotificationSound('allahu_akbar');
      } catch (e) {
        developer.log(
          'Error configuring custom sound in _androidDetails: $e',
          name: 'NotificationService',
          error: e,
        );
        customSound = null;
      }
    }

    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: playSound,
      playSound: playSound,
      icon: '@mipmap/launcher_icon',
      color: color,
      sound: (mode == 1 || mode == 2) ? null : customSound,
      vibrationPattern: playSound
          ? (vibrationPattern ?? Int64List.fromList([0, 5000]))
          : null,
    );
  }

  /// Schedule notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    try {
      if (scheduledTime.isBefore(DateTime.now())) {
        developer.log(
          'Skipping past notification: $title at ${scheduledTime.toString()}',
          name: 'NotificationService',
        );
        return;
      }

      final tz.TZDateTime scheduledDate = tz.TZDateTime.from(
        scheduledTime,
        tz.local,
      );
      developer.log(
        'Scheduling notification: $title at ${scheduledDate.toString()}',
        name: 'NotificationService',
      );

      final androidDetails = await _androidDetails(
        channelId: 'prayer_channel',
        channelName: 'Prayer Times',
        channelDescription: 'Notifications for prayer and Jamaat times',
        color: const Color(0xFF43A047),
        vibrationPattern: Int64List.fromList([0, 5000]),
      );

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        NotificationDetails(
          android: androidDetails,
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            // Use custom adhan sound
            sound: 'adhan.wav',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      developer.log(
        'Notification scheduled successfully: $title at ${scheduledDate.toString()}',
        name: 'NotificationService',
      );
    } catch (e) {
      developer.log(
        'Error scheduling notification: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
      developer.log('All notifications cancelled', name: 'NotificationService');
    } catch (e) {
      developer.log(
        'Error cancelling notifications: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  /// Schedule prayer notifications
  Future<void> schedulePrayerNotifications(
    Map<String, DateTime?> prayerTimes,
  ) async {
    try {
      developer.log(
        'Scheduling prayer notifications for ${prayerTimes.length} prayers',
        name: 'NotificationService',
      );
      int scheduledCount = 0;
      final now = DateTime.now();

      for (final entry in prayerTimes.entries) {
        final name = entry.key;
        final time = entry.value;
        if (time != null) {
          final notifyTime = time.subtract(const Duration(minutes: 20));

          // Check if notification time is in the future (within next 24 hours)
          if (notifyTime.isAfter(now)) {
            await scheduleNotification(
              id: name.hashCode,
              title: '$name Prayer',
              body: '$name prayer is in 20 minutes.',
              scheduledTime: notifyTime,
            );
            scheduledCount++;
            developer.log(
              'Scheduled $name prayer notification for ${notifyTime.toString()}',
              name: 'NotificationService',
            );
          } else {
            // Check if prayer time is today but notification time has passed
            final prayerTimeToday = DateTime(
              now.year,
              now.month,
              now.day,
              time.hour,
              time.minute,
            );
            if (prayerTimeToday.isAfter(now)) {
              // Prayer is still today, schedule notification for next prayer
              final nextNotifyTime = prayerTimeToday.subtract(
                const Duration(minutes: 20),
              );
              if (nextNotifyTime.isAfter(now)) {
                await scheduleNotification(
                  id: name.hashCode,
                  title: '$name Prayer',
                  body: '$name prayer is in 20 minutes.',
                  scheduledTime: nextNotifyTime,
                );
                scheduledCount++;
                developer.log(
                  'Scheduled $name prayer notification for today: ${nextNotifyTime.toString()}',
                  name: 'NotificationService',
                );
              }
            } else {
              developer.log(
                'Skipping $name prayer notification - prayer time already passed today',
                name: 'NotificationService',
              );
            }
          }
        }
      }
      developer.log(
        'Scheduled $scheduledCount prayer notifications',
        name: 'NotificationService',
      );
    } catch (e) {
      developer.log(
        'Error scheduling prayer notifications: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  /// Schedule Jamaat notifications
  Future<void> scheduleJamaatNotifications(
    Map<String, dynamic>? jamaatTimes,
  ) async {
    try {
      developer.log(
        'Scheduling Jamaat notifications',
        name: 'NotificationService',
      );
      if (jamaatTimes != null) {
        int scheduledCount = 0;
        final now = DateTime.now();

        for (final entry in jamaatTimes.entries) {
          final name = entry.key;
          final value = entry.value;
          if (value != null &&
              value is String &&
              value.isNotEmpty &&
              value != '-') {
            try {
              final parts = value.split(':');
              if (parts.length == 2) {
                final jamaatTime = DateTime(
                  now.year,
                  now.month,
                  now.day,
                  int.parse(parts[0]),
                  int.parse(parts[1]),
                );
                final notifyTime = jamaatTime.subtract(
                  const Duration(minutes: 10),
                );

                // Check if notification time is in the future
                if (notifyTime.isAfter(now)) {
                  await scheduleNotification(
                    id: name.hashCode + 1000,
                    title: '$name Jamaat',
                    body: '$name Jamaat is in 10 minutes.',
                    scheduledTime: notifyTime,
                  );
                  scheduledCount++;
                  developer.log(
                    'Scheduled $name Jamaat notification for ${notifyTime.toString()}',
                    name: 'NotificationService',
                  );
                } else {
                  // Check if jamaat time is today but notification time has passed
                  if (jamaatTime.isAfter(now)) {
                    // Jamaat is still today, schedule notification
                    final nextNotifyTime = jamaatTime.subtract(
                      const Duration(minutes: 10),
                    );
                    if (nextNotifyTime.isAfter(now)) {
                      await scheduleNotification(
                        id: name.hashCode + 1000,
                        title: '$name Jamaat',
                        body: '$name Jamaat is in 10 minutes.',
                        scheduledTime: nextNotifyTime,
                      );
                      scheduledCount++;
                      developer.log(
                        'Scheduled $name Jamaat notification for today: ${nextNotifyTime.toString()}',
                        name: 'NotificationService',
                      );
                    }
                  } else {
                    developer.log(
                      'Skipping $name Jamaat notification - jamaat time already passed today',
                      name: 'NotificationService',
                    );
                  }
                }
              }
            } catch (e) {
              developer.log(
                'Error parsing Jamaat time for $name: $e',
                name: 'NotificationService',
                error: e,
              );
            }
          }
        }
        developer.log(
          'Scheduled $scheduledCount Jamaat notifications',
          name: 'NotificationService',
        );
      }
    } catch (e) {
      developer.log(
        'Error scheduling Jamaat notifications: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  /// Schedule all notifications (prayer and Jamaat)
  Future<void> scheduleAllNotifications(
    Map<String, DateTime?> prayerTimes,
    Map<String, dynamic>? jamaatTimes,
  ) async {
    try {
      developer.log(
        'Starting to schedule all notifications',
        name: 'NotificationService',
      );
      await cancelAllNotifications();
      await schedulePrayerNotifications(prayerTimes);
      await scheduleJamaatNotifications(jamaatTimes);
      developer.log(
        'All notifications scheduled successfully',
        name: 'NotificationService',
      );
    } catch (e) {
      developer.log(
        'Error in scheduleAllNotifications: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  /// Check device notification and sound settings
  Future<Map<String, dynamic>> checkDeviceSettings() async {
    final Map<String, dynamic> settings = {
      'deviceModel': Platform.isAndroid ? 'Android Device' : 'iOS Device',
      'androidVersion': Platform.isAndroid ? 'Android' : 'iOS',
      'notificationsEnabled': false,
      'soundEnabled': true,
      'vibrationEnabled': true,
      'doNotDisturb': false,
      'batteryOptimization': false,
      'appNotifications': false,
    };

    try {
      // Check basic notification permissions
      settings['notificationsEnabled'] = await areNotificationsEnabled();

      // For Android, we can check more settings
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();

        if (androidImplementation != null) {
          // Check if notifications are enabled for the app
          settings['appNotifications'] =
              await androidImplementation.areNotificationsEnabled() ?? false;
        }
      }

      developer.log(
        'Device settings check completed: $settings',
        name: 'NotificationService',
      );
      return settings;
    } catch (e) {
      developer.log(
        'Error checking device settings: $e',
        name: 'NotificationService',
        error: e,
      );
      settings['error'] = e.toString();
      return settings;
    }
  }

  /// Show detailed device settings information
  void showDeviceSettingsInfo(BuildContext context) {
    checkDeviceSettings().then((settings) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Device Settings Check'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Device: ${settings['deviceModel']}'),
                Text(
                  'Notifications Enabled: ${settings['notificationsEnabled']}',
                ),
                Text('App Notifications: ${settings['appNotifications']}'),
                const SizedBox(height: 16),
                const Text(
                  'If notifications are not working:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text('1. Check device notification settings'),
                const Text('2. Ensure Do Not Disturb is OFF'),
                const Text('3. Check app notification permissions'),
                const Text('4. Verify device volume is ON'),
                const Text('5. Check battery optimization settings'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    });
  }

  /// Check if notification permissions are granted
  Future<bool> areNotificationsEnabled() async {
    try {
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();
        if (androidImplementation != null) {
          return await androidImplementation.areNotificationsEnabled() ?? false;
        }
      }
      return false;
    } catch (e) {
      developer.log(
        'Error checking notification permissions: $e',
        name: 'NotificationService',
        error: e,
      );
      return false;
    }
  }

  /// Get system information for debugging
  Future<String> getSystemInfo() async {
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final version = androidInfo.version;
      final sdkInt = androidInfo.version.sdkInt;
      final manufacturer = androidInfo.manufacturer;
      final model = androidInfo.model;

      return 'Android $version (SDK $sdkInt) - $manufacturer $model';
    } catch (e) {
      return 'Error getting system info: $e';
    }
  }

  /// Recreate notification channel with custom sound
  Future<void> recreateNotificationChannel() async {
    try {
      developer.log(
        'Recreating notification channel with user sound mode...',
        name: 'NotificationService',
      );

      // Delete existing channels
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidImplementation != null) {
        // Delete all existing channels to ensure clean recreation
        await androidImplementation.deleteNotificationChannel('prayer_channel');
        developer.log(
          'Deleted existing notification channels',
          name: 'NotificationService',
        );

        // Get user's sound mode preference
        final mode = await _settingsService.getNotificationSoundMode();
        RawResourceAndroidNotificationSound? customSound;
        bool playSound = mode != 2;

        // Only use custom sound if mode is 0 (custom) and we're on Android
        if (mode == 0 && Platform.isAndroid) {
          try {
            customSound = RawResourceAndroidNotificationSound('allahu_akbar');
            developer.log(
              'Custom sound configured for channel recreation: allahu_akbar',
              name: 'NotificationService',
            );
          } catch (e) {
            developer.log(
              'Error configuring custom sound for channel recreation: $e',
              name: 'NotificationService',
              error: e,
            );
            customSound = null;
          }
        }

        // Create new prayer channel with user sound mode
        final AndroidNotificationChannel prayerChannel =
            AndroidNotificationChannel(
              'prayer_channel',
              'Prayer Times',
              description: 'Notifications for prayer and Jamaat times',
              importance: Importance.max,
              playSound: playSound,
              enableVibration: playSound,
              showBadge: true,
              sound: customSound,
            );

        await androidImplementation.createNotificationChannel(prayerChannel);
        developer.log(
          'Created new prayer channel with sound mode: $mode',
          name: 'NotificationService',
        );
      }
    } catch (e) {
      developer.log(
        'Error recreating notification channel: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }
}
