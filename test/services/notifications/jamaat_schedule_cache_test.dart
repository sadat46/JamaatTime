import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/services/notifications/reminders/jamaat_schedule_cache.dart';
import 'package:jamaat_time/services/notifications/reminders/jamaat_schedule_cache_writer.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _scopeA = 'serverMosque:Savar Cantt';
const _scopeB = 'serverMosque:Dhaka Cantt';
const _scopeLocal = 'local:';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await JamaatScheduleCache.instance.clear();
  });

  test('write then readFor round-trips the times map within a scope',
      () async {
    final date = DateTime(2026, 5, 11);
    await JamaatScheduleCache.instance.write(
      scope: _scopeA,
      date: date,
      times: {
        'fajr': '04:50',
        'dhuhr': '13:15',
        'asr': '16:35',
        'maghrib': '18:45',
        'isha': '20:30',
      },
    );

    final read = await JamaatScheduleCache.instance
        .readFor(scope: _scopeA, date: date);

    expect(read, {
      'fajr': '04:50',
      'dhuhr': '13:15',
      'asr': '16:35',
      'maghrib': '18:45',
      'isha': '20:30',
    });
  });

  test('readFor returns null for missing dates', () async {
    final read = await JamaatScheduleCache.instance
        .readFor(scope: _scopeA, date: DateTime(2099, 1, 1));
    expect(read, isNull);
  });

  test('entries under one scope are invisible to another scope', () async {
    final date = DateTime(2026, 5, 11);
    await JamaatScheduleCache.instance.write(
      scope: _scopeA,
      date: date,
      times: {'fajr': '04:50'},
    );

    expect(
      await JamaatScheduleCache.instance.readFor(scope: _scopeB, date: date),
      isNull,
    );
    expect(
      await JamaatScheduleCache.instance
          .readFor(scope: _scopeLocal, date: date),
      isNull,
    );
    expect(
      await JamaatScheduleCache.instance.readFor(scope: _scopeA, date: date),
      {'fajr': '04:50'},
    );
  });

  test('clearOtherScopes drops every entry except the current scope', () async {
    final date = DateTime(2026, 5, 11);
    await JamaatScheduleCache.instance.write(
      scope: _scopeA,
      date: date,
      times: {'fajr': '04:50'},
    );
    await JamaatScheduleCache.instance.write(
      scope: _scopeB,
      date: date,
      times: {'fajr': '04:55'},
    );
    await JamaatScheduleCache.instance.write(
      scope: _scopeLocal,
      date: date,
      times: {'fajr': '05:00'},
    );

    await JamaatScheduleCache.instance.clearOtherScopes(_scopeA);

    expect(
      await JamaatScheduleCache.instance.readFor(scope: _scopeA, date: date),
      {'fajr': '04:50'},
    );
    expect(
      await JamaatScheduleCache.instance.readFor(scope: _scopeB, date: date),
      isNull,
    );
    expect(
      await JamaatScheduleCache.instance
          .readFor(scope: _scopeLocal, date: date),
      isNull,
    );
  });

  test('pruneOlderThan deletes entries strictly older than cutoff', () async {
    await JamaatScheduleCache.instance.write(
      scope: _scopeA,
      date: DateTime(2026, 5, 9),
      times: {'fajr': '04:48'},
    );
    await JamaatScheduleCache.instance.write(
      scope: _scopeA,
      date: DateTime(2026, 5, 10),
      times: {'fajr': '04:49'},
    );
    await JamaatScheduleCache.instance.write(
      scope: _scopeA,
      date: DateTime(2026, 5, 11),
      times: {'fajr': '04:50'},
    );

    await JamaatScheduleCache.instance.pruneOlderThan(DateTime(2026, 5, 11));

    expect(
      await JamaatScheduleCache.instance
          .readFor(scope: _scopeA, date: DateTime(2026, 5, 9)),
      isNull,
    );
    expect(
      await JamaatScheduleCache.instance
          .readFor(scope: _scopeA, date: DateTime(2026, 5, 10)),
      isNull,
    );
    expect(
      await JamaatScheduleCache.instance
          .readFor(scope: _scopeA, date: DateTime(2026, 5, 11)),
      {'fajr': '04:50'},
    );
  });

  test('write overwrites the entry for the same scope + date', () async {
    final date = DateTime(2026, 5, 11);
    await JamaatScheduleCache.instance.write(
      scope: _scopeA,
      date: date,
      times: {'fajr': '04:50'},
    );
    await JamaatScheduleCache.instance.write(
      scope: _scopeA,
      date: date,
      times: {'fajr': '04:55', 'dhuhr': '13:15'},
    );

    expect(
      await JamaatScheduleCache.instance.readFor(scope: _scopeA, date: date),
      {'fajr': '04:55', 'dhuhr': '13:15'},
    );
  });

  test('writer filters empty values and stringifies valid values', () async {
    final date = DateTime(2026, 5, 11);
    final wrote = await JamaatScheduleCacheWriter().writeForDate(
      scope: _scopeA,
      date: date,
      jamaatTimes: {
        'fajr': '04:50',
        'dhuhr': '',
        'asr': '-',
        'maghrib': null,
        'isha': 2030,
      },
    );

    expect(wrote, isTrue);
    expect(
      await JamaatScheduleCache.instance.readFor(scope: _scopeA, date: date),
      {'fajr': '04:50', 'isha': '2030'},
    );
  });

  test('writer skips empty payloads', () async {
    final date = DateTime(2026, 5, 11);
    final wrote = await JamaatScheduleCacheWriter().writeForDate(
      scope: _scopeA,
      date: date,
      jamaatTimes: {'fajr': '-', 'dhuhr': ''},
    );

    expect(wrote, isFalse);
    expect(
      await JamaatScheduleCache.instance.readFor(scope: _scopeA, date: date),
      isNull,
    );
  });

  test('writer with a null scope is a no-op', () async {
    final date = DateTime(2026, 5, 11);
    final wrote = await JamaatScheduleCacheWriter().writeForDate(
      scope: null,
      date: date,
      jamaatTimes: {'fajr': '04:50'},
    );
    expect(wrote, isFalse);
    expect(
      await JamaatScheduleCache.instance.readFor(scope: _scopeA, date: date),
      isNull,
    );
  });
}
