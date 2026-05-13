import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

/// Persistent cache of jamaat times keyed by `YYYY-MM-DD` date.
///
/// This cache is the single source of truth for the notification scheduler.
/// The home controller writes here after every successful Firestore fetch (or
/// local-offset computation); the scheduler reads here when arming alarms. The
/// in-memory `_jamaatTimes` on the home controller drives the UI only.
class JamaatScheduleCache {
  JamaatScheduleCache._();

  static final JamaatScheduleCache instance = JamaatScheduleCache._();

  static const String _storageKey = 'notif_jamaat_cache_v1';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<Map<String, dynamic>> _readAll() async {
    try {
      final prefs = await _prefs;
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } catch (e) {
      developer.log(
        'JamaatScheduleCache read error: $e',
        name: 'JamaatScheduleCache',
        error: e,
      );
      return <String, dynamic>{};
    }
  }

  Future<void> _writeAll(Map<String, dynamic> data) async {
    final prefs = await _prefs;
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  Future<void> write({
    required DateTime date,
    required Map<String, String> times,
  }) async {
    final all = await _readAll();
    all[_dateKey(date)] = times;
    await _writeAll(all);
  }

  Future<Map<String, String>?> readFor(DateTime date) async {
    final all = await _readAll();
    final entry = all[_dateKey(date)];
    if (entry is Map) {
      return entry.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return null;
  }

  Future<void> pruneOlderThan(DateTime cutoff) async {
    final all = await _readAll();
    final cutoffKey = _dateKey(cutoff);
    final keysToRemove = all.keys
        .where((k) => k.compareTo(cutoffKey) < 0)
        .toList();
    if (keysToRemove.isEmpty) return;
    for (final k in keysToRemove) {
      all.remove(k);
    }
    await _writeAll(all);
  }

  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_storageKey);
  }

  static String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
