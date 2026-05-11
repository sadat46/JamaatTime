import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/core/locale_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('read() defaults to en when nothing is persisted', () async {
    expect(await LocalePrefs.read(), 'en');
  });

  test('write() persists and read() returns the new value', () async {
    await LocalePrefs.write('en');
    expect(await LocalePrefs.read(), 'en');
  });

  test('readFromPrefs respects pre-seeded value', () async {
    SharedPreferences.setMockInitialValues({'app_locale': 'bn'});
    final prefs = await SharedPreferences.getInstance();
    expect(LocalePrefs.readFromPrefs(prefs), 'bn');
  });

  test('toLocale maps codes and falls back to en for unknown', () {
    expect(LocalePrefs.toLocale('en'), const Locale('en'));
    expect(LocalePrefs.toLocale('bn'), const Locale('bn'));
    expect(LocalePrefs.toLocale('xx'), const Locale('en'));
  });

  test(
    'key constant matches the SharedPreferences key written by write()',
    () async {
      await LocalePrefs.write('en');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocalePrefs.key), 'en');
    },
  );
}
