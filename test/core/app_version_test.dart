import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/core/app_version.dart';

void main() {
  group('AppVersion.publicBuildNumber', () {
    test('keeps normal pubspec build numbers unchanged', () {
      expect(AppVersion.publicBuildNumber('10'), '10');
      expect(AppVersion.publicBuildNumber('15'), '15');
    });

    test('normalizes Flutter split APK version codes', () {
      expect(AppVersion.publicBuildNumber('1010'), '10');
      expect(AppVersion.publicBuildNumber('2010'), '10');
      expect(AppVersion.publicBuildNumber('4010'), '10');
      expect(AppVersion.publicBuildNumber('2015'), '15');
    });

    test('returns non-numeric values unchanged', () {
      expect(AppVersion.publicBuildNumber('unknown'), 'unknown');
    });
  });

  test('label uses the normalized public build number', () {
    expect(
      AppVersion.label(version: '2.0.46', buildNumber: '2010'),
      'v 2.0.46 (10)',
    );
  });
}
