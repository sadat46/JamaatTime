import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Android channel used for FCM broadcast notifications. Kept distinct from
// the local jamaat-reminder channels owned by notification_service.dart so
// users can mute one stream without affecting the other.
const String broadcastChannelId = 'notice_board';
const String broadcastChannelName = 'Notice Board';
const String broadcastChannelDescription =
    'App-wide announcements and jamaat time updates.';

const AndroidNotificationChannel broadcastAndroidChannel =
    AndroidNotificationChannel(
      broadcastChannelId,
      broadcastChannelName,
      description: broadcastChannelDescription,
      importance: Importance.high,
    );
