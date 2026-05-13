import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PrayerChannels {
  static String channelIdForSoundMode(int soundMode) {
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

  static String? customSoundResource(int soundMode) {
    switch (soundMode) {
      case 0:
        return 'prayer_allahu_akbar';
      case 3:
        return 'prayer_custom_2';
      case 4:
        return 'prayer_custom_3';
      default:
        return null;
    }
  }

  static AndroidNotificationChannel? buildChannelById(String id) {
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
      default:
        return null;
    }
  }

  static const List<String> allChannelIds = <String>[
    'prayer_channel_custom',
    'prayer_channel_custom_2',
    'prayer_channel_custom_3',
    'prayer_channel_system',
    'prayer_channel_silent',
  ];
}
