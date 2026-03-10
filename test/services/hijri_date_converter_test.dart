import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/services/hijri_date_converter.dart';

void main() {
  group('HijriDateConverter', () {
    test('formats expected Ramadan day for Bangladesh offset scenario', () {
      final date = DateTime(2026, 3, 10, 1, 30);

      final withoutOffset = HijriDateConverter.formatHijriDate(
        date,
        dayOffset: 0,
      );
      final withBangladeshOffset = HijriDateConverter.formatHijriDate(
        date,
        dayOffset: -1,
      );

      expect(withoutOffset, '21 Ramadan 1447 AH');
      expect(withBangladeshOffset, '20 Ramadan 1447 AH');
    });

    test('detects Ramadan month from converted Hijri date', () {
      expect(
        HijriDateConverter.isRamadan(DateTime(2026, 3, 10), dayOffset: -1),
        isTrue,
      );
      expect(
        HijriDateConverter.isRamadan(DateTime(2026, 1, 1), dayOffset: -1),
        isFalse,
      );
    });
  });
}
