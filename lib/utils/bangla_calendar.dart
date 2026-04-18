class BanglaCalendar {
  static const List<String> _monthNames = [
    'বৈশাখ', 'জ্যৈষ্ঠ', 'আষাঢ়', 'শ্রাবণ', 'ভাদ্র', 'আশ্বিন',
    'কার্তিক', 'অগ্রহায়ণ', 'পৌষ', 'মাঘ', 'ফাল্গুন', 'চৈত্র',
  ];

  static const List<String> _banglaDigits = [
    '০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯',
  ];

  static String _toBanglaDigits(String numStr) {
    return numStr.split('').map((c) {
      final code = c.codeUnitAt(0);
      if (code >= 48 && code <= 57) return _banglaDigits[code - 48];
      return c;
    }).join();
  }

  /// Converts Western digits in [text] into Bangla digits.
  static String toBanglaDigits(String text) => _toBanglaDigits(text);

  static bool _isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }

  /// Converts a Gregorian [date] to a Bangla calendar string.
  /// e.g. `২৫ ফাল্গুন ১৪ৃ২ বঙ্গাব্দ`
  static String fromGregorian(DateTime date) {
    // Bangla new year starts on April 14.
    final newYearDate = DateTime(date.year, 4, 14);
    final bool afterNewYear = !date.isBefore(newYearDate);

    final int banglaYear = afterNewYear ? date.year - 593 : date.year - 594;

    // Days in each Bangla month:
    // বৈশাখ–ভাদ্র (0-4): 31 days each
    // আশ্বিন–চৈত্র (5-11): 30 days each
    // চৈত্র gets 31 if the corresponding Gregorian year is a leap year.
    final List<int> monthDays = [31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 30, 30];
    if (_isLeapYear(banglaYear + 594)) {
      monthDays[11] = 31; // চৈত্র gets extra day
    }

    // Calculate day-of-year in Bangla calendar.
    // Bangla year starts April 14, so compute days since then.
    int dayOfBanglaYear;
    if (afterNewYear) {
      dayOfBanglaYear = date.difference(newYearDate).inDays;
    } else {
      final prevNewYear = DateTime(date.year - 1, 4, 14);
      dayOfBanglaYear = date.difference(prevNewYear).inDays;
    }

    // Find month and day.
    int monthIndex = 0;
    int remaining = dayOfBanglaYear;
    while (monthIndex < 11 && remaining >= monthDays[monthIndex]) {
      remaining -= monthDays[monthIndex];
      monthIndex++;
    }

    final int banglaDay = remaining + 1;
    final String monthName = _monthNames[monthIndex];

    return '${_toBanglaDigits('$banglaDay')} $monthName ${_toBanglaDigits('$banglaYear')} বঙ্গাব্দ';
  }
}
