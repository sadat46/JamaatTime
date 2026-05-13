import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/feature_flags.dart';
import '../../../features/notice_board/presentation/notice_board_screen.dart';
import '../../../features/notice_board/presentation/notice_detail_screen.dart';

class FcmDeepLinkRouter {
  FcmDeepLinkRouter(this._navigatorKey);

  static const String _pendingKey = 'notice_board.pending_fcm_route.v1';
  static const List<String> _allowedPrefixes = [
    '/home',
    '/notice-board',
    '/notice',
    '/settings',
    '/admin/jamaat',
    '/calendar',
    '/profile',
    '/ebadat',
  ];

  final GlobalKey<NavigatorState> _navigatorKey;
  String? _lastNotifId;
  DateTime? _lastTapAt;
  String? _activeNoticeId;

  Future<void> restorePendingIntent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    if (raw == null || raw.isEmpty) return;
    await handlePayload(raw);
  }

  Future<void> handlePayload(String? payload) async {
    if (payload == null || payload.trim().isEmpty) return;
    final intent = _RouteIntent.fromPayload(payload);
    await _routeWhenReady(intent);
  }

  Future<void> handleRemoteMessageData(Map<String, dynamic> data) async {
    final payload = data['payload'];
    if (payload is String && payload.trim().isNotEmpty) {
      await handlePayload(payload);
      return;
    }
    await _routeWhenReady(
      _RouteIntent(
        notifId: (data['notifId'] ?? data['notification_id'])?.toString(),
        deepLink: data['deepLink']?.toString(),
        type: data['type']?.toString(),
        priority: data['priority']?.toString(),
        schemaVersion: int.tryParse(data['schemaVersion']?.toString() ?? ''),
      ),
    );
  }

  Future<void> _routeWhenReady(_RouteIntent intent) async {
    if (intent.isEmpty) return;
    if (_isDuplicateTap(intent)) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingKey, intent.toPayload());
    final nav = _navigatorKey.currentState;
    if (nav == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        restorePendingIntent();
      });
      return;
    }

    await prefs.remove(_pendingKey);
    if (!kNoticeBoardEnabled) {
      nav.popUntil((route) => route.isFirst);
      return;
    }

    final notifId = intent.notifId;
    if (notifId != null && notifId.isNotEmpty) {
      await _pushNoticeDetail(nav, notifId);
      return;
    }

    final deepLink = intent.deepLink;
    if (deepLink == null || deepLink.isEmpty) {
      await _pushNoticeBoard(nav);
      return;
    }
    if (!_isAllowedDeepLink(deepLink)) {
      await _pushNoticeBoard(nav, message: 'Unsupported notification link.');
      return;
    }
    if (deepLink == '/home' || deepLink.startsWith('/home?')) {
      nav.popUntil((route) => route.isFirst);
      return;
    }
    if (deepLink == '/notice-board') {
      await _pushNoticeBoard(nav);
      return;
    }
    await _pushNoticeBoard(
      nav,
      message: 'Open the related page from the notice.',
    );
  }

  bool _isDuplicateTap(_RouteIntent intent) {
    final notifId = intent.notifId;
    if (notifId == null || notifId.isEmpty) return false;
    final now = DateTime.now();
    final lastTapAt = _lastTapAt;
    if (_lastNotifId == notifId &&
        lastTapAt != null &&
        now.difference(lastTapAt) < const Duration(seconds: 2)) {
      return true;
    }
    _lastNotifId = notifId;
    _lastTapAt = now;
    return false;
  }

  bool _isAllowedDeepLink(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.hasScheme || uri.host.isNotEmpty) return false;
    return _allowedPrefixes.any(
      (prefix) => uri.path == prefix || uri.path.startsWith('$prefix/'),
    );
  }

  Future<void> _pushNoticeDetail(NavigatorState nav, String notifId) async {
    if (_activeNoticeId == notifId) return;
    _activeNoticeId = notifId;
    try {
      await nav.push(
        MaterialPageRoute<void>(
          builder: (_) => NoticeDetailScreen(notifId: notifId),
        ),
      );
    } finally {
      if (_activeNoticeId == notifId) _activeNoticeId = null;
    }
  }

  Future<void> _pushNoticeBoard(NavigatorState nav, {String? message}) async {
    if (message != null && nav.context.mounted) {
      ScaffoldMessenger.of(
        nav.context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
    await nav.push(
      MaterialPageRoute<void>(builder: (_) => const NoticeBoardScreen()),
    );
  }
}

class _RouteIntent {
  const _RouteIntent({
    this.notifId,
    this.deepLink,
    this.type,
    this.priority,
    this.schemaVersion,
  });

  final String? notifId;
  final String? deepLink;
  final String? type;
  final String? priority;
  final int? schemaVersion;

  bool get isEmpty =>
      (notifId == null || notifId!.isEmpty) &&
      (deepLink == null || deepLink!.isEmpty);

  factory _RouteIntent.fromPayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        return _RouteIntent(
          notifId: decoded['notifId']?.toString(),
          deepLink: decoded['deepLink']?.toString(),
          type: decoded['type']?.toString(),
          priority: decoded['priority']?.toString(),
          schemaVersion: int.tryParse(
            decoded['schemaVersion']?.toString() ?? '',
          ),
        );
      }
    } catch (_) {
      // Legacy payloads are plain deep-link strings.
    }
    return _RouteIntent(deepLink: payload);
  }

  String toPayload() {
    return jsonEncode({
      'notifId': notifId,
      'deepLink': deepLink,
      'type': type,
      'priority': priority,
      'schemaVersion': schemaVersion,
    });
  }
}
