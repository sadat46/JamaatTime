import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import 'broadcast_channel.dart';

// Renders FCM pushes while the app is foregrounded. Android does not
// auto-display notification payloads in foreground, so we bridge to
// flutter_local_notifications — including the BigPicture image path.
class FcmForegroundRenderer {
  FcmForegroundRenderer(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void> show(RemoteMessage message) async {
    final notif = message.notification;
    final data = message.data;
    final title = notif?.title ?? (data['title'] as String?) ?? '';
    final body = notif?.body ?? (data['body'] as String?) ?? '';
    if (title.isEmpty && body.isEmpty) return;

    final imageUrl = notif?.android?.imageUrl ?? (data['imageUrl'] as String?);
    AndroidNotificationDetails details = _plainDetails(body);

    if (imageUrl != null && imageUrl.isNotEmpty) {
      final path = await _downloadToTemp(imageUrl);
      if (path != null) {
        details = AndroidNotificationDetails(
          broadcastChannelId,
          broadcastChannelName,
          channelDescription: broadcastChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigPictureStyleInformation(
            FilePathAndroidBitmap(path),
            contentTitle: title,
            summaryText: body,
            hideExpandedLargeIcon: false,
          ),
        );
      }
    }

    final payload = jsonEncode({
      'notifId': data['notifId'] ?? data['notification_id'],
      'deepLink': data['deepLink'],
      'type': data['type'],
      'priority': data['priority'],
      'schemaVersion': data['schemaVersion'],
    });
    await _plugin.show(
      message.messageId.hashCode,
      title,
      body,
      NotificationDetails(android: details),
      payload: payload,
    );
  }

  AndroidNotificationDetails _plainDetails(String body) {
    return AndroidNotificationDetails(
      broadcastChannelId,
      broadcastChannelName,
      channelDescription: broadcastChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body),
    );
  }

  Future<String?> _downloadToTemp(String url) async {
    try {
      final uri = Uri.parse(url);
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return null;
      final dir = Directory.systemTemp;
      final file = File(
        '${dir.path}/fcm_${DateTime.now().microsecondsSinceEpoch}.img',
      );
      await file.writeAsBytes(resp.bodyBytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
