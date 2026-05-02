import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/screens/calendar_screen.dart';

void main() {
  test('buildPrayerShareText formats selected date and prayer rows', () {
    final text = buildPrayerShareText(
      locationLabel: 'Savar Cantt',
      gregorianDate: '2 May 2026',
      weekday: 'Saturday',
      hijriDate: "14 Dhu al-Qi'dah 1447 AH",
      banglaDate: '১৯ বৈশাখ ১৪৩৩ বঙ্গাব্দ',
      rows: [
        ['Fajr', '4:03 AM', '5:00 AM'],
        ['Sunrise', '5:24 AM', '-'],
        ['Zuhr', '11:56 AM', '1:15 PM'],
      ],
    );

    expect(text, '''
Prayer & Jamaat Time
Savar Cantt

2 May 2026, Saturday
14 Dhu al-Qi'dah 1447 AH
১৯ বৈশাখ ১৪৩৩ বঙ্গাব্দ

Name        Prayer     Jamaat
────────────────────────
Fajr        4:03 AM    5:00 AM
Sunrise     5:24 AM    —
Zuhr        11:56 AM   1:15 PM

Shared from Jamaat Time''');
  });
}
