import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class JamaatChannels {
  static String channelIdForSoundMode(int soundMode) {
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

  static String? customSoundResource(int soundMode) {
    switch (soundMode) {
      case 0:
        return 'jamaat_allahu_akbar';
      case 3:
        return 'jamaat_custom_2';
      case 4:
        return 'jamaat_custom_3';
      default:
        return null;
    }
  }

  static AndroidNotificationChannel? buildChannelById(String id) {
    switch (id) {
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
      default:
        return null;
    }
  }

  static const List<String> allChannelIds = <String>[
    'jamaat_channel_custom',
    'jamaat_channel_custom_2',
    'jamaat_channel_custom_3',
    'jamaat_channel_system',
    'jamaat_channel_silent',
  ];
}
