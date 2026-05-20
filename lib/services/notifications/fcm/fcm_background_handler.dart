import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../firebase_options.dart';
import '../notification_ids.dart';

// Top-level background entry point required by FirebaseMessaging on Android.
// When the app is terminated or background, Android renders the notification
// natively from the `notification` payload — this handler only ensures
// Firebase is initialized so data-only messages don't crash the isolate.
//
// Tombstone limitation: a `remove_notice` push can cancel notifications that
// our local plugin rendered (foreground path uses NotificationIds.broadcast).
// Notifications Android rendered natively from the `notification` block while
// the app was killed carry a system-assigned id we cannot target here — those
// simply disappear from the notice board on the next Firestore sync.
@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Already initialized or transient — Android will still render from the
    // notification block.
  }

  if (message.data['action'] == 'remove_notice') {
    final notifId =
        (message.data['notifId'] ?? message.data['notification_id']) as String?;
    if (notifId != null && notifId.isNotEmpty) {
      try {
        final plugin = FlutterLocalNotificationsPlugin();
        await plugin.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/launcher_icon'),
          ),
        );
        await plugin.cancel(NotificationIds.broadcast(notifId));
      } catch (_) {
        // Best-effort: nothing to cancel, or plugin unavailable in isolate.
      }
    }
  }
}
