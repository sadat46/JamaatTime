import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/models/jamaat_location.dart';
import 'package:jamaat_time/models/location_config.dart';
import 'package:jamaat_time/models/prayer_location.dart';
import 'package:jamaat_time/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('SettingsService prayer/jamaat location split', () {
    test('returns null and empty for a fresh install', () async {
      final settings = SettingsService();
      expect(await settings.getPrayerLocation(), isNull);
      final jamaat = await settings.getJamaatLocation();
      expect(jamaat.source, JamaatSource.none);
      expect(jamaat.city, isNull);
    });

    test('persists and reloads a GPS PrayerLocation', () async {
      final settings = SettingsService();
      final location = PrayerLocation(
        mode: PrayerLocationMode.gps,
        latitude: 23.42,
        longitude: 91.55,
        locationName: 'Jhenaidah',
        timezone: 'Asia/Dhaka',
        country: Country.bangladesh,
        calculationMethodType: PrayerCalculationMethodType.muslimWorldLeague,
      );
      await settings.setPrayerLocation(location);

      final loaded = await settings.getPrayerLocation();
      expect(loaded, isNotNull);
      expect(loaded!.mode, PrayerLocationMode.gps);
      expect(loaded.latitude, 23.42);
      expect(loaded.longitude, 91.55);
      expect(loaded.locationName, 'Jhenaidah');
      expect(loaded.country, Country.bangladesh);
      expect(loaded.timezone, 'Asia/Dhaka');
    });

    test('persists and reloads a server-mosque JamaatLocation', () async {
      final settings = SettingsService();
      await settings.setJamaatLocation(const JamaatLocation(
        source: JamaatSource.serverMosque,
        city: 'Savar Cantt',
      ));

      final loaded = await settings.getJamaatLocation();
      expect(loaded.source, JamaatSource.serverMosque);
      expect(loaded.city, 'Savar Cantt');
      expect(loaded.hasServerMosque, isTrue);
    });

  });
}
