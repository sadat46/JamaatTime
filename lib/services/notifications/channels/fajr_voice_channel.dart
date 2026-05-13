import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FajrVoiceChannel {
  static const String channelId = 'fajr_voice_channel_v1';

  static AndroidNotificationChannel? buildChannelById(String id) {
    if (id != channelId) return null;
    return AndroidNotificationChannel(
      channelId,
      'Tahajjud end and Fajr start voice notification',
      description: 'Plays voice reminder at Fajr prayer start time',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
      sound: RawResourceAndroidNotificationSound('fajr_prayer_voice'),
    );
  }
}
