import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/services/notifications/reminders/jamaat_schedule_cache.dart';
import 'package:jamaat_time/services/notifications/reminders/jamaat_schedule_cache_writer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await JamaatScheduleCache.instance.clear();
  });

  test('write then readFor round-trips the times map', () async {
    final date = DateTime(2026, 5, 11);
    await JamaatScheduleCache.instance.write(
      date: date,
      times: {
        'fajr': '04:50',
        'dhuhr': '13:15',
        'asr': '16:35',
        'maghrib': '18:45',
        'isha': '20:30',
      },
    );

    final read = await JamaatScheduleCache.instance.readFor(date);

    expect(read, {
      'fajr': '04:50',
      'dhuhr': '13:15',
      'asr': '16:35',
      'maghrib': '18:45',
      'isha': '20:30',
    });
  });

  test('readFor returns null for missing dates', () async {
    final read = await JamaatScheduleCache.instance.readFor(
      DateTime(2099, 1, 1),
    );
    expect(read, isNull);
  });

  test('multiple dates coexist independently', () async {
    final today = DateTime(2026, 5, 11);
    final tomorrow = DateTime(2026, 5, 12);
    await JamaatScheduleCache.instance.write(
      date: today,
      times: {'fajr': '04:50'},
    );
    await JamaatScheduleCache.instance.write(
      date: tomorrow,
      times: {'fajr': '04:51'},
    );

    expect(await JamaatScheduleCache.instance.readFor(today), {
      'fajr': '04:50',
    });
    expect(await JamaatScheduleCache.instance.readFor(tomorrow), {
      'fajr': '04:51',
    });
  });

  test('pruneOlderThan deletes entries strictly older than cutoff', () async {
    await JamaatScheduleCache.instance.write(
      date: DateTime(2026, 5, 9),
      times: {'fajr': '04:48'},
    );
    await JamaatScheduleCache.instance.write(
      date: DateTime(2026, 5, 10),
      times: {'fajr': '04:49'},
    );
    await JamaatScheduleCache.instance.write(
      date: DateTime(2026, 5, 11),
      times: {'fajr': '04:50'},
    );

    await JamaatScheduleCache.instance.pruneOlderThan(DateTime(2026, 5, 11));

    expect(
      await JamaatScheduleCache.instance.readFor(DateTime(2026, 5, 9)),
      isNull,
    );
    expect(
      await JamaatScheduleCache.instance.readFor(DateTime(2026, 5, 10)),
      isNull,
    );
    expect(await JamaatScheduleCache.instance.readFor(DateTime(2026, 5, 11)), {
      'fajr': '04:50',
    });
  });

  test('write overwrites the entry for the same date', () async {
    final date = DateTime(2026, 5, 11);
    await JamaatScheduleCache.instance.write(
      date: date,
      times: {'fajr': '04:50'},
    );
    await JamaatScheduleCache.instance.write(
      date: date,
      times: {'fajr': '04:55', 'dhuhr': '13:15'},
    );

    expect(await JamaatScheduleCache.instance.readFor(date), {
      'fajr': '04:55',
      'dhuhr': '13:15',
    });
  });

  test('writer filters empty values and stringifies valid values', () async {
    final date = DateTime(2026, 5, 11);
    final wrote = await JamaatScheduleCacheWriter().writeForDate(
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
    expect(await JamaatScheduleCache.instance.readFor(date), {
      'fajr': '04:50',
      'isha': '2030',
    });
  });

  test('writer skips empty payloads', () async {
    final date = DateTime(2026, 5, 11);
    final wrote = await JamaatScheduleCacheWriter().writeForDate(
      date: date,
      jamaatTimes: {'fajr': '-', 'dhuhr': ''},
    );

    expect(wrote, isFalse);
    expect(await JamaatScheduleCache.instance.readFor(date), isNull);
  });
}
