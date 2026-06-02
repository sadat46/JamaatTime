import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/services/prayer_aux_calculator.dart';

void main() {
  final calc = PrayerAuxCalculator.instance;

  group('getMaghribOffset', () {
    test('returns cantonment-specific offsets for known cities', () {
      expect(calc.getMaghribOffset('Savar Cantt'), 13);
      expect(calc.getMaghribOffset('Rangpur Cantt'), 10);
    });

    test('returns the default offset for unknown cities', () {
      expect(calc.getMaghribOffset('Nowhere'), 7);
    });

    test('returns the Local Mosque offset (+10) for a null city', () {
      expect(calc.getMaghribOffset(null), 10);
    });
  });

  group('calculateMaghribJamaatTime', () {
    test('applies the city offset when a city is given', () {
      final maghrib = DateTime(2026, 6, 2, 18, 30);
      expect(
        calc.calculateMaghribJamaatTime(
          maghribPrayerTime: maghrib,
          selectedCity: 'Savar Cantt',
        ),
        '18:43', // +13
      );
    });

    test('Local Mosque mode (null city) computes via the +10 offset', () {
      final maghrib = DateTime(2026, 6, 2, 18, 30);
      expect(
        calc.calculateMaghribJamaatTime(
          maghribPrayerTime: maghrib,
          selectedCity: null,
        ),
        '18:40', // +10 Local Mosque
      );
    });

    test('returns "-" only when the prayer time itself is null', () {
      expect(
        calc.calculateMaghribJamaatTime(
          maghribPrayerTime: null,
          selectedCity: null,
        ),
        '-',
      );
    });
  });
}
