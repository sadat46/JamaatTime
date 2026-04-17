import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  test('bangladesh hijri offset defaults to -1 and can be updated', () async {
    final settingsService = SettingsService();

    expect(
      await settingsService.getBangladeshHijriOffsetDays(),
      SettingsService.defaultBangladeshHijriOffsetDays,
    );

    await settingsService.setBangladeshHijriOffsetDays(2);
    expect(await settingsService.getBangladeshHijriOffsetDays(), 2);
  });

  test('notification sound defaults to mode 3 and migrates once', () async {
    final settingsService = SettingsService();

    expect(await settingsService.getNotificationSoundMode(), 3);
    expect(await settingsService.getPrayerNotificationSoundMode(), 3);
    expect(await settingsService.getJamaatNotificationSoundMode(), 3);

    await settingsService.setNotificationSoundMode(2);
    await settingsService.setPrayerNotificationSoundMode(1);
    await settingsService.setJamaatNotificationSoundMode(4);

    await settingsService.migrateNotificationSoundDefaultsToCustom2();

    expect(await settingsService.getNotificationSoundMode(), 3);
    expect(await settingsService.getPrayerNotificationSoundMode(), 3);
    expect(await settingsService.getJamaatNotificationSoundMode(), 3);

    await settingsService.setPrayerNotificationSoundMode(1);
    await settingsService.setJamaatNotificationSoundMode(4);
    await settingsService.migrateNotificationSoundDefaultsToCustom2();

    expect(await settingsService.getPrayerNotificationSoundMode(), 1);
    expect(await settingsService.getJamaatNotificationSoundMode(), 4);
  });
}
