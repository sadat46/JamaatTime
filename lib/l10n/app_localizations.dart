import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
  ];

  /// Bottom navigation label for the Home tab
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get nav_home;

  /// Bottom navigation label for the Ebadat tab
  ///
  /// In en, this message translates to:
  /// **'Ebadat'**
  String get nav_ebadat;

  /// Bottom navigation label for the Calendar tab
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get nav_calendar;

  /// Bottom navigation label for the Profile tab
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get nav_profile;

  /// Section header for the language picker in Settings
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settings_languageSection;

  /// Subtitle under the Language section header
  ///
  /// In en, this message translates to:
  /// **'Choose the app display language.'**
  String get settings_languageSubtitle;

  /// Label above the language dropdown field
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settings_languageLabel;

  /// Dropdown item label for Bengali
  ///
  /// In en, this message translates to:
  /// **'বাংলা'**
  String get settings_languageBangla;

  /// Dropdown item label for English
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settings_languageEnglish;

  /// Home-screen widget label when no jamaat is scheduled
  ///
  /// In en, this message translates to:
  /// **'Jamaat N/A'**
  String get widget_jamaatNA;

  /// Home-screen widget label after jamaat window has passed
  ///
  /// In en, this message translates to:
  /// **'Jamaat ended'**
  String get widget_jamaatOver;

  /// Home-screen widget label while jamaat is ongoing
  ///
  /// In en, this message translates to:
  /// **'Jamaat ongoing'**
  String get widget_jamaatOngoing;

  /// Home-screen widget label prefix, e.g. 'Fajr Jamaat in 12m'
  ///
  /// In en, this message translates to:
  /// **'Jamaat in'**
  String get widget_jamaatInSuffix;

  /// Widget countdown label during Sunrise period
  ///
  /// In en, this message translates to:
  /// **'Coming Dhuhr'**
  String get widget_comingDhuhr;

  /// Widget countdown label for normal prayer periods
  ///
  /// In en, this message translates to:
  /// **'Prayer ends in'**
  String get widget_prayerEndsIn;

  /// Widget countdown label during Sunrise using next prayer name
  ///
  /// In en, this message translates to:
  /// **'{prayer} in'**
  String widget_nextPrayerIn(String prayer);

  /// Widget sunrise line showing next prayer jamaat time
  ///
  /// In en, this message translates to:
  /// **'{prayer} Jamaat at {time}'**
  String widget_nextPrayerJamaatAt(String prayer, String time);

  /// Widget countdown label for active prayer period
  ///
  /// In en, this message translates to:
  /// **'{prayer} Time Remaining'**
  String widget_timeRemaining(String prayer);

  /// Name of the Fajr prayer
  ///
  /// In en, this message translates to:
  /// **'Fajr'**
  String get prayer_fajr;

  /// Name of the Sunrise period
  ///
  /// In en, this message translates to:
  /// **'Sunrise'**
  String get prayer_sunrise;

  /// Name of the Dhuhr prayer
  ///
  /// In en, this message translates to:
  /// **'Dhuhr'**
  String get prayer_dhuhr;

  /// Name of the Asr prayer
  ///
  /// In en, this message translates to:
  /// **'Asr'**
  String get prayer_asr;

  /// Name of the Maghrib prayer
  ///
  /// In en, this message translates to:
  /// **'Maghrib'**
  String get prayer_maghrib;

  /// Name of the Isha prayer
  ///
  /// In en, this message translates to:
  /// **'Isha'**
  String get prayer_isha;

  /// Prayer notification title
  ///
  /// In en, this message translates to:
  /// **'{prayer} Prayer'**
  String notification_prayerTitle(String prayer);

  /// Prayer notification body
  ///
  /// In en, this message translates to:
  /// **'{prayer} time remaining 20 minutes.'**
  String notification_prayerBody(String prayer);

  /// Jamaat notification title
  ///
  /// In en, this message translates to:
  /// **'{prayer} Jamaat'**
  String notification_jamaatTitle(String prayer);

  /// Jamaat notification body
  ///
  /// In en, this message translates to:
  /// **'{prayer} Jamaat is in 10 minutes.'**
  String notification_jamaatBody(String prayer);

  /// Tooltip on monajat detail copy icon button
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get ebadat_monajatCopyTooltip;

  /// Section label for pronunciation in monajat detail
  ///
  /// In en, this message translates to:
  /// **'Pronunciation'**
  String get ebadat_monajatPronunciationLabel;

  /// Section label for meaning in monajat detail
  ///
  /// In en, this message translates to:
  /// **'Meaning'**
  String get ebadat_monajatMeaningLabel;

  /// Section label for context/fadilat in monajat detail
  ///
  /// In en, this message translates to:
  /// **'Context & Benefit'**
  String get ebadat_monajatContextLabel;

  /// Short label for context line in copied monajat text
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get ebadat_monajatContextShortLabel;

  /// Primary button label in monajat detail for copy
  ///
  /// In en, this message translates to:
  /// **'Copy Full Dua'**
  String get ebadat_monajatCopyButton;

  /// Snackbar text when monajat copy succeeds
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get ebadat_monajatCopySuccess;

  /// Snackbar text when monajat copy fails
  ///
  /// In en, this message translates to:
  /// **'Failed to copy'**
  String get ebadat_monajatCopyFailed;

  /// Label for transliteration section in ebadat cards
  ///
  /// In en, this message translates to:
  /// **'Transliteration'**
  String get ebadat_transliterationLabel;

  /// Label for meaning section in ebadat cards
  ///
  /// In en, this message translates to:
  /// **'Meaning'**
  String get ebadat_meaningLabel;

  /// Default expandable references section title
  ///
  /// In en, this message translates to:
  /// **'References'**
  String get ebadat_referencesTitle;

  /// Settings entry and page title for Family Safety
  ///
  /// In en, this message translates to:
  /// **'Family Safety'**
  String get familySafetyTitle;

  /// Settings entry subtitle for Family Safety
  ///
  /// In en, this message translates to:
  /// **'Help protect your family from harmful and distracting online content.'**
  String get familySafetySubtitle;

  /// Intro text on the Family Safety landing page
  ///
  /// In en, this message translates to:
  /// **'Optional on-device tools for family-friendly browsing habits and safer setup guidance.'**
  String get familySafetyIntro;

  /// Family Safety section title for website protection
  ///
  /// In en, this message translates to:
  /// **'Website Protection'**
  String get websiteProtectionTitle;

  /// Subtitle for Website Protection
  ///
  /// In en, this message translates to:
  /// **'Block selected harmful website categories when protection is enabled.'**
  String get websiteProtectionSubtitle;

  /// Status text for Website Protection before filtering is implemented
  ///
  /// In en, this message translates to:
  /// **'Website Protection permission setup is available now. Filtering starts in a later phase.'**
  String get websiteProtectionPlaceholder;

  /// CTA to enable Website Protection
  ///
  /// In en, this message translates to:
  /// **'Enable Website Protection'**
  String get websiteProtectionEnableCta;

  /// Status title when Android VPN permission is already granted
  ///
  /// In en, this message translates to:
  /// **'VPN permission ready'**
  String get websiteProtectionVpnPermissionReadyTitle;

  /// Status body for granted VPN permission before filtering is implemented
  ///
  /// In en, this message translates to:
  /// **'Website Protection will not start until filtering is added in the next phase.'**
  String get websiteProtectionVpnPermissionReadyBody;

  /// Status title when Android VPN permission is not granted
  ///
  /// In en, this message translates to:
  /// **'VPN permission required'**
  String get websiteProtectionVpnPermissionNeededTitle;

  /// Status body before requesting Android VPN permission
  ///
  /// In en, this message translates to:
  /// **'Review the disclosure, then Android will ask for VPN permission. Protection will not start in this phase.'**
  String get websiteProtectionVpnPermissionNeededBody;

  /// Snackbar after Android VPN permission is granted
  ///
  /// In en, this message translates to:
  /// **'VPN permission granted. Website Protection will not start until the next setup phase.'**
  String get websiteProtectionVpnPermissionGranted;

  /// Snackbar after Android VPN permission is denied or dismissed
  ///
  /// In en, this message translates to:
  /// **'You can enable this anytime later.'**
  String get websiteProtectionVpnPermissionDenied;

  /// Disclosure dialog title shown before Android VPN consent
  ///
  /// In en, this message translates to:
  /// **'Enable Website Protection?'**
  String get websiteProtectionVpnDisclosureTitle;

  /// Disclosure dialog body shown before Android VPN consent
  ///
  /// In en, this message translates to:
  /// **'Website Protection helps block harmful website categories (such as adult\ncontent, gambling, and proxy-bypass sites) for everyone using this device.\n\nTo do this, the app uses Android\'s VPN system locally on your device to\ninspect website addresses (domain names) and block selected categories.\n\nWhat this feature does NOT do:\n• It does not read messages, passwords, or payment details.\n• It does not inspect the contents of secure (HTTPS) pages.\n• It does not install any certificates.\n• It does not upload your browsing to any server.\n\nActivity summaries (counts only) are stored on your device and you can\nclear them at any time. You can disable Website Protection from this\nscreen whenever you want.'**
  String get websiteProtectionVpnDisclosureBody;

  /// Family Safety section title for Digital Wellbeing
  ///
  /// In en, this message translates to:
  /// **'Digital Wellbeing'**
  String get digitalWellbeingTitle;

  /// Subtitle for Digital Wellbeing
  ///
  /// In en, this message translates to:
  /// **'Review focus-friendly options without changing existing Focus Guard behavior.'**
  String get digitalWellbeingSubtitle;

  /// Placeholder text for Digital Wellbeing during the UI shell phase
  ///
  /// In en, this message translates to:
  /// **'Digital Wellbeing status will connect to the existing Focus Guard feature in a later phase.'**
  String get digitalWellbeingPlaceholder;

  /// Family Safety section title for Parent Control
  ///
  /// In en, this message translates to:
  /// **'Parent Control'**
  String get parentControlTitle;

  /// Subtitle for Parent Control
  ///
  /// In en, this message translates to:
  /// **'Use a local PIN to guard Family Safety settings.'**
  String get parentControlSubtitle;

  /// Button label to set a Parent Control PIN
  ///
  /// In en, this message translates to:
  /// **'Set PIN'**
  String get parentControlSetPin;

  /// Button label to change a Parent Control PIN
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get parentControlChangePin;

  /// Warning copy for forgotten Parent Control PIN reset
  ///
  /// In en, this message translates to:
  /// **'This will reset your PIN and disable Website Protection. To reset, type the word DISABLE.'**
  String get parentControlForgotPinWarning;

  /// Placeholder text for Parent Control during the UI shell phase
  ///
  /// In en, this message translates to:
  /// **'PIN setup will be added in a later phase. It will guard only Family Safety settings.'**
  String get parentControlPlaceholder;

  /// Status title when a Parent Control PIN exists
  ///
  /// In en, this message translates to:
  /// **'PIN is active'**
  String get parentControlPinActiveTitle;

  /// Status title when no Parent Control PIN exists
  ///
  /// In en, this message translates to:
  /// **'No PIN set'**
  String get parentControlPinInactiveTitle;

  /// Status body when a Parent Control PIN exists
  ///
  /// In en, this message translates to:
  /// **'Changing protected Family Safety settings will require this PIN.'**
  String get parentControlPinActiveBody;

  /// Status body when no Parent Control PIN exists
  ///
  /// In en, this message translates to:
  /// **'Set a local PIN before enabling protected Family Safety settings.'**
  String get parentControlPinInactiveBody;

  /// Explains the local PIN scope
  ///
  /// In en, this message translates to:
  /// **'This PIN protects Family Safety settings only. It never locks the rest of the app.'**
  String get parentControlPinScope;

  /// Dialog title for creating a Parent Control PIN
  ///
  /// In en, this message translates to:
  /// **'Create Parent Control PIN'**
  String get parentControlCreatePinTitle;

  /// Dialog title for changing a Parent Control PIN
  ///
  /// In en, this message translates to:
  /// **'Change Parent Control PIN'**
  String get parentControlChangePinTitle;

  /// Input label for the current Parent Control PIN
  ///
  /// In en, this message translates to:
  /// **'Current PIN'**
  String get parentControlCurrentPin;

  /// Input label for a new Parent Control PIN
  ///
  /// In en, this message translates to:
  /// **'New PIN'**
  String get parentControlNewPin;

  /// Input label for confirming a Parent Control PIN
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get parentControlConfirmPin;

  /// Helper text for Parent Control PIN fields
  ///
  /// In en, this message translates to:
  /// **'Use 4 to 8 digits.'**
  String get parentControlPinHint;

  /// Dialog action for saving a Parent Control PIN
  ///
  /// In en, this message translates to:
  /// **'Save PIN'**
  String get parentControlSavePin;

  /// Dialog action for updating a Parent Control PIN
  ///
  /// In en, this message translates to:
  /// **'Update PIN'**
  String get parentControlUpdatePin;

  /// Dialog cancel action in Parent Control
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get parentControlCancel;

  /// Button label for forgotten Parent Control PIN flow
  ///
  /// In en, this message translates to:
  /// **'Forgot PIN'**
  String get parentControlForgotPin;

  /// Dialog title for resetting a forgotten Parent Control PIN
  ///
  /// In en, this message translates to:
  /// **'Reset Parent Control PIN'**
  String get parentControlResetPinTitle;

  /// Input label for reset confirmation word
  ///
  /// In en, this message translates to:
  /// **'Type DISABLE'**
  String get parentControlResetPinInputLabel;

  /// Dialog action to reset PIN and disable Website Protection
  ///
  /// In en, this message translates to:
  /// **'Reset and disable'**
  String get parentControlResetPinCta;

  /// Snackbar shown after saving a Parent Control PIN
  ///
  /// In en, this message translates to:
  /// **'Parent Control PIN saved.'**
  String get parentControlPinSaved;

  /// Snackbar shown after changing a Parent Control PIN
  ///
  /// In en, this message translates to:
  /// **'Parent Control PIN changed.'**
  String get parentControlPinChanged;

  /// Snackbar shown after resetting a forgotten Parent Control PIN
  ///
  /// In en, this message translates to:
  /// **'PIN reset and Website Protection disabled.'**
  String get parentControlPinReset;

  /// Validation message for invalid Parent Control PIN
  ///
  /// In en, this message translates to:
  /// **'Enter a PIN with 4 to 8 digits.'**
  String get parentControlPinInvalid;

  /// Validation message for mismatched Parent Control PIN confirmation
  ///
  /// In en, this message translates to:
  /// **'PINs do not match.'**
  String get parentControlPinMismatch;

  /// Snackbar shown after an incorrect Parent Control PIN
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN.'**
  String get parentControlPinIncorrect;

  /// Snackbar/status message shown during Parent Control PIN cooldown
  ///
  /// In en, this message translates to:
  /// **'Too many incorrect attempts. Try again after the cooldown.'**
  String get parentControlPinLocked;

  /// Generic error message for Parent Control PIN actions
  ///
  /// In en, this message translates to:
  /// **'Parent Control PIN could not be updated.'**
  String get parentControlPinError;

  /// Family Safety section title for Safe Search Setup
  ///
  /// In en, this message translates to:
  /// **'Safe Search Setup'**
  String get safeSearchSetupTitle;

  /// Subtitle for Safe Search Setup
  ///
  /// In en, this message translates to:
  /// **'Guidance for SafeSearch, Restricted Mode, and family-filtered DNS.'**
  String get safeSearchSetupSubtitle;

  /// Placeholder text for Safe Search Setup during the UI shell phase
  ///
  /// In en, this message translates to:
  /// **'Safe Search and Private DNS guidance will be added in the next phase.'**
  String get safeSearchSetupPlaceholder;

  /// Intro text on the Safe Search Setup page
  ///
  /// In en, this message translates to:
  /// **'Use these device and account settings to make search, video, and browsing safer for family use.'**
  String get safeSearchSetupIntro;

  /// Guide card title for Google SafeSearch
  ///
  /// In en, this message translates to:
  /// **'Google SafeSearch'**
  String get safeSearchGoogleTitle;

  /// Guide text for Google SafeSearch
  ///
  /// In en, this message translates to:
  /// **'Turn on SafeSearch in Google Search settings for each signed-in account and browser profile your family uses.'**
  String get safeSearchGoogleBody;

  /// Guide card title for YouTube Restricted Mode
  ///
  /// In en, this message translates to:
  /// **'YouTube Restricted Mode'**
  String get safeSearchYoutubeTitle;

  /// Guide text for YouTube Restricted Mode
  ///
  /// In en, this message translates to:
  /// **'Open YouTube settings and enable Restricted Mode. Repeat this for each browser, app profile, and child account.'**
  String get safeSearchYoutubeBody;

  /// Guide card title for Android Private DNS
  ///
  /// In en, this message translates to:
  /// **'Android Private DNS'**
  String get safeSearchPrivateDnsTitle;

  /// Guide text for Android Private DNS
  ///
  /// In en, this message translates to:
  /// **'For stronger family filtering, set Android Private DNS to the CleanBrowsing family host shown below. This app only opens the settings screen; it does not change the system setting.'**
  String get safeSearchPrivateDnsBody;

  /// Guide card title for browser safe-mode tips
  ///
  /// In en, this message translates to:
  /// **'Browser Safe Mode'**
  String get safeSearchBrowserTitle;

  /// Guide text for browser safe-mode tips
  ///
  /// In en, this message translates to:
  /// **'Use child profiles, disable private browsing where your browser allows it, and keep safe browsing protection enabled.'**
  String get safeSearchBrowserBody;

  /// Private DNS status card title
  ///
  /// In en, this message translates to:
  /// **'Current Private DNS'**
  String get privateDnsStatusTitle;

  /// Loading text while reading Private DNS state
  ///
  /// In en, this message translates to:
  /// **'Checking Private DNS status...'**
  String get privateDnsLoading;

  /// Label for Private DNS mode
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get privateDnsModeLabel;

  /// Label for Private DNS host
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get privateDnsHostLabel;

  /// Private DNS host value when no hostname is configured
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get privateDnsHostNotSet;

  /// Private DNS mode value for off
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get privateDnsModeOff;

  /// Private DNS mode value for opportunistic/automatic
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get privateDnsModeAutomatic;

  /// Private DNS mode value for hostname mode
  ///
  /// In en, this message translates to:
  /// **'Private DNS provider hostname'**
  String get privateDnsModeHostname;

  /// Private DNS mode value when platform channel is unavailable
  ///
  /// In en, this message translates to:
  /// **'Unavailable on this platform'**
  String get privateDnsModeUnsupported;

  /// Private DNS mode value when Android returns no recognized mode
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get privateDnsModeUnknown;

  /// Warning shown when Private DNS uses a known DoH/DoT provider hostname
  ///
  /// In en, this message translates to:
  /// **'Private DNS is set to a DoH provider. Website Protection (when enabled later) cannot inspect DoH traffic — consider switching Private DNS to Off or to family-filter-dns.cleanbrowsing.org for stronger filtering.'**
  String get privateDnsDohProviderWarning;

  /// Private DNS status unavailable message
  ///
  /// In en, this message translates to:
  /// **'Private DNS status is unavailable on this device.'**
  String get privateDnsStatusUnavailable;

  /// Label before the recommended CleanBrowsing family DNS hostname
  ///
  /// In en, this message translates to:
  /// **'Recommended family DNS host'**
  String get privateDnsRecommendedHostLabel;

  /// Button label for copying the recommended family DNS host
  ///
  /// In en, this message translates to:
  /// **'Copy DNS host'**
  String get safeSearchCopyDnsHostCta;

  /// Button label for opening Android network settings
  ///
  /// In en, this message translates to:
  /// **'Open Network Settings'**
  String get safeSearchOpenNetworkSettingsCta;

  /// Tooltip for refreshing Private DNS status
  ///
  /// In en, this message translates to:
  /// **'Refresh status'**
  String get safeSearchRefreshStatusCta;

  /// Snackbar message after copying DNS host
  ///
  /// In en, this message translates to:
  /// **'DNS host copied to clipboard.'**
  String get safeSearchCopiedDnsHostMessage;

  /// Snackbar message when network settings intent is unavailable
  ///
  /// In en, this message translates to:
  /// **'Network settings could not be opened on this device.'**
  String get safeSearchNetworkSettingsUnavailable;

  /// Family Safety section title for Activity Summary
  ///
  /// In en, this message translates to:
  /// **'Activity Summary'**
  String get activitySummaryTitle;

  /// Subtitle for Activity Summary
  ///
  /// In en, this message translates to:
  /// **'View local counts for blocked categories without storing browsing history.'**
  String get activitySummarySubtitle;

  /// Placeholder text for Activity Summary during the UI shell phase
  ///
  /// In en, this message translates to:
  /// **'Activity Summary will show local counts only after Website Protection exists.'**
  String get activitySummaryPlaceholder;

  /// Family Safety privacy explanation page title
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacyExplanationTitle;

  /// Family Safety privacy explanation tile subtitle
  ///
  /// In en, this message translates to:
  /// **'Understand what Family Safety does locally on this device.'**
  String get privacyExplanationSubtitle;

  /// Privacy explanation for the Family Safety section
  ///
  /// In en, this message translates to:
  /// **'Family Safety is optional and off by default. This phase adds only guidance and placeholder screens. It does not add a VPN, Accessibility changes, overlays, DNS upload, HTTPS interception, or new permissions.'**
  String get familySafetyPrivacyExplanation;

  /// Negative action on Family Safety disclosure dialogs
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get familySafetyNotNowCta;

  /// Positive action on Website Protection VPN disclosure dialog
  ///
  /// In en, this message translates to:
  /// **'Continue and grant permission'**
  String get familySafetyContinueGrantPermissionCta;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
