import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import '../core/app_locale_controller.dart';
import '../core/app_text.dart';
import '../core/constants.dart';
import '../core/locale_prefs.dart';
import '../models/location_config.dart';
import '../services/jamaat_service.dart';
import '../services/location_config_service.dart';
import '../services/prayer_aux_calculator.dart';
import '../services/prayer_time_engine.dart';
import '../services/settings_service.dart';
import '../utils/bangla_calendar.dart';
import '../utils/locale_digits.dart';
import '../firebase_options.dart';
import 'hijri_date_converter.dart';

/// Top-level background callback for home widget refresh button.
/// Must be top-level (not inside a class) for home_widget background execution.
@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e, st) {
    // Firebase is optional for widget refresh; Jamaat data will fall back to N/A.
    debugPrint('widget bgcb firebase init failed: $e\n$st');
  }

  try {
    final prefs = await SharedPreferences.getInstance();
    final locale = LocalePrefs.toLocale(LocalePrefs.readFromPrefs(prefs));
    final isGpsMode = prefs.getBool('is_gps_mode') ?? false;
    final savedCity = prefs.getString('selected_city');
    final lastLat = prefs.getDouble('last_latitude');
    final lastLng = prefs.getDouble('last_longitude');
    final madhabStr = prefs.getString('madhab') ?? 'hanafi';
    final hijriOffset =
        prefs.getInt('bangladesh_hijri_offset_days') ??
        SettingsService.defaultBangladeshHijriOffsetDays;

    final configService = LocationConfigService();
    LocationConfig config;
    Coordinates coords;

    if (isGpsMode && lastLat != null && lastLng != null) {
      final locationName =
          prefs.getString('last_location_name') ?? 'GPS Location';
      config = LocationConfig.world(locationName, lastLat, lastLng);
      coords = Coordinates(lastLat, lastLng);
    } else {
      final cityName = savedCity ?? AppConstants.defaultCity;
      config = configService.getConfigForCity(cityName);
      coords = Coordinates(config.latitude, config.longitude);
    }

    final calcService = PrayerTimeEngine.instance;
    final params = calcService.getCalculationParametersForConfig(config);

    if (config.country == Country.bangladesh) {
      params.madhab = madhabStr == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    }

    final now = DateTime.now();
    final prayerTimes = PrayerTimes(
      coordinates: coords,
      date: now,
      calculationParameters: params,
      precision: true,
    );

    final times = calcService.createPrayerTimesMap(prayerTimes);
    final effectiveHijriOffset = config.country == Country.bangladesh
        ? hijriOffset
        : 0;

    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    final tomorrowTimes = PrayerTimes(
      coordinates: coords,
      date: tomorrow,
      calculationParameters: params,
      precision: true,
    );
    final tomorrowMap = calcService.createPrayerTimesMap(tomorrowTimes);
    Map<String, dynamic>? widgetJamaatTimes;

    if (config.jamaatSource == JamaatSource.localOffset) {
      widgetJamaatTimes = PrayerAuxCalculator.instance.buildOffsetJamaatTimes(
        prayerTimes: times,
        offsets: config.jamaatOffsets,
      );
    } else if (config.jamaatSource == JamaatSource.server) {
      final cityForJamaat = savedCity ?? config.cityName;
      final serverTimes = await JamaatService()
          .getJamaatTimes(city: cityForJamaat, date: now)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (serverTimes != null) {
        widgetJamaatTimes = Map<String, dynamic>.from(serverTimes);
        final maghribJamaat = PrayerAuxCalculator.instance
            .calculateMaghribJamaatTime(
              maghribPrayerTime: times['Maghrib'],
              selectedCity: cityForJamaat,
            );
        if (maghribJamaat != '-') {
          widgetJamaatTimes['maghrib'] = maghribJamaat;
        }
      }
    }

    final placeName = prefs.getString('last_location_name');
    await WidgetService.updateWidgetData(
      times: times,
      locale: locale,
      locationName: placeName ?? config.cityName,
      date: now,
      hijriOffsetDays: effectiveHijriOffset,
      tomorrowFajr: tomorrowMap['Fajr'],
      jamaatTimes: widgetJamaatTimes,
    );
  } catch (e, st) {
    // Background callback errors are non-fatal but must be visible in logcat
    // so we can diagnose stale-widget reports.
    debugPrint('widget bgcb error: $e\n$st');
  }
}

