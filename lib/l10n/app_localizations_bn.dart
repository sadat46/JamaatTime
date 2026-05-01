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
  String get widget_jamaatInSuffix => 'জামাত শুরু হতে বাকি';

  @override
  String get widget_comingDhuhr => 'আসছে যোহর';

  @override
  String get widget_prayerEndsIn => 'ওয়াক্ত শেষ হতে বাকি';

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

  @override
  String get familySafetyTitle => 'ফ্যামিলি সেফটি';

  @override
  String get familySafetySubtitle =>
      'ক্ষতিকর ও মনোযোগ নষ্ট করা অনলাইন কনটেন্ট থেকে পরিবারকে সুরক্ষিত রাখতে সহায়তা করুন।';

  @override
  String get familySafetyIntro =>
      'পরিবারবান্ধব ব্রাউজিং অভ্যাস ও নিরাপদ সেটআপের জন্য ঐচ্ছিক অন-ডিভাইস টুল।';

  @override
  String get websiteProtectionTitle => 'ওয়েবসাইট প্রোটেকশন';

  @override
  String get websiteProtectionSubtitle =>
      'প্রোটেকশন চালু থাকলে নির্বাচিত ক্ষতিকর ওয়েবসাইট ক্যাটাগরি ব্লক করুন।';

  @override
  String get websiteProtectionPlaceholder =>
      'ওয়েবসাইট প্রোটেকশন সেটআপ পরের ধাপে যোগ করা হবে। এই রিলিজে কোনো VPN বা সংবেদনশীল পারমিশন সক্রিয় নয়।';

  @override
  String get websiteProtectionEnableCta => 'ওয়েবসাইট প্রোটেকশন চালু করুন';

  @override
  String get websiteProtectionVpnDisclosureTitle =>
      'ওয়েবসাইট প্রোটেকশন চালু করবেন?';

  @override
  String get websiteProtectionVpnDisclosureBody =>
      'ওয়েবসাইট প্রোটেকশন এই ডিভাইস ব্যবহারকারী সবার জন্য ক্ষতিকর ওয়েবসাইট ক্যাটাগরি (যেমন প্রাপ্তবয়স্ক কনটেন্ট, জুয়া, এবং প্রক্সি-বাইপাস সাইট) ব্লক করতে সহায়তা করে।\n\nএটি করতে অ্যাপটি আপনার ডিভাইসে Android VPN সিস্টেম লোকালি ব্যবহার করে ওয়েবসাইট ঠিকানা (ডোমেইন নাম) দেখে নির্বাচিত ক্যাটাগরি ব্লক করে।\n\nএই ফিচার যা করে না:\n• এটি মেসেজ, পাসওয়ার্ড, বা পেমেন্ট তথ্য পড়ে না।\n• এটি সুরক্ষিত (HTTPS) পেজের কনটেন্ট দেখে না।\n• এটি কোনো সার্টিফিকেট ইনস্টল করে না।\n• এটি আপনার ব্রাউজিং কোনো সার্ভারে আপলোড করে না।\n\nঅ্যাক্টিভিটি সামারি (শুধু সংখ্যা) আপনার ডিভাইসে সংরক্ষিত থাকে এবং যেকোনো সময় মুছে ফেলতে পারবেন। আপনি চাইলে এই স্ক্রিন থেকে ওয়েবসাইট প্রোটেকশন বন্ধ করতে পারবেন।';

  @override
  String get digitalWellbeingTitle => 'ডিজিটাল ওয়েলবিয়িং';

  @override
  String get digitalWellbeingSubtitle =>
      'বর্তমান ফোকাস গার্ড আচরণ না বদলে ফোকাসবান্ধব অপশন দেখুন।';

  @override
  String get digitalWellbeingPlaceholder =>
      'ডিজিটাল ওয়েলবিয়িং স্ট্যাটাস পরের ধাপে বর্তমান ফোকাস গার্ড ফিচারের সাথে যুক্ত হবে।';

  @override
  String get parentControlTitle => 'প্যারেন্ট কন্ট্রোল';

  @override
  String get parentControlSubtitle =>
      'ফ্যামিলি সেফটি সেটিংস সুরক্ষিত রাখতে লোকাল PIN ব্যবহার করুন।';

  @override
  String get parentControlSetPin => 'PIN সেট করুন';

  @override
  String get parentControlChangePin => 'PIN পরিবর্তন করুন';

  @override
  String get parentControlForgotPinWarning =>
      'এটি আপনার PIN রিসেট করবে এবং ওয়েবসাইট প্রোটেকশন বন্ধ করবে। রিসেট করতে DISABLE শব্দটি টাইপ করুন।';

  @override
  String get parentControlPlaceholder =>
      'PIN সেটআপ পরের ধাপে যোগ করা হবে। এটি শুধু ফ্যামিলি সেফটি সেটিংস সুরক্ষিত রাখবে।';

  @override
  String get safeSearchSetupTitle => 'সেফ সার্চ সেটআপ';

  @override
  String get safeSearchSetupSubtitle =>
      'SafeSearch, Restricted Mode, এবং পরিবার-ফিল্টারড DNS সেটআপের নির্দেশনা।';

  @override
  String get safeSearchSetupPlaceholder =>
      'সেফ সার্চ ও Private DNS নির্দেশনা পরের ধাপে যোগ করা হবে।';

  @override
  String get activitySummaryTitle => 'অ্যাক্টিভিটি সামারি';

  @override
  String get activitySummarySubtitle =>
      'ব্রাউজিং ইতিহাস না রেখে ব্লক হওয়া ক্যাটাগরির লোকাল সংখ্যা দেখুন।';

  @override
  String get activitySummaryPlaceholder =>
      'ওয়েবসাইট প্রোটেকশন তৈরি হওয়ার পর অ্যাক্টিভিটি সামারি শুধু লোকাল সংখ্যা দেখাবে।';

  @override
  String get privacyExplanationTitle => 'প্রাইভেসি';

  @override
  String get privacyExplanationSubtitle =>
      'এই ডিভাইসে ফ্যামিলি সেফটি লোকালি কী করে তা জানুন।';

  @override
  String get familySafetyPrivacyExplanation =>
      'ফ্যামিলি সেফটি ঐচ্ছিক এবং ডিফল্টভাবে বন্ধ। এই ধাপে শুধু নির্দেশনা ও প্লেসহোল্ডার স্ক্রিন যোগ করা হয়েছে। এতে কোনো VPN, Accessibility পরিবর্তন, overlay, DNS আপলোড, HTTPS interception, বা নতুন পারমিশন যোগ হয়নি।';

  @override
  String get familySafetyNotNowCta => 'এখন নয়';

  @override
  String get familySafetyContinueGrantPermissionCta =>
      'চালিয়ে যান এবং পারমিশন দিন';
}
