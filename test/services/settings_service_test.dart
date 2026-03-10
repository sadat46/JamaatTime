import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bangladesh hijri offset defaults to -1 and can be updated', () async {
    SharedPreferences.setMockInitialValues({});
    final settingsService = SettingsService();

    expect(
      await settingsService.getBangladeshHijriOffsetDays(),
      SettingsService.defaultBangladeshHijriOffsetDays,
    );

    await settingsService.setBangladeshHijriOffsetDays(2);
    expect(await settingsService.getBangladeshHijriOffsetDays(), 2);
  });
}