class WidgetService {
  static const String _androidWidgetName = 'PrayerWidgetProvider';
  static const _fmt = 'HH:mm';
  static const Duration _jamaatOngoingWindow = Duration(minutes: 10);
  static const Map<String, String> _bnLocationPhraseMap = {
    'GPS Location': 'জিপিএস অবস্থান',
    'Barishal Cantt': 'বরিশাল ক্যান্ট',
    'Bogra Cantt': 'বগুড়া ক্যান্ট',
    'Chittagong Cantt': 'চট্টগ্রাম ক্যান্ট',
    'Dhaka Cantt': 'ঢাকা ক্যান্ট',
    'Ghatail Cantt': 'ঘাটাইল ক্যান্ট',
    'Jashore Cantt': 'যশোর ক্যান্ট',
    'Kumilla Cantt': 'কুমিল্লা ক্যান্ট',
    'Ramu Cantt': 'রামু ক্যান্ট',
    'Rangpur Cantt': 'রংপুর ক্যান্ট',
    'Savar Cantt': 'সাভার ক্যান্ট',
    'Sylhet Cantt': 'সিলেট ক্যান্ট',
    'Makkah': 'মক্কা',
    'Madinah': 'মদিনা',
    'Jeddah': 'জেদ্দা',
  };
  static const Map<String, String> _bnLocationWordMap = {
    'Savar': 'সাভার',
    'Dhaka': 'ঢাকা',
    'District': 'জেলা',
    'Division': 'বিভাগ',
    'Bangladesh': 'বাংলাদেশ',
    'Cantt': 'ক্যান্ট',
  };

  static Future<void> updateWidgetData({
    required Map<String, DateTime?> times,
    required Locale locale,
    required String locationName,
    required DateTime date,
    required int hijriOffsetDays,
    DateTime? tomorrowFajr,
    Map<String, dynamic>? jamaatTimes,
  }) async {
    try {
      final now = DateTime.now();
      final localeCode = locale.languageCode.toLowerCase();
      final timeFormat = widgetTimeFormatForLocale(locale);
      final widgetData = computeWidgetPreviewData(
        times: times,
        locale: locale,
        now: now,
        timeFormat: timeFormat,
        tomorrowFajr: tomorrowFajr,
        jamaatTimes: jamaatTimes,
      );

      final hijriDate = HijriDateConverter.formatHijriDate(
        date,
        dayOffset: hijriOffsetDays,
        languageCode: localeCode,
      );
      final banglaDate = BanglaCalendar.fromGregorian(date);
      final islamicDate = localeCode == 'bn'
          ? LocaleDigits.localize('$hijriDate  |  $banglaDate', locale)
          : '$hijriDate  |  $banglaDate';
      final localizedLocation = _localizedLocationName(locationName, locale);

      await Future.wait([
        HomeWidget.saveWidgetData<String>('prayer_name', widgetData.prayerName),
        HomeWidget.saveWidgetData<String>('prayer_time', widgetData.prayerTime),
        HomeWidget.saveWidgetData<String>(
          'remaining_label',
          widgetData.remainingLabel,
        ),
        HomeWidget.saveWidgetData<int>(
          'next_prayer_epoch_millis',
          widgetData.nextPrayerEpochMillis,
        ),
        HomeWidget.saveWidgetData<bool>(
          'countdown_running',
          widgetData.countdownRunning,
        ),
        HomeWidget.saveWidgetData<String>(
          'jamaat_label',
          widgetData.jamaatLabel,
        ),
        HomeWidget.saveWidgetData<int>(
          'jamaat_epoch_millis',
          widgetData.jamaatEpochMillis,
        ),
        HomeWidget.saveWidgetData<bool>(
          'jamaat_countdown_running',
          widgetData.jamaatCountdownRunning,
        ),
        HomeWidget.saveWidgetData<bool>(
          'jamaat_time_style',
          widgetData.jamaatTextUsesTimeStyle,
        ),
        HomeWidget.saveWidgetData<int>(
          'jamaat_over_epoch_millis',
          widgetData.jamaatOverEpochMillis,
        ),
        HomeWidget.saveWidgetData<String>(
          'jamaat_value_text',
          widgetData.jamaatValueText,
        ),
        // 4 dynamic prayer row slots
        HomeWidget.saveWidgetData<String>(
          'row_label_1',
          widgetData.rowLabels[0],
        ),
        HomeWidget.saveWidgetData<String>('row_time_1', widgetData.rowTimes[0]),
        HomeWidget.saveWidgetData<String>(
          'row_label_2',
          widgetData.rowLabels[1],
        ),
        HomeWidget.saveWidgetData<String>('row_time_2', widgetData.rowTimes[1]),
        HomeWidget.saveWidgetData<String>(
          'row_label_3',
          widgetData.rowLabels[2],
        ),
        HomeWidget.saveWidgetData<String>('row_time_3', widgetData.rowTimes[2]),
        HomeWidget.saveWidgetData<String>(
          'row_label_4',
          widgetData.rowLabels[3],
        ),
        HomeWidget.saveWidgetData<String>('row_time_4', widgetData.rowTimes[3]),
        HomeWidget.saveWidgetData<String>('islamic_date', islamicDate),
        HomeWidget.saveWidgetData<String>('location', localizedLocation),
        HomeWidget.saveWidgetData<String>('locale_code', localeCode),
      ]);

      await HomeWidget.updateWidget(androidName: _androidWidgetName);
    } catch (e) {
      // Widget updates are best-effort, never block the app
    }
  }

