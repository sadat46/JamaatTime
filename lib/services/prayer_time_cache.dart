import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PrayerTimeCacheKey {
  const PrayerTimeCacheKey(this.values);

  final Map<String, String> values;

  Map<String, dynamic> toJson() => values;

  bool matches(PrayerTimeCacheKey other) {
    if (values.length != other.values.length) {
      return false;
    }
    for (final entry in values.entries) {
      if (other.values[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  static PrayerTimeCacheKey fromJson(Object? value) {
    if (value is! Map) {
      return const PrayerTimeCacheKey(<String, String>{});
    }
    return PrayerTimeCacheKey(
      value.map((key, dynamic data) => MapEntry(key.toString(), '$data')),
    );
  }
}

class HomeCachedState {
  const HomeCachedState({
    required this.cacheKey,
    required this.times,
    required this.jamaatTimes,
    required this.lastJamaatUpdate,
  });

  final PrayerTimeCacheKey cacheKey;
  final Map<String, DateTime?> times;
  final Map<String, dynamic>? jamaatTimes;
  final DateTime? lastJamaatUpdate;

  Map<String, dynamic> toJson() {
    return {
      'version': 1,
      'writtenAt': DateTime.now().toUtc().toIso8601String(),
      'key': cacheKey.toJson(),
      'times': times.map(
        (key, value) => MapEntry(key, value?.toUtc().toIso8601String()),
      ),
      'jamaatTimes': jamaatTimes,
      'lastJamaatUpdate': lastJamaatUpdate?.toUtc().toIso8601String(),
    };
  }

  static HomeCachedState? fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      return null;
    }
    final rawTimes = json['times'];
    if (rawTimes is! Map) {
      return null;
    }

    final times = <String, DateTime?>{};
    for (final entry in rawTimes.entries) {
      final value = entry.value;
      times[entry.key.toString()] = value == null
          ? null
          : DateTime.tryParse(value.toString())?.toLocal();
    }

    final rawJamaatTimes = json['jamaatTimes'];
    return HomeCachedState(
      cacheKey: PrayerTimeCacheKey.fromJson(json['key']),
      times: times,
      jamaatTimes: rawJamaatTimes is Map
          ? Map<String, dynamic>.from(rawJamaatTimes)
          : null,
      lastJamaatUpdate: json['lastJamaatUpdate'] == null
          ? null
          : DateTime.tryParse(json['lastJamaatUpdate'].toString())?.toLocal(),
    );
  }
}

class PrayerTimeCache {
  static const String _prefsKey = 'home_cached_state_v1';

  Future<HomeCachedState?> read(PrayerTimeCacheKey expectedKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final state = HomeCachedState.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (state == null || !state.cacheKey.matches(expectedKey)) {
        return null;
      }
      return state;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(HomeCachedState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
  }
}
