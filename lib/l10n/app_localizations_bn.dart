// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get nav_home => 'হোম';

  @override
  String get nav_ebadat => 'ইবাদত';

  @override
  String get nav_calendar => 'ক্যালেন্ডার';

  @override
  String get nav_profile => 'প্রোফাইল';

  @override
  String get settings_languageSection => 'ভাষা';

  @override
  String get settings_languageSubtitle => 'অ্যাপের প্রদর্শন ভাষা বেছে নিন।';

  @override
  String get settings_languageLabel => 'অ্যাপের ভাষা';

  @override
  String get settings_languageBangla => 'বাংলা';

  @override
  String get settings_languageEnglish => 'English';

  @override
  String get widget_jamaatNA => 'জামাত নেই';

  @override
  String get widget_jamaatOver => 'জামাত শেষ';

  @override
  String get widget_jamaatOngoing => 'জামাত চলমান';

  @override
  String get widget_jamaatInSuffix => 'জামাত শুরু হবে';

  @override
  String get widget_comingDhuhr => 'আসছে যোহর';

  @override
  String get widget_prayerEndsIn => 'নামাজ শেষ হবে';

  @override
  String widget_nextPrayerIn(String prayer) {
    return '$prayer শুরু হবে';
  }

  @override
  String widget_nextPrayerJamaatAt(String prayer, String time) {
    return '$prayer জামাত $time';
  }

  @override
  String widget_timeRemaining(String prayer) {
    return '$prayer বাকি';
  }

  @override
  String get prayer_fajr => 'ফজর';

  @override
  String get prayer_sunrise => 'সূর্যোদয়';

  @override
  String get prayer_dhuhr => 'যোহর';

  @override
  String get prayer_asr => 'আসর';

  @override
  String get prayer_maghrib => 'মাগরিব';

  @override
  String get prayer_isha => 'এশা';

  @override
  String notification_prayerTitle(String prayer) {
    return '$prayer নামাজ';
  }

  @override
  String notification_prayerBody(String prayer) {
    return '$prayer নামাজের সময় আর ২০ মিনিট বাকি।';
  }

  @override
  String notification_jamaatTitle(String prayer) {
    return '$prayer জামাত';
  }

  @override
  String notification_jamaatBody(String prayer) {
    return '$prayer জামাত শুরু হবে ১০ মিনিট পরে।';
  }

  @override
  String get ebadat_monajatCopyTooltip => 'কপি করুন';

  @override
  String get ebadat_monajatPronunciationLabel => 'উচ্চারণ';

  @override
  String get ebadat_monajatMeaningLabel => 'অর্থ';

  @override
  String get ebadat_monajatContextLabel => 'প্রসঙ্গ ও ফযিলত';

  @override
  String get ebadat_monajatContextShortLabel => 'প্রসঙ্গ';

  @override
  String get ebadat_monajatCopyButton => 'সম্পূর্ণ দোয়া কপি করুন';

  @override
  String get ebadat_monajatCopySuccess => 'ক্লিপবোর্ডে কপি হয়েছে';

  @override
  String get ebadat_monajatCopyFailed => 'কপি করতে সমস্যা হয়েছে';

  @override
  String get ebadat_transliterationLabel => 'উচ্চারণ';

  @override
  String get ebadat_meaningLabel => 'অর্থ';

  @override
  String get ebadat_referencesTitle => 'সূত্রসমূহ';
}