  @visibleForTesting
  static DateFormat widgetTimeFormatForLocale(Locale locale) {
    final localeCode = locale.languageCode.toLowerCase();
    return DateFormat(_fmt, localeCode == 'bn' ? 'bn' : 'en');
  }

  static Future<void> forceRefresh({
    required Map<String, DateTime?> times,
    required String locationName,
    required DateTime date,
    required int hijriOffsetDays,
    DateTime? tomorrowFajr,
    Map<String, dynamic>? jamaatTimes,
  }) async {
    Locale locale;
    try {
      locale = AppLocaleController.instance.current;
    } catch (_) {
      final code = await LocalePrefs.read();
      locale = LocalePrefs.toLocale(code);
    }

    await updateWidgetData(
      times: times,
      locale: locale,
      locationName: locationName,
      date: date,
      hijriOffsetDays: hijriOffsetDays,
      tomorrowFajr: tomorrowFajr,
      jamaatTimes: jamaatTimes,
    );
  }

  @visibleForTesting
  static WidgetPreviewData computeWidgetPreviewData({
    required Map<String, DateTime?> times,
    required Locale locale,
    required DateTime now,
    required DateFormat timeFormat,
    DateTime? tomorrowFajr,
    Map<String, dynamic>? jamaatTimes,
  }) {
    final strings = AppText.of(locale);
    final engine = PrayerTimeEngine.instance;
    final currentPeriod = engine.getCurrentPrayerPeriod(times: times, now: now);
    final nextPeriod = engine.getNextPrayerForWidget(times: times, now: now);
    final currentMainPrayer = engine.getCurrentPrayerForWidget(
      times: times,
      now: now,
    );
    final isSunriseState = currentPeriod == 'Sunrise';
    final currentPeriodTime = times[currentPeriod];
    final todayNextTime = times[nextPeriod];

    // After Isha, next period falls back to "Fajr" but today's Fajr is in the
    // past. Use tomorrow's Fajr so the countdown remains valid.
    final effectiveNextTime =
        (todayNextTime != null && now.isBefore(todayNextTime))
        ? todayNextTime
        : tomorrowFajr;
    final countdownRunning =
        effectiveNextTime != null && now.isBefore(effectiveNextTime);
    final nextEpochMillis = countdownRunning
        ? effectiveNextTime.millisecondsSinceEpoch
        : 0;

    // Row 2 remains main-prayer focused and excludes the current main prayer.
    final rowPrayers = PrayerTimeEngine.mainPrayerOrder
        .where((p) => p != currentMainPrayer)
        .take(4)
        .toList();
    while (rowPrayers.length < 4) {
      rowPrayers.add('-');
    }
    final rowLabels = rowPrayers
        .map((name) => name == '-' ? '-' : _localizedPrayerName(locale, name))
        .toList(growable: false);
    final rowTimes = rowPrayers
        .map((name) => _formatPrayerTime(times[name], timeFormat, locale))
        .toList(growable: false);

    final remainingLabel = isSunriseState
        ? strings.widget_nextPrayerIn(_localizedPrayerName(locale, nextPeriod))
        : strings.widget_prayerEndsIn;
    final jamaatStatus = _computeJamaatWidgetState(
      now: now,
      locale: locale,
      timeFormat: timeFormat,
      currentPeriod: currentPeriod,
      currentMainPrayer: currentMainPrayer,
      nextPeriod: nextPeriod,
      times: times,
      jamaatTimes: jamaatTimes,
    );

    return WidgetPreviewData(
      prayerName: _localizedPrayerName(locale, currentPeriod),
      prayerTime: _formatPrayerTime(currentPeriodTime, timeFormat, locale),
      remainingLabel: remainingLabel,
      nextPrayerEpochMillis: nextEpochMillis,
      countdownRunning: countdownRunning,
      jamaatLabel: jamaatStatus.label,
      jamaatValueText: jamaatStatus.valueText,
      jamaatEpochMillis: jamaatStatus.epochMillis,
      jamaatCountdownRunning: jamaatStatus.countdownRunning,
      jamaatTextUsesTimeStyle: jamaatStatus.textUsesTimeStyle,
      jamaatOverEpochMillis: jamaatStatus.overEpochMillis,
      rowLabels: rowLabels,
      rowTimes: rowTimes,
    );
  }

