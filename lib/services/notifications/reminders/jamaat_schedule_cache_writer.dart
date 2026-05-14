import 'dart:developer' as developer;

import 'jamaat_schedule_cache.dart';

class JamaatScheduleCacheWriter {
  JamaatScheduleCacheWriter({JamaatScheduleCache? cache})
    : _cache = cache ?? JamaatScheduleCache.instance;

  final JamaatScheduleCache _cache;

  Future<bool> writeForDate({
    required DateTime date,
    required Map<String, dynamic> jamaatTimes,
  }) async {
    final stringified = stringifyTimes(jamaatTimes);
    if (stringified.isEmpty) return false;

    try {
      await _cache.write(date: date, times: stringified);
      return true;
    } catch (e) {
      developer.log(
        'Jamaat schedule cache write error: $e',
        name: 'JamaatScheduleCacheWriter',
        error: e,
      );
      return false;
    }
  }

  static Map<String, String> stringifyTimes(Map<String, dynamic> jamaatTimes) {
    final stringified = <String, String>{};
    for (final entry in jamaatTimes.entries) {
      final value = entry.value;
      if (value == null) continue;
      final asString = value.toString();
      if (asString.isEmpty || asString == '-') continue;
      stringified[entry.key] = asString;
    }
    return stringified;
  }
}
