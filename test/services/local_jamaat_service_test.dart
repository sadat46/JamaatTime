import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/services/local_jamaat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sampleCsv = '''Date,Fajr,Dhuhr,Asr,Isha
1/1/2026,5:50,13:15,16:25,19:45
13-01-2026,5:50,13:15,16:25,19:45
24-05-2026,4:50,13:15,16:35,8:30 PM
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  LocalJamaatService buildService(String csv) {
    return LocalJamaatService.forTesting(
      assetLoader: () async => csv,
    );
  }

  group('CSV parsing', () {
    test('parses slash-formatted date (D/M/YYYY)', () async {
      final service = buildService(_sampleCsv);
      final times = await service.getCsvDefaultForDate(DateTime(2026, 1, 1));
      expect(times, isNotNull);
      expect(times!.fajr, '05:50');
      expect(times.dhuhr, '13:15');
      expect(times.asr, '16:25');
      expect(times.isha, '19:45');
    });

    test('parses dash-formatted date (DD-MM-YYYY)', () async {
      final service = buildService(_sampleCsv);
      final times = await service.getCsvDefaultForDate(DateTime(2026, 1, 13));
      expect(times, isNotNull);
      expect(times!.fajr, '05:50');
    });

    test('accepts 12-hour AM/PM input in CSV cells', () async {
      final service = buildService(_sampleCsv);
      final times = await service.getCsvDefaultForDate(DateTime(2026, 5, 24));
      expect(times, isNotNull);
      expect(times!.isha, '20:30',
          reason: '8:30 PM should normalize to 24-hour 20:30');
    });

    test('returns null for dates not in the CSV', () async {
      final service = buildService(_sampleCsv);
      final times = await service.getCsvDefaultForDate(DateTime(2099, 1, 1));
      expect(times, isNull);
    });
  });

  group('Effective time resolution', () {
    test('falls back to CSV default when no override exists', () async {
      final service = buildService(_sampleCsv);
      final times =
          await service.getEffectiveTimesForDate(DateTime(2026, 1, 1));
      expect(times!.fajr, '05:50');
    });

    test('override wins over CSV default for the same date', () async {
      final service = buildService(_sampleCsv);
      await service.setOverrideForDate(
        DateTime(2026, 1, 1),
        const LocalJamaatTimes(
          fajr: '06:00',
          dhuhr: '13:30',
          asr: '17:00',
          isha: '20:00',
        ),
      );
      final times =
          await service.getEffectiveTimesForDate(DateTime(2026, 1, 1));
      expect(times!.fajr, '06:00');
      expect(times.dhuhr, '13:30');
      expect(times.asr, '17:00');
      expect(times.isha, '20:00');
    });

    test('clearing an override restores the CSV default', () async {
      final service = buildService(_sampleCsv);
      await service.setOverrideForDate(
        DateTime(2026, 1, 1),
        const LocalJamaatTimes(
          fajr: '06:00',
          dhuhr: '13:30',
          asr: '17:00',
          isha: '20:00',
        ),
      );
      await service.clearOverrideForDate(DateTime(2026, 1, 1));
      final times =
          await service.getEffectiveTimesForDate(DateTime(2026, 1, 1));
      expect(times!.fajr, '05:50');
    });

    test('override on a date without a CSV default still resolves', () async {
      final service = buildService(_sampleCsv);
      await service.setOverrideForDate(
        DateTime(2099, 6, 15),
        const LocalJamaatTimes(
          fajr: '04:30',
          dhuhr: '12:30',
          asr: '15:30',
          isha: '20:30',
        ),
      );
      final times =
          await service.getEffectiveTimesForDate(DateTime(2099, 6, 15));
      expect(times!.fajr, '04:30');
    });
  });

  group('Time input parser', () {
    test('accepts 24-hour HH:mm and H:mm', () {
      expect(LocalJamaatService.parseTimeInput('05:50'), '05:50');
      expect(LocalJamaatService.parseTimeInput('5:50'), '05:50');
      expect(LocalJamaatService.parseTimeInput('13:15'), '13:15');
      expect(LocalJamaatService.parseTimeInput('23:59'), '23:59');
    });

    test('accepts 12-hour with AM/PM markers in either case', () {
      expect(LocalJamaatService.parseTimeInput('5:50 AM'), '05:50');
      expect(LocalJamaatService.parseTimeInput('5:50 am'), '05:50');
      expect(LocalJamaatService.parseTimeInput('1:15 PM'), '13:15');
      expect(LocalJamaatService.parseTimeInput('12:00 AM'), '00:00');
      expect(LocalJamaatService.parseTimeInput('12:00 PM'), '12:00');
    });

    test('rejects out-of-range and garbage inputs', () {
      expect(LocalJamaatService.parseTimeInput(''), isNull);
      expect(LocalJamaatService.parseTimeInput('24:00'), isNull);
      expect(LocalJamaatService.parseTimeInput('12:60'), isNull);
      expect(LocalJamaatService.parseTimeInput('13:15 PM'), isNull,
          reason: '12-hour marker with 13 is invalid');
      expect(LocalJamaatService.parseTimeInput('abc'), isNull);
    });
  });
}