  static String _localizedPrayerName(Locale locale, String prayerKey) {
    final strings = AppText.of(locale);
    switch (prayerKey) {
      case 'Fajr':
        return strings.prayer_fajr;
      case 'Sunrise':
        return strings.prayer_sunrise;
      case 'Dhuhr':
        return strings.prayer_dhuhr;
      case 'Asr':
        return strings.prayer_asr;
      case 'Maghrib':
        return strings.prayer_maghrib;
      case 'Isha':
        return strings.prayer_isha;
      default:
        return prayerKey;
    }
  }

  static String _formatPrayerTime(
    DateTime? time,
    DateFormat fmt,
    Locale locale,
  ) {
    final pattern = fmt.pattern ?? _fmt;
    return PrayerTimeEngine.instance.formatDisplayTime(
      time,
      pattern: pattern,
      languageCode: locale.languageCode,
    );
  }

  static String _localizedLocationName(String locationName, Locale locale) {
    var localized = locationName.trim();
    if (locale.languageCode.toLowerCase() != 'bn') {
      return localized;
    }

    for (final entry in _bnLocationPhraseMap.entries) {
      localized = localized.replaceAll(
        RegExp(RegExp.escape(entry.key), caseSensitive: false),
        entry.value,
      );
    }

    for (final entry in _bnLocationWordMap.entries) {
      localized = localized.replaceAll(
        RegExp('\\b${RegExp.escape(entry.key)}\\b', caseSensitive: false),
        entry.value,
      );
    }

    return LocaleDigits.localize(localized, locale);
  }

  static _JamaatWidgetState _computeJamaatWidgetState({
    required DateTime now,
    required Locale locale,
    required DateFormat timeFormat,
    required String currentPeriod,
    required String currentMainPrayer,
    required String nextPeriod,
    required Map<String, DateTime?> times,
    required Map<String, dynamic>? jamaatTimes,
  }) {
    if (currentPeriod == 'Sunrise') {
      return _computeSunriseJamaatWidgetState(
        now: now,
        locale: locale,
        timeFormat: timeFormat,
        nextPeriod: nextPeriod,
        jamaatTimes: jamaatTimes,
      );
    }

    final fajrTime = times['Fajr'];
    final isOvernightIsha =
        currentPeriod == 'Isha' && fajrTime != null && now.isBefore(fajrTime);
    if (isOvernightIsha) {
      return _JamaatWidgetState.over(locale);
    }

    final jamaatTime = _resolveTodayJamaatTime(
      now: now,
      prayerName: currentMainPrayer,
      jamaatTimes: jamaatTimes,
    );
    if (jamaatTime == null) {
      return _JamaatWidgetState.na(locale);
    }

    if (now.isBefore(jamaatTime)) {
      final strings = AppText.of(locale);
      return _JamaatWidgetState(
        label: strings.widget_jamaatInSuffix,
        valueText: '',
        epochMillis: jamaatTime.millisecondsSinceEpoch,
        countdownRunning: true,
        textUsesTimeStyle: false,
        overEpochMillis: jamaatTime.add(_jamaatOngoingWindow).millisecondsSinceEpoch,
      );
    }

    if (now.isBefore(jamaatTime.add(_jamaatOngoingWindow))) {
      return _JamaatWidgetState.ongoing(locale);
    }
    return _JamaatWidgetState.over(locale);
  }

  static _JamaatWidgetState _computeSunriseJamaatWidgetState({
    required DateTime now,
    required Locale locale,
    required DateFormat timeFormat,
    required String nextPeriod,
    required Map<String, dynamic>? jamaatTimes,
  }) {
    final sunriseNextPrayer =
        PrayerTimeEngine.mainPrayerOrder.contains(nextPeriod)
        ? nextPeriod
        : 'Dhuhr';
    final jamaatTime = _resolveTodayJamaatTime(
      now: now,
      prayerName: sunriseNextPrayer,
      jamaatTimes: jamaatTimes,
    );
    if (jamaatTime == null) {
      return _JamaatWidgetState.na(locale);
    }

    final strings = AppText.of(locale);
    final prayerLabel = _localizedPrayerName(locale, sunriseNextPrayer);
    final jamaatTimeLabel = _formatPrayerTime(jamaatTime, timeFormat, locale);
    return _JamaatWidgetState(
      label: strings.widget_nextPrayerJamaatAt(prayerLabel, jamaatTimeLabel),
      valueText: '',
      epochMillis: 0,
      countdownRunning: false,
      textUsesTimeStyle: false,
      overEpochMillis: 0,
    );
  }

