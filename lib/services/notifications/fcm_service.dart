import 'dart:async';

import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'broadcast_channel.dart';
import 'fcm_background_handler.dart';
import 'fcm_deep_link_router.dart';
import 'fcm_foreground_renderer.dart';
import 'fcm_token_repository.dart';

// Facade for the FCM receive layer. Runs on app start, BEFORE any auth gate,
// so guest devices subscribe to `all_users` and register in
// device_tokens/{installationId} without ever signing in.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();
  factory FcmService() => instance;

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
    _repo = FcmTokenRepository();
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

    await _localPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(broadcastAndroidChannel);
    await _router?.restorePendingIntent();

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

    try {
      await messaging.requestPermission(alert: true, badge: true, sound: true);
    } catch (_) {
      // Android notification permission can be denied; FCM receive setup remains valid.
    }

    try {
      await messaging.subscribeToTopic('all_users');
    } catch (_) {
      // Topic subscription can fail transiently; a later call will retry.
    }

    try {
      final token = await messaging.getToken();
      await _persistToken(token: token, locale: locale);
    } catch (_) {
      // Do not let Firestore/App Check/network token writes disable FCM display.
    }

    _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) {
      _persistToken(token: newToken, locale: locale).catchError((_) {});
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
    try {
      token = await FirebaseMessaging.instance.getToken();
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      authorizationStatus = settings.authorizationStatus.name;
    } catch (_) {
      token = null;
    }
    final user = FirebaseAuth.instance.currentUser;
    final installationId = await _safeInstallationId();
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
