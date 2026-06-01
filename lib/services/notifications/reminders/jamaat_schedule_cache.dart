import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

/// Persistent cache of jamaat times keyed by Jamaat scope + date.
///
/// Phase 5 of PRAYER_LOCATION_FIX_PLAN: previously keyed by date alone, which
/// let stale times from a previous mosque/source survive across switches.
/// Storage shape v2 is a flat `{ "$scope|$YYYY-MM-DD": {...times} }` map; the
/// scope namespace isolates server-mosque, local, and per-mosque entries.
///
/// The cache remains the single source of truth for the notification
/// scheduler. The home controller writes here after every successful
/// Firestore fetch or local-resolver computation; the scheduler reads here
/// when arming alarms. The in-memory `_jamaatTimes` on the home controller
/// drives the UI only.
class JamaatScheduleCache {
  JamaatScheduleCache._();

  static final JamaatScheduleCache instance = JamaatScheduleCache._();

  static const String _storageKeyV1 = 'notif_jamaat_cache_v1';
  static const String _storageKey = 'notif_jamaat_cache_v2';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<Map<String, dynamic>> _readAll() async {
    try {
      final prefs = await _prefs;
      // Phase 5 migration: drop the date-only v1 cache on first read of v2.
      // Old entries would have leaked across source/city changes.
      if (prefs.containsKey(_storageKeyV1)) {
        await prefs.remove(_storageKeyV1);
      }
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
    if (data.isEmpty) {
      await prefs.remove(_storageKey);
      return;
    }
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  Future<void> write({
    required String scope,
    required DateTime date,
    required Map<String, String> times,
  }) async {
    final all = await _readAll();
    all[_compositeKey(scope, date)] = times;
    await _writeAll(all);
  }

  Future<Map<String, String>?> readFor({
    required String scope,
    required DateTime date,
  }) async {
    final all = await _readAll();
    final entry = all[_compositeKey(scope, date)];
    if (entry is Map) {
      return entry.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return null;
  }

  /// Drop every entry whose scope does not match [currentScope]. Called when
  /// the user switches Jamaat source or mosque so reminders never read stale
  /// data from the previous selection.
  Future<void> clearOtherScopes(String currentScope) async {
    final all = await _readAll();
    final prefix = '$currentScope|';
    final keysToRemove = all.keys.where((k) => !k.startsWith(prefix)).toList();
    if (keysToRemove.isEmpty) return;
    for (final k in keysToRemove) {
      all.remove(k);
    }
    await _writeAll(all);
  }

  Future<void> pruneOlderThan(DateTime cutoff) async {
    final all = await _readAll();
    final cutoffKey = _dateKey(cutoff);
    final keysToRemove = <String>[];
    for (final key in all.keys) {
      final parts = key.split('|');
      if (parts.length < 2) {
        keysToRemove.add(key);
        continue;
      }
      final datePart = parts.last;
      if (datePart.compareTo(cutoffKey) < 0) {
        keysToRemove.add(key);
      }
    }
    if (keysToRemove.isEmpty) return;
    for (final k in keysToRemove) {
      all.remove(k);
    }
    await _writeAll(all);
  }

  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_storageKey);
    await prefs.remove(_storageKeyV1);
  }

  static String _compositeKey(String scope, DateTime date) =>
      '$scope|${_dateKey(date)}';

  static String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
