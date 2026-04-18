import 'dart:async';

import 'package:hijri_calendar/hijri_calendar.dart';
import '../utils/bangla_calendar.dart';

/// Immutable Hijri date parts used by app features.
class HijriDateParts {
  final int day;
  final int month;
  final int year;

  const HijriDateParts({
    required this.day,
    required this.month,
    required this.year,
  });
}

/// Centralized Gregorian->Hijri conversion with optional day offset support.
class HijriDateConverter {
  static const List<String> _hijriMonths = [
    'Muharram',
    'Safar',
    "Rabi' al-Awwal",
    "Rabi' al-Thani",
    'Jumada al-Awwal',
    'Jumada al-Thani',
    'Rajab',
    "Sha'ban",
    'Ramadan',
    'Shawwal',
    "Dhu al-Qi'dah",
    'Dhu al-Hijjah',
  ];

  static const List<String> _hijriMonthsBn = [
    'মুহাররম',
    'সফর',
    'রবিউল আউয়াল',
    'রবিউস সানি',
    'জুমাদাল উলা',
    'জুমাদাস সানিয়া',
    'রজব',
    'শাবান',
    'রমজান',
    'শাওয়াল',
    'জিলকদ',
    'জিলহজ',
  ];

  static HijriDateParts toHijri(DateTime date, {int dayOffset = 0}) {
    // Normalize to local noon before conversion to avoid edge effects near
    // midnight when device timezone and conversion timezone differ.
    final normalized = DateTime(date.year, date.month, date.day, 12)
        .add(Duration(days: dayOffset));

    final hijri = _runSilently(
      () => HijriCalendarConfig.fromGregorian(normalized),
    );

    return HijriDateParts(
      day: hijri.hDay,
      month: hijri.hMonth,
      year: hijri.hYear,
    );
  }

  static String formatHijriDate(
    DateTime date, {
    int dayOffset = 0,
    String languageCode = 'en',
  }) {
    final hijriDate = toHijri(date, dayOffset: dayOffset);
    final isBangla = languageCode.toLowerCase() == 'bn';
    final months = isBangla ? _hijriMonthsBn : _hijriMonths;

    final dayStr = isBangla
        ? BanglaCalendar.toBanglaDigits('${hijriDate.day}')
        : '${hijriDate.day}';
    final yearStr = isBangla
        ? BanglaCalendar.toBanglaDigits('${hijriDate.year}')
        : '${hijriDate.year}';

    if (hijriDate.month < 1 || hijriDate.month > months.length) {
      final monthStr = isBangla
          ? BanglaCalendar.toBanglaDigits('${hijriDate.month}')
          : '${hijriDate.month}';
      final suffix = isBangla ? 'হিজরি' : 'AH';
      return '$dayStr $monthStr $yearStr $suffix';
    }

    final monthName = months[hijriDate.month - 1];
    final suffix = isBangla ? 'হিজরি' : 'AH';
    return '$dayStr $monthName $yearStr $suffix';
  }

  static bool isRamadan(DateTime date, {int dayOffset = 0}) {
    final hijriDate = toHijri(date, dayOffset: dayOffset);
    return hijriDate.month == 9;
  }

  static T _runSilently<T>(T Function() action) {
    return runZoned<T>(
      action,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {},
      ),
    );
  }
}
