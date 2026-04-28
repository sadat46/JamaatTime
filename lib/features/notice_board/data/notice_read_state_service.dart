import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'notice_model.dart';

class NoticeReadStateService {
  NoticeReadStateService({SharedPreferences? preferences})
    : _preferences = preferences;

  static const int _schemaVersion = 1;
  static const int _maxReadIds = 500;
  static const String _schemaKey = 'notice_board.read_state.schema';
  static const String _latestSeenKey = 'notice_board.read_state.latest_seen_ms';
  static const String _readIdsKey = 'notice_board.read_state.read_ids';

  SharedPreferences? _preferences;

  Future<DateTime?> latestSeenPublishedAt() async {
    await _migrateIfNeeded();
    final ms = (await _prefs()).getInt(_latestSeenKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<bool> hasUnreadLatest(NoticeModel? latest) async {
    if (latest == null) return false;
    if (await isRead(latest.id)) return false;
    final latestPublished = latest.publishedAt ?? latest.createdAt;
    final seen = await latestSeenPublishedAt();
    if (latestPublished == null) return false;
    return seen == null || latestPublished.isAfter(seen);
  }

  Future<void> markAllSeen(Iterable<NoticeModel> notices) async {
    await _migrateIfNeeded();
    DateTime? newest;
    for (final notice in notices) {
      final published = notice.publishedAt ?? notice.createdAt;
      if (published != null && (newest == null || published.isAfter(newest))) {
        newest = published;
      }
      await markRead(notice.id);
    }
    if (newest != null) {
      await (await _prefs()).setInt(
        _latestSeenKey,
        newest.millisecondsSinceEpoch,
      );
    }
  }

  Future<void> markRead(String notifId) async {
    await _migrateIfNeeded();
    final map = await _readIds();
    map[notifId] = DateTime.now().millisecondsSinceEpoch;
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final trimmed = Map<String, int>.fromEntries(sorted.take(_maxReadIds));
    await (await _prefs()).setString(_readIdsKey, jsonEncode(trimmed));
  }

  Future<bool> isRead(String notifId) async {
    await _migrateIfNeeded();
    return (await _readIds()).containsKey(notifId);
  }

  Future<Map<String, int>> _readIds() async {
    final raw = (await _prefs()).getString(_readIdsKey);
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, int>{};
      return decoded.map(
        (key, dynamic value) =>
            MapEntry(key.toString(), (value as num).toInt()),
      );
    } catch (_) {
      return <String, int>{};
    }
  }

  Future<void> _migrateIfNeeded() async {
    final prefs = await _prefs();
    final current = prefs.getInt(_schemaKey);
    if (current == _schemaVersion) return;
    await prefs.setInt(_schemaKey, _schemaVersion);
    if (current == null) return;
    await prefs.remove(_readIdsKey);
    await prefs.remove(_latestSeenKey);
  }

  Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }
}