  static DateTime? _resolveTodayJamaatTime({
    required DateTime now,
    required String prayerName,
    required Map<String, dynamic>? jamaatTimes,
  }) {
    if (jamaatTimes == null || jamaatTimes.isEmpty) {
      return null;
    }

    final jamaatKey = PrayerAuxCalculator.instance.getJamaatTimeKey(prayerName);
    final raw = jamaatTimes[jamaatKey];
    if (raw == null || raw.toString().trim().isEmpty) {
      return null;
    }

    final normalized = PrayerAuxCalculator.instance.formatJamaatTime(
      raw.toString(),
    );
    return _parseTodayJamaatTime(now, normalized);
  }

  static DateTime? _parseTodayJamaatTime(DateTime now, String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return DateTime(now.year, now.month, now.day, hour, minute);
  }
}

@immutable
class WidgetPreviewData {
  final String prayerName;
  final String prayerTime;
  final String remainingLabel;
  final int nextPrayerEpochMillis;
  final bool countdownRunning;
  final String jamaatLabel;
  final String jamaatValueText;
  final int jamaatEpochMillis;
  final bool jamaatCountdownRunning;
  final bool jamaatTextUsesTimeStyle;
  final int jamaatOverEpochMillis;
  final List<String> rowLabels;
  final List<String> rowTimes;

  const WidgetPreviewData({
    required this.prayerName,
    required this.prayerTime,
    required this.remainingLabel,
    required this.nextPrayerEpochMillis,
    required this.countdownRunning,
    required this.jamaatLabel,
    required this.jamaatValueText,
    required this.jamaatEpochMillis,
    required this.jamaatCountdownRunning,
    required this.jamaatTextUsesTimeStyle,
    required this.jamaatOverEpochMillis,
    required this.rowLabels,
    required this.rowTimes,
  });
}

@immutable
class _JamaatWidgetState {
  final String label;
  final String valueText;
  final int epochMillis;
  final bool countdownRunning;
  final bool textUsesTimeStyle;
  final int overEpochMillis;

  const _JamaatWidgetState({
    required this.label,
    required this.valueText,
    required this.epochMillis,
    required this.countdownRunning,
    required this.textUsesTimeStyle,
    required this.overEpochMillis,
  });

  factory _JamaatWidgetState.na(Locale locale) {
    final strings = AppText.of(locale);
    return _JamaatWidgetState(
      label: strings.widget_jamaatNA,
      valueText: '',
      epochMillis: 0,
      countdownRunning: false,
      textUsesTimeStyle: false,
      overEpochMillis: 0,
    );
  }

  factory _JamaatWidgetState.over(Locale locale) {
    final strings = AppText.of(locale);
    final baseLabel = _baseLabel(locale);
    return _JamaatWidgetState(
      label: baseLabel,
      valueText: _statusValue(
        fullLabel: strings.widget_jamaatOver,
        baseLabel: baseLabel,
      ),
      epochMillis: 0,
      countdownRunning: false,
      textUsesTimeStyle: true,
      overEpochMillis: 0,
    );
  }

  factory _JamaatWidgetState.ongoing(Locale locale) {
    final strings = AppText.of(locale);
    final baseLabel = _baseLabel(locale);
    return _JamaatWidgetState(
      label: baseLabel,
      valueText: _statusValue(
        fullLabel: strings.widget_jamaatOngoing,
        baseLabel: baseLabel,
      ),
      epochMillis: 0,
      countdownRunning: false,
      textUsesTimeStyle: true,
      overEpochMillis: 0,
    );
  }

  static String _baseLabel(Locale locale) {
    final seed = AppText.of(locale).widget_jamaatInSuffix.trim();
    final firstSpace = seed.indexOf(' ');
    if (firstSpace > 0) {
      return seed.substring(0, firstSpace).trim();
    }
    return seed;
  }

  static String _statusValue({
    required String fullLabel,
    required String baseLabel,
  }) {
    final full = fullLabel.trim();
    final base = baseLabel.trim();
    if (base.isNotEmpty && full.startsWith(base)) {
      final remainder = full.substring(base.length).trimLeft();
      if (remainder.isNotEmpty) {
        return remainder;
      }
    }
    final firstSpace = full.indexOf(' ');
    if (firstSpace > 0 && firstSpace < full.length - 1) {
      return full.substring(firstSpace + 1).trimLeft();
    }
    return full;
  }
}
