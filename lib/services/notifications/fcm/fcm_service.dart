import 'dart:async';

import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/firebase_bootstrap.dart';
import 'broadcast_channel.dart';
import 'fcm_background_handler.dart';
import 'fcm_deep_link_router.dart';
import 'fcm_foreground_renderer.dart';
import 'fcm_token_repository.dart';

const String _kAllUsersTopic = 'all_users';
const String _kTopicSubscribedFlag = 'fcm.topic.all_users.subscribed.v1';

// Facade for the FCM receive layer. Runs on app start, BEFORE any auth gate,
// so guest devices subscribe to `all_users` and register in
// device_tokens/{installationId} without ever signing in.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();
  factory FcmService() => instance;

  // Exposed for a settings-screen CTA that re-prompts the user for
  // POST_NOTIFICATIONS when denial was the reason broadcasts don't display.
  final ValueNotifier<bool> notificationsPermissionDenied =
      ValueNotifier<bool>(false);

  bool _initialized = false;
  late final FlutterLocalNotificationsPlugin _localPlugin;
  late final FcmTokenRepository _repo;
  late final FcmForegroundRenderer _renderer;
  FcmDeepLinkRouter? _router;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<String>? _tokenRefreshSub;

  Future<void> init({
    required GlobalKey<NavigatorState> navigatorKey,
    required String locale,
  }) async {
    if (_initialized) return;

    _localPlugin = FlutterLocalNotificationsPlugin();
    _renderer = FcmForegroundRenderer(_localPlugin);
    _router = FcmDeepLinkRouter(navigatorKey);

    await _localPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final router = _router;
        if (router != null) unawaited(router.handlePayload(response.payload));
      },
    );

    // Channel creation is a local OS resource; create it before the
    // firebaseReady guard so background FCM renders never hit a missing channel
    // even if Firebase init transiently fails.
    await _localPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(broadcastAndroidChannel);
    await _router?.restorePendingIntent();

    if (!await firebaseReady) return;
    _repo = FcmTokenRepository();

    FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);

    final messaging = FirebaseMessaging.instance;
    FirebaseMessaging.onMessage.listen(_renderer.show);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedApp);
    try {
      final initial = await messaging.getInitialMessage();
      if (initial != null) _handleOpenedApp(initial);
    } catch (_) {
      // Opening from a notification is best-effort; receiving must still work.
    }

    _initialized = true;
    unawaited(_finishDeferredRegistration(messaging, locale));
  }

  Future<void> _finishDeferredRegistration(
    FirebaseMessaging messaging,
    String locale,
  ) async {
    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint(
          'JT_NOTIFY: POST_NOTIFICATIONS denied; broadcasts will not display.',
        );
        notificationsPermissionDenied.value = true;
      } else {
        notificationsPermissionDenied.value = false;
      }
    } catch (e) {
      debugPrint('JT_NOTIFY: requestPermission failed: $e');
    }

    // Register the FCM token first; subscribeToTopic requires a registered
    // token to succeed reliably.
    String? token;
    try {
      token = await messaging.getToken();
      await _persistToken(token: token, locale: locale);
    } catch (e) {
      debugPrint('JT_NOTIFY: getToken/persist failed: $e');
    }

    if (token != null && token.isNotEmpty) {
      await _ensureTopicSubscription(messaging);
    }

    _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) async {
      try {
        await _persistToken(token: newToken, locale: locale);
      } catch (_) {}
      // Token rotation invalidates the prior topic subscription; re-subscribe.
      await _clearTopicSubscribedFlag();
      await _ensureTopicSubscription(messaging);
    });

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) return;
      try {
        final t = await messaging.getToken();
        if (t == null) return;
        final installationId = await _safeInstallationId();
        if (installationId == null) {
          await _repo.saveForUser(uid: user.uid, token: t, locale: locale);
        } else {
          await _repo.migrateGuestToUser(
            installationId: installationId,
            uid: user.uid,
            token: t,
            locale: locale,
          );
        }
      } catch (_) {
        // Auth-linked token writes are diagnostic only for topic sends.
      }
    });
  }

  Future<void> _persistToken({
    required String? token,
    required String locale,
  }) async {
    if (token == null || token.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final installationId = await _safeInstallationId();
      await _repo.saveForUser(
        uid: user.uid,
        token: token,
        locale: locale,
        installationId: installationId,
      );
      return;
    }
    final installationId = await _safeInstallationId();
    if (installationId == null) return;
    await _repo.saveForDevice(
      installationId: installationId,
      token: token,
      locale: locale,
    );
  }

  Future<void> _ensureTopicSubscription(FirebaseMessaging messaging) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kTopicSubscribedFlag) == true) return;
    } catch (e) {
      debugPrint('JT_NOTIFY: prefs read failed for topic flag: $e');
    }
    try {
      await messaging.subscribeToTopic(_kAllUsersTopic);
      debugPrint('JT_NOTIFY: subscribed to topic $_kAllUsersTopic');
      try {
        await prefs?.setBool(_kTopicSubscribedFlag, true);
      } catch (_) {}
    } catch (e) {
      // Leave the flag unset so the next cold start (or token refresh) retries.
      debugPrint('JT_NOTIFY: subscribeToTopic failed: $e');
    }
  }

  Future<void> _clearTopicSubscribedFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kTopicSubscribedFlag);
    } catch (_) {}
  }

  Future<String?> _safeInstallationId() async {
    try {
      return await FirebaseInstallations.instance.getId();
    } catch (_) {
      return null;
    }
  }

  void _handleOpenedApp(RemoteMessage message) {
    final router = _router;
    if (router != null) {
      unawaited(router.handleRemoteMessageData(message.data));
    }
  }

  // Exposed for a settings-screen dev button (deferred in P2).
  Future<Map<String, String?>> debugSnapshot() async {
    String? token;
    String authorizationStatus = 'unavailable';
    User? user;
    String? installationId;
    if (await firebaseReady) {
      try {
        token = await FirebaseMessaging.instance.getToken();
        final settings = await FirebaseMessaging.instance
            .getNotificationSettings();
        authorizationStatus = settings.authorizationStatus.name;
      } catch (_) {
        token = null;
      }
      user = FirebaseAuth.instance.currentUser;
      installationId = await _safeInstallationId();
    }
    String? androidNotificationsEnabled;
    try {
      final plugin = _initialized
          ? _localPlugin
          : FlutterLocalNotificationsPlugin();
      final enabled = await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled();
      androidNotificationsEnabled = enabled?.toString();
    } catch (_) {
      androidNotificationsEnabled = null;
    }
    return {
      'fcmToken': token,
      'uid': user?.uid,
      'email': user?.email,
      'installationId': installationId,
      'loggedIn': (user != null).toString(),
      'authorizationStatus': authorizationStatus,
      'androidNotificationsEnabled': androidNotificationsEnabled,
    };
  }

  Future<void> dispose() async {
    await _authSub?.cancel();
    await _tokenRefreshSub?.cancel();
  }
}
