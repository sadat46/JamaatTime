import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../firebase_options.dart';

// Top-level background entry point required by FirebaseMessaging on Android.
// When the app is terminated or background, Android renders the notification
// natively from the `notification` payload — this handler only ensures
// Firebase is initialized so data-only messages don't crash the isolate.
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
}
