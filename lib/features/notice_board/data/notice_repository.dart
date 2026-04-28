import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notice_errors.dart';
import 'notice_model.dart';

class NoticePage {
  const NoticePage({
    required this.items,
    required this.cursor,
    required this.fromCache,
  });

  final List<NoticeModel> items;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool fromCache;
}

class NoticeRepository {
  NoticeRepository({
    FirebaseFirestore? firestore,
    SharedPreferences? preferences,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _preferences = preferences;

  static const int defaultPageSize = 20;
  static const int _cacheLimit = 50;
  static const Duration _detailTtl = Duration(seconds: 30);
  static const String _cacheKey = 'notice_board.cache.v1';

  final FirebaseFirestore _firestore;
  SharedPreferences? _preferences;
  final Map<String, _MemoryCacheEntry> _detailCache = {};
  final Map<String, Future<NoticeModel>> _singleFlight = {};

  Query<Map<String, dynamic>> _basePublicQuery() {
    return _firestore
        .collection('notifications')
        .where('publicVisible', isEqualTo: true)
        .where('status', whereIn: const ['sent', 'fallback_text']);
  }

  Future<NoticePage> fetchPage({
    DocumentSnapshot<Map<String, dynamic>>? cursor,
    int limit = defaultPageSize,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _basePublicQuery()
          .orderBy('pinned', descending: true)
          .orderBy('publishedAt', descending: true)
          .limit(limit);
      if (cursor != null) query = query.startAfterDocument(cursor);
      final snap = await query.get();
      final items = snap.docs
          .map(NoticeModel.fromFirestore)
          .where((notice) => notice.isReadablePublic || notice.unsupported)
          .toList(growable: false);
      if (cursor == null && items.isNotEmpty) {
        await _writeColdCache(items);
      }
      return NoticePage(
        items: items,
        cursor: snap.docs.isEmpty ? null : snap.docs.last,
        fromCache: false,
      );
    } on FirebaseException catch (e) {
      if (cursor == null) {
        final cached = await _readColdCache();
        if (cached.isNotEmpty) {
          return NoticePage(items: cached, cursor: null, fromCache: true);
        }
      }
      if (e.code == 'permission-denied') throw const NoticePermissionDenied();
      throw NoticeNetwork(e.message ?? e.code);
    } catch (e) {
      if (cursor == null) {
        final cached = await _readColdCache();
        if (cached.isNotEmpty) {
          return NoticePage(items: cached, cursor: null, fromCache: true);
        }
      }
      throw NoticeNetwork(e.toString());
    }
  }

  Future<NoticeModel> getById(String notifId) {
    final cached = _detailCache[notifId];
    if (cached != null && !cached.isExpired) return Future.value(cached.notice);
    final inFlight = _singleFlight[notifId];
    if (inFlight != null) return inFlight;

    final future = _getByIdUncached(notifId);
    _singleFlight[notifId] = future;
    future.whenComplete(() => _singleFlight.remove(notifId));
    return future;
  }

  Future<NoticeModel> _getByIdUncached(String notifId) async {
    try {
      final doc = await _firestore
          .collection('notifications')
          .doc(notifId)
          .get();
      if (!doc.exists) throw const NoticeNotFound();
      final notice = NoticeModel.fromFirestore(doc);
      if (!notice.isReadablePublic && !notice.unsupported) {
        throw const NoticeHidden();
      }
      _detailCache[notifId] = _MemoryCacheEntry(
        notice: notice,
        expiresAt: DateTime.now().add(_detailTtl),
      );
      return notice;
    } on NoticeException {
      rethrow;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw const NoticePermissionDenied();
      throw NoticeNetwork(e.message ?? e.code);
    } catch (e) {
      throw NoticeNetwork(e.toString());
    }
  }

  Stream<NoticeModel?> watchLatest() async* {
    DateTime lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
    await for (final snap
        in _basePublicQuery()
            .orderBy('publishedAt', descending: true)
            .limit(1)
            .snapshots()) {
      final now = DateTime.now();
      final delay = const Duration(seconds: 1) - now.difference(lastEmit);
      if (!delay.isNegative) await Future<void>.delayed(delay);
      lastEmit = DateTime.now();
      final notices = snap.docs
          .map(NoticeModel.fromFirestore)
          .where((notice) => notice.isReadablePublic || notice.unsupported)
          .toList(growable: false);
      yield notices.isEmpty ? null : notices.first;
    }
  }

  Future<void> _writeColdCache(List<NoticeModel> notices) async {
    final prefs = await _prefs();
    final payload = notices
        .take(_cacheLimit)
        .map((notice) => notice.toCacheJson())
        .toList(growable: false);
    await prefs.setString(_cacheKey, jsonEncode(payload));
  }

  Future<List<NoticeModel>> _readColdCache() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => NoticeModel.fromMap(
              item['notifId']?.toString() ?? '',
              Map<String, dynamic>.from(item),
            ),
          )
          .where((notice) => notice.id.isNotEmpty)
          .where((notice) => notice.isReadablePublic || notice.unsupported)
          .take(_cacheLimit)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }
}

class _MemoryCacheEntry {
  const _MemoryCacheEntry({required this.notice, required this.expiresAt});

  final NoticeModel notice;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
