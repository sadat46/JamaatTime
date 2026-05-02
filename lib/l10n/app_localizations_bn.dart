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
  String get basicWebsiteProtectionTitle => 'বেসিক ওয়েবসাইট প্রোটেকশন';

  @override
  String get basicWebsiteProtectionSubtitle =>
      'বেসিক ওয়েবসাইট ফিল্টারিংয়ের জন্য পরিবারবান্ধব Private DNS সেটআপ করুন।';

  @override
  String get websiteProtectionTitle => 'অ্যাডভান্সড ওয়েবসাইট প্রোটেকশন';

  @override
  String get websiteProtectionSubtitle =>
      'আরও শক্তিশালী ওয়েবসাইট প্রোটেকশনের জন্য ঐচ্ছিক লোকাল VPN ফিল্টারিং ব্যবহার করুন।';

  @override
  String get websiteProtectionPlaceholder =>
      'ওয়েবসাইট প্রোটেকশন পারমিশন সেটআপ এখন করা যাবে। ফিল্টারিং পরের ধাপে চালু হবে।';

  @override
  String get websiteProtectionEnableCta => 'ওয়েবসাইট প্রোটেকশন চালু করুন';

  @override
  String get websiteProtectionVpnPermissionReadyTitle => 'VPN পারমিশন প্রস্তুত';

  @override
  String get websiteProtectionVpnPermissionReadyBody =>
      'পরের ধাপে ফিল্টারিং যোগ না হওয়া পর্যন্ত ওয়েবসাইট প্রোটেকশন চালু হবে না।';

  @override
  String get websiteProtectionVpnPermissionNeededTitle =>
      'VPN পারমিশন প্রয়োজন';

  @override
  String get websiteProtectionVpnPermissionNeededBody =>
      'প্রথমে ব্যাখ্যাটি দেখুন, তারপর Android VPN পারমিশন চাইবে। এই ধাপে প্রোটেকশন চালু হবে না।';

  @override
  String get websiteProtectionVpnPermissionGranted =>
      'VPN পারমিশন দেওয়া হয়েছে। পরের সেটআপ ধাপের আগে ওয়েবসাইট প্রোটেকশন চালু হবে না।';

  @override
  String get websiteProtectionVpnPermissionDenied =>
      'আপনি পরে যেকোনো সময় এটি চালু করতে পারবেন।';

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
      'বর্তমান ফোকাস গার্ড এবং মনোযোগ নষ্ট করা কনটেন্ট প্রোটেকশন দেখুন।';

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
  String get parentControlPinActiveTitle => 'PIN সক্রিয় আছে';

  @override
  String get parentControlPinInactiveTitle => 'কোনো PIN সেট নেই';

  @override
  String get parentControlPinActiveBody =>
      'সুরক্ষিত ফ্যামিলি সেফটি সেটিংস পরিবর্তন করতে এই PIN লাগবে।';

  @override
  String get parentControlPinInactiveBody =>
      'সুরক্ষিত ফ্যামিলি সেফটি সেটিংস চালু করার আগে একটি লোকাল PIN সেট করুন।';

  @override
  String get parentControlPinScope =>
      'এই PIN শুধু ফ্যামিলি সেফটি সেটিংস সুরক্ষিত রাখে। এটি অ্যাপের বাকি অংশ কখনো লক করে না।';

  @override
  String get parentControlCreatePinTitle => 'প্যারেন্ট কন্ট্রোল PIN তৈরি করুন';

  @override
  String get parentControlChangePinTitle =>
      'প্যারেন্ট কন্ট্রোল PIN পরিবর্তন করুন';

  @override
  String get parentControlCurrentPin => 'বর্তমান PIN';

  @override
  String get parentControlNewPin => 'নতুন PIN';

  @override
  String get parentControlConfirmPin => 'PIN নিশ্চিত করুন';

  @override
  String get parentControlPinHint => '৪ থেকে ৮টি সংখ্যা ব্যবহার করুন।';

  @override
  String get parentControlSavePin => 'PIN সংরক্ষণ করুন';

  @override
  String get parentControlUpdatePin => 'PIN আপডেট করুন';

  @override
  String get parentControlCancel => 'বাতিল';

  @override
  String get parentControlForgotPin => 'PIN ভুলে গেছেন';

  @override
  String get parentControlResetPinTitle => 'প্যারেন্ট কন্ট্রোল PIN রিসেট করুন';

  @override
  String get parentControlResetPinInputLabel => 'DISABLE টাইপ করুন';

  @override
  String get parentControlResetPinCta => 'রিসেট করে বন্ধ করুন';

  @override
  String get parentControlPinSaved => 'প্যারেন্ট কন্ট্রোল PIN সংরক্ষণ হয়েছে।';

  @override
  String get parentControlPinChanged =>
      'প্যারেন্ট কন্ট্রোল PIN পরিবর্তন হয়েছে।';

  @override
  String get parentControlPinReset =>
      'PIN রিসেট হয়েছে এবং ওয়েবসাইট প্রোটেকশন বন্ধ হয়েছে।';

  @override
  String get parentControlPinInvalid => '৪ থেকে ৮ সংখ্যার একটি PIN দিন।';

  @override
  String get parentControlPinMismatch => 'PIN মিলছে না।';

  @override
  String get parentControlPinIncorrect => 'PIN সঠিক নয়।';

  @override
  String get parentControlPinLocked =>
      'অনেকবার ভুল চেষ্টা হয়েছে। কুলডাউন শেষে আবার চেষ্টা করুন।';

  @override
  String get parentControlPinError =>
      'প্যারেন্ট কন্ট্রোল PIN আপডেট করা যায়নি।';

  @override
  String get safeSearchSetupTitle => 'অন্যান্য সেফটি গাইড';

  @override
  String get safeSearchSetupSubtitle =>
      'Google SafeSearch, YouTube Restricted Mode, এবং ব্রাউজার সেফটি সেটিংস চালু করুন।';

  @override
  String get safeSearchSetupPlaceholder =>
      'সেফ সার্চ ও Private DNS নির্দেশনা পরের ধাপে যোগ করা হবে।';

  @override
  String get safeSearchSetupIntro =>
      'পরিবারের ব্যবহারের জন্য সার্চ, ভিডিও, এবং ব্রাউজিং আরও নিরাপদ করতে এই ডিভাইস ও অ্যাকাউন্ট সেটিংস ব্যবহার করুন।';

  @override
  String get safeSearchGoogleTitle => 'Google SafeSearch';

  @override
  String get safeSearchGoogleBody =>
      'আপনার পরিবার যে প্রতিটি সাইন-ইন করা অ্যাকাউন্ট ও ব্রাউজার প্রোফাইল ব্যবহার করে, সেগুলোর Google Search settings থেকে SafeSearch চালু করুন।';

  @override
  String get safeSearchYoutubeTitle => 'YouTube Restricted Mode';

  @override
  String get safeSearchYoutubeBody =>
      'YouTube settings খুলে Restricted Mode চালু করুন। প্রতিটি ব্রাউজার, অ্যাপ প্রোফাইল, এবং শিশুর অ্যাকাউন্টের জন্য এটি আবার করুন।';

  @override
  String get safeSearchPrivateDnsTitle => 'Android Private DNS';

  @override
  String get safeSearchPrivateDnsBody =>
      'আরও শক্তিশালী পরিবার-ফিল্টারিংয়ের জন্য Android Private DNS-এ নিচের CleanBrowsing family host সেট করুন। এই অ্যাপ শুধু settings screen খুলে; সিস্টেম সেটিং বদলায় না।';

  @override
  String get safeSearchBrowserTitle => 'ব্রাউজার সেফ মোড';

  @override
  String get safeSearchBrowserBody =>
      'চাইল্ড প্রোফাইল ব্যবহার করুন, ব্রাউজার অনুমতি দিলে private browsing বন্ধ করুন, এবং safe browsing protection চালু রাখুন।';

  @override
  String get privateDnsStatusTitle => 'বর্তমান Private DNS';

  @override
  String get privateDnsLoading => 'Private DNS status দেখা হচ্ছে...';

  @override
  String get privateDnsModeLabel => 'মোড';

  @override
  String get privateDnsHostLabel => 'হোস্ট';

  @override
  String get privateDnsHostNotSet => 'সেট করা নেই';

  @override
  String get privateDnsModeOff => 'বন্ধ';

  @override
  String get privateDnsModeAutomatic => 'অটোমেটিক';

  @override
  String get privateDnsModeHostname => 'Private DNS provider hostname';

  @override
  String get privateDnsModeUnsupported => 'এই প্ল্যাটফর্মে নেই';

  @override
  String get privateDnsModeUnknown => 'অজানা';

  @override
  String get privateDnsDohProviderWarning =>
      'Private DNS একটি DoH provider-এ সেট করা আছে। Website Protection (পরে চালু হলে) DoH traffic দেখতে পারবে না — শক্তিশালী filtering-এর জন্য Private DNS Off করুন অথবা family-filter-dns.cleanbrowsing.org ব্যবহার করুন।';

  @override
  String get privateDnsStatusUnavailable =>
      'এই ডিভাইসে Private DNS status পাওয়া যাচ্ছে না।';

  @override
  String get privateDnsRecommendedHostLabel => 'প্রস্তাবিত family DNS host';

  @override
  String get safeSearchCopyDnsHostCta => 'DNS host কপি করুন';

  @override
  String get safeSearchOpenNetworkSettingsCta => 'Network Settings খুলুন';

  @override
  String get safeSearchRefreshStatusCta => 'Status refresh করুন';

  @override
  String get safeSearchCopiedDnsHostMessage =>
      'DNS host clipboard-এ কপি হয়েছে।';

  @override
  String get safeSearchNetworkSettingsUnavailable =>
      'এই ডিভাইসে Network settings খোলা যায়নি।';

  @override
  String get activitySummaryTitle => 'সেফটি সামারি';

  @override
  String get activitySummarySubtitle =>
      'ব্রাউজিং ইতিহাস না রেখে লোকাল প্রোটেকশন সংখ্যা দেখুন।';

  @override
  String get activitySummaryPlaceholder =>
      'সেফটি সামারি শুধু লোকাল প্রোটেকশন সংখ্যা দেখায়।';

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

  @override
  String get websiteProtectionTurnOnCta => 'প্রোটেকশন চালু করুন';

  @override
  String get websiteProtectionTurnOffCta => 'প্রোটেকশন বন্ধ করুন';

  @override
  String get websiteProtectionRunningTitle => 'ওয়েবসাইট প্রোটেকশন চালু আছে';

  @override
  String get websiteProtectionRunningBody =>
      'নির্বাচিত ক্যাটাগরি ব্লক করা হচ্ছে। বন্ধ করতে এই স্ক্রিনে ফিরে আসুন।';

  @override
  String get websiteProtectionStartFailed => 'প্রোটেকশন চালু করা যায়নি।';

  @override
  String get websiteProtectionStarted => 'ওয়েবসাইট প্রোটেকশন এখন চালু।';

  @override
  String get websiteProtectionStopped => 'ওয়েবসাইট প্রোটেকশন এখন বন্ধ।';

  @override
  String get websiteProtectionDohBannerTitle =>
      'Private DNS একটি DoH প্রোভাইডার ব্যবহার করছে';

  @override
  String get websiteProtectionDohBannerBody =>
      'Private DNS একটি DoH প্রোভাইডারে সেট থাকলে কিছু কোয়েরি ফিল্টার করা যায় না। সবচেয়ে ভালো ফলাফলের জন্য সিস্টেম সেটিংসে Private DNS Off করুন।';

  @override
  String get websiteProtectionOpenNetworkSettings => 'নেটওয়ার্ক সেটিংস খুলুন';

  @override
  String get websiteProtectionLimitsTitle => 'ওয়েবসাইট প্রোটেকশনের সীমাবদ্ধতা';

  @override
  String get websiteProtectionLimitsBullets =>
      '• Firefox বা Brave-এর মতো ব্রাউজারে HTTPS DNS (DoH) ফিল্টার করা যায় না।\n• হার্ডকোডেড DoH থাকা কিছু অ্যাপ ফিল্টার করা যায় না।\n• Android থেকে VPN-এর বাইরে রাখা অ্যাপ বা অন্য নেটওয়ার্কে চলা অ্যাপ ফিল্টার হয় না।\n• Wi-Fi বা মোবাইল ডেটা বন্ধ করলে ফিল্টারিং বন্ধ হয়।\nএটি একটি সহায়ক সুরক্ষা, পূর্ণ গ্যারান্টি নয়।';

  @override
  String get activitySummaryEmpty =>
      'এখনো কোনো ওয়েবসাইট ব্লক নেই। প্রোটেকশন কোনো ক্যাটাগরি ব্লক করলে সংখ্যা এখানে আসবে।';

  @override
  String get activitySummaryClearCta => 'সামারি মুছুন';

  @override
  String get activitySummaryClearedSnack => 'সেফটি সামারি মুছে ফেলা হয়েছে।';

  @override
  String activitySummaryRangeLabel(int days) {
    return 'শেষ $days দিন';
  }

  @override
  String get activitySummaryWebsiteBlocksToday => 'আজকের ওয়েবসাইট ব্লক';

  @override
  String get activitySummaryShortVideoBlocksToday => 'আজকের শর্ট-ভিডিও ব্লক';

  @override
  String get activitySummaryPrivacyNote =>
      'সেফটি সামারি শুধু লোকাল প্রোটেকশন সংখ্যা সংরক্ষণ করে। এটি ওয়েবসাইট, সার্চ টার্ম, বা পূর্ণ অ্যাপ ব্যবহারের ইতিহাস সংরক্ষণ করে না।';

  @override
  String get activitySummaryCategoryAdult => 'অ্যাডাল্ট কনটেন্ট';

  @override
  String get activitySummaryCategoryGambling => 'জুয়া';

  @override
  String get activitySummaryCategoryProxyBypass => 'Proxy / DNS bypass';

  @override
  String activitySummaryBlockedCount(int count) {
    return '$countটি ব্লক করা হয়েছে';
  }

  @override
  String get activitySummaryClearConfirmTitle => 'সামারি মুছবেন?';

  @override
  String get activitySummaryClearConfirmBody =>
      'ডিভাইসে রাখা সব সংখ্যা মুছে যাবে। এই কাজ ফিরিয়ে আনা যাবে না।';

  @override
  String get activitySummaryClearConfirmCta => 'মুছুন';

  @override
  String get activitySummaryCancelCta => 'বাতিল';

  @override
  String get activitySummaryExportCta => 'CSV ফাইলে এক্সপোর্ট করুন';

  @override
  String get activitySummaryExportNothing =>
      'এখনো এক্সপোর্ট করার মতো সংখ্যা নেই।';

  @override
  String get activitySummaryExportSuccess =>
      'অ্যাক্টিভিটি সামারি এক্সপোর্ট হয়েছে।';

  @override
  String get activitySummaryExportFailed =>
      'অ্যাক্টিভিটি সামারি এক্সপোর্ট করা যায়নি।';

  @override
  String activitySummaryRetentionNote(int days) {
    return '$days দিনের পুরোনো সংখ্যা স্বয়ংক্রিয়ভাবে মুছে ফেলা হয়।';
  }
}
