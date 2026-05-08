import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

class NoticeModel {
  const NoticeModel({
    required this.id,
    required this.schemaVersion,
    required this.type,
    required this.category,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.imageWidth,
    required this.imageHeight,
    required this.imageBlurHash,
    required this.imageFallback,
    required this.deepLink,
    required this.locale,
    required this.localizedVariants,
    required this.status,
    required this.publicVisible,
    required this.priority,
    required this.pinned,
    required this.expiresAt,
    required this.archivedAt,
    required this.triggerSource,
    required this.audience,
    required this.createdAt,
    required this.scheduledFor,
    required this.sentAt,
    required this.publishedAt,
    required this.updatedAt,
    required this.unsupported,
  });

  final String id;
  final int schemaVersion;
  final String type;
  final String? category;
  final String title;
  final String body;
  final String? imageUrl;
  final int? imageWidth;
  final int? imageHeight;
  final String? imageBlurHash;
  final bool imageFallback;
  final String? deepLink;
  final String locale;
  final Map<String, NoticeLocalizedVariant> localizedVariants;
  final String status;
  final bool publicVisible;
  final String priority;
  final bool pinned;
  final DateTime? expiresAt;
  final DateTime? archivedAt;
  final String triggerSource;
  final String audience;
  final DateTime? createdAt;
  final DateTime? scheduledFor;
  final DateTime? sentAt;
  final DateTime? publishedAt;
  final DateTime? updatedAt;
  final bool unsupported;

  bool get isExpired =>
      expiresAt != null && !expiresAt!.isAfter(DateTime.now());

  bool get isReadablePublic =>
      publicVisible &&
      (status == 'sent' || status == 'fallback_text') &&
      !isExpired;

  String localizedTitle(Locale locale) {
    return localizedVariants[locale.languageCode]?.title ?? title;
  }

  String localizedBody(Locale locale) {
    return localizedVariants[locale.languageCode]?.body ?? body;
  }

  factory NoticeModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return NoticeModel.fromMap(doc.id, doc.data() ?? const <String, dynamic>{});
  }

  factory NoticeModel.fromMap(String id, Map<String, dynamic> data) {
    final schemaVersion = _asInt(data['schemaVersion']) ?? 0;
    if (schemaVersion > 1) {
      return NoticeModel.unsupported(id: id, schemaVersion: schemaVersion);
    }

    return NoticeModel(
      id: (data['notifId'] as String?) ?? id,
      schemaVersion: schemaVersion,
      type: (data['type'] as String?) ?? 'announcement',
      category: data['category'] as String?,
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      imageUrl: data['imageUrl'] as String?,
      imageWidth: _asInt(data['imageWidth']),
      imageHeight: _asInt(data['imageHeight']),
      imageBlurHash: data['imageBlurHash'] as String?,
      imageFallback: data['imageFallback'] == true,
      deepLink: data['deepLink'] as String?,
      locale: (data['locale'] as String?) ?? 'en',
      localizedVariants: _parseVariants(data['localizedVariants']),
      status: (data['status'] as String?) ?? 'draft',
      publicVisible: data['publicVisible'] == true,
      priority: (data['priority'] as String?) ?? 'normal',
      pinned: data['pinned'] == true,
      expiresAt: _asDate(data['expiresAt']),
      archivedAt: _asDate(data['archivedAt']),
      triggerSource: (data['triggerSource'] as String?) ?? 'manual',
      audience: (data['audience'] as String?) ?? 'guests_and_users',
      createdAt: _asDate(data['createdAt']),
      scheduledFor: _asDate(data['scheduledFor']),
      sentAt: _asDate(data['sentAt']),
      publishedAt: _asDate(data['publishedAt']),
      updatedAt: _asDate(data['updatedAt']),
      unsupported: false,
    );
  }

  factory NoticeModel.unsupported({
    required String id,
    required int schemaVersion,
  }) {
    return NoticeModel(
      id: id,
      schemaVersion: schemaVersion,
      type: 'unsupported',
      category: null,
      title: 'Update app to view this notice',
      body: 'This notice uses a newer format.',
      imageUrl: null,
      imageWidth: null,
      imageHeight: null,
      imageBlurHash: null,
      imageFallback: false,
      deepLink: null,
      locale: 'en',
      localizedVariants: const {},
      status: 'sent',
      publicVisible: true,
      priority: 'normal',
      pinned: false,
      expiresAt: null,
      archivedAt: null,
      triggerSource: 'system',
      audience: 'guests_and_users',
      createdAt: null,
      scheduledFor: null,
      sentAt: null,
      publishedAt: null,
      updatedAt: null,
      unsupported: true,
    );
  }

  Map<String, dynamic> toCacheJson() {
    return {
      'notifId': id,
      'schemaVersion': schemaVersion,
      'type': type,
      'category': category,
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'imageWidth': imageWidth,
      'imageHeight': imageHeight,
      'imageBlurHash': imageBlurHash,
      'imageFallback': imageFallback,
      'deepLink': deepLink,
      'locale': locale,
      'localizedVariants': localizedVariants.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'status': status,
      'publicVisible': publicVisible,
      'priority': priority,
      'pinned': pinned,
      'expiresAt': expiresAt?.millisecondsSinceEpoch,
      'archivedAt': archivedAt?.millisecondsSinceEpoch,
      'triggerSource': triggerSource,
      'audience': audience,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'scheduledFor': scheduledFor?.millisecondsSinceEpoch,
      'sentAt': sentAt?.millisecondsSinceEpoch,
      'publishedAt': publishedAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  static DateTime? _asDate(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  static Map<String, NoticeLocalizedVariant> _parseVariants(Object? value) {
    if (value is! Map) return const {};
    final parsed = <String, NoticeLocalizedVariant>{};
    for (final entry in value.entries) {
      if (entry.key is! String || entry.value is! Map) continue;
      parsed[entry.key as String] = NoticeLocalizedVariant.fromMap(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }
    return parsed;
  }
}

class NoticeLocalizedVariant {
  const NoticeLocalizedVariant({required this.title, required this.body});

  final String title;
  final String body;

  factory NoticeLocalizedVariant.fromMap(Map<String, dynamic> data) {
    return NoticeLocalizedVariant(
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'title': title, 'body': body};
}
