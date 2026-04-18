import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import '../core/app_locale_controller.dart';
import '../core/constants.dart';
import '../core/locale_text.dart';
import '../l10n/app_localizations.dart';
import '../models/location_config.dart';
import '../services/hijri_date_converter.dart';
import '../services/jamaat_service.dart';
import '../services/prayer_aux_calculator.dart';
import '../services/location_config_service.dart';
import '../services/prayer_time_engine.dart';
import '../services/settings_service.dart';
import '../utils/bangla_calendar.dart';
import '../widgets/calendar_selected_date_card.dart';

class _SelectedDateCardData {
  const _SelectedDateCardData({
    required this.gregorianDate,
    required this.weekday,
    required this.banglaDate,
    required this.hijriDate,
  });

  final String gregorianDate;
  final String weekday;
  final String banglaDate;
  final String hijriDate;
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const List<String> _prayerOrder = [
    'Fajr',
    'Sunrise',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];
  static const List<String> _hijriMonthsEnglish = [
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
  static const List<String> _hijriMonthsBangla = [
    'মুহাররম',
    'সফর',
    'রবিউল আউয়াল',
    'রবিউস সানি',
    'জুমাদাল উলা',
    'জুমাদাস সানি',
    'রজব',
    'শাবান',
    'রমজান',
    'শাওয়াল',
    'জিলকদ',
    'জিলহজ',
  ];

  final PrayerTimeEngine _prayerCalculationService = PrayerTimeEngine.instance;
  final JamaatService _jamaatService = JamaatService();
  final PrayerAuxCalculator _jamaatTimeUtility = PrayerAuxCalculator.instance;
  final LocationConfigService _locationConfigService = LocationConfigService();
  final SettingsService _settingsService = SettingsService();

  late DateTime _focusedDay;
  late DateTime _selectedDay;
  bool _isLoading = true;
  bool _isRefreshingDay = false;
  String? _errorMessage;

  LocationConfig? _locationConfig;
  Coordinates? _coordinates;
  CalculationParameters? _calculationParameters;
  String _locationLabel = AppConstants.defaultCity;
  int _bangladeshHijriOffsetDays =
      SettingsService.defaultBangladeshHijriOffsetDays;

  Map<String, DateTime?> _prayerTimes = <String, DateTime?>{};
  Map<String, dynamic>? _jamaatTimes;

  bool get _isEnglishCurrent =>
      AppLocaleController.instance.current.languageCode == 'en';

  String _trCurrent(String bn, String en) => _isEnglishCurrent ? en : bn;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _focusedDay = today;
    _selectedDay = today;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _loadDataForDay(
      _selectedDay,
      reloadLocation: true,
      forceRefreshServer: false,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadDataForDay(
    DateTime day, {
    required bool reloadLocation,
    required bool forceRefreshServer,
  }) async {
    try {
      if (reloadLocation ||
          _locationConfig == null ||
          _coordinates == null ||
          _calculationParameters == null) {
        await _loadLocationContext();
      }

      final normalizedDay = DateTime(day.year, day.month, day.day);
      final prayerTimes = PrayerTimes(
        coordinates: _coordinates!,
        date: normalizedDay,
        calculationParameters: _calculationParameters!,
        precision: true,
      );
      final prayerMap = _prayerCalculationService.createPrayerTimesMap(
        prayerTimes,
      );

      String? errorMessage;
      Map<String, dynamic>? jamaatMap;

      switch (_locationConfig!.jamaatSource) {
        case JamaatSource.server:
          try {
            final serverTimes = await _jamaatService.getJamaatTimes(
              city: _locationConfig!.cityName,
              date: normalizedDay,
              forceRefresh: forceRefreshServer,
            );

            if (serverTimes != null) {
              jamaatMap = Map<String, dynamic>.from(serverTimes);
              final maghribJamaat = _jamaatTimeUtility
                  .calculateMaghribJamaatTime(
                    maghribPrayerTime: prayerMap['Maghrib'],
                    selectedCity: _locationConfig!.cityName,
                  );
              if (maghribJamaat != '-') {
                jamaatMap['maghrib'] = maghribJamaat;
              }
            }
          } catch (_) {
            errorMessage = _trCurrent(
              'জামাতের সময় লোড করা যায়নি। নামাজের সময় দেখানো হচ্ছে।',
              'Jamaat times could not be loaded. Showing prayer times.',
            );
            jamaatMap = null;
          }
          break;
        case JamaatSource.localOffset:
          jamaatMap = PrayerAuxCalculator.instance.buildOffsetJamaatTimes(
            prayerTimes: prayerMap,
            offsets: _locationConfig!.jamaatOffsets,
          );
          break;
        case JamaatSource.none:
          jamaatMap = null;
          break;
      }

      if (!mounted) return;
      setState(() {
        _selectedDay = normalizedDay;
        _prayerTimes = prayerMap;
        _jamaatTimes = jamaatMap;
        _errorMessage = errorMessage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _trCurrent(
          'এই মুহূর্তে ক্যালেন্ডারের তথ্য লোড করা যাচ্ছে না।',
          'Unable to load calendar data right now.',
        );
      });
    }
  }

  Future<void> _loadLocationContext() async {
    final prefs = await SharedPreferences.getInstance();
    _bangladeshHijriOffsetDays = await _settingsService
        .getBangladeshHijriOffsetDays();

    LocationConfig? activeConfig = _locationConfigService.currentConfig;

    if (activeConfig == null) {
      final isGpsMode = prefs.getBool('is_gps_mode') ?? false;
      final savedCity = prefs.getString('selected_city');
      final lastLat = prefs.getDouble('last_latitude');
      final lastLng = prefs.getDouble('last_longitude');

      if (isGpsMode && lastLat != null && lastLng != null) {
        final locationName = prefs.getString('last_location_name') ?? 'GPS';
        activeConfig = LocationConfig.world(locationName, lastLat, lastLng);
      } else {
        activeConfig = _locationConfigService.getConfigForCity(
          savedCity ?? AppConstants.defaultCity,
        );
      }
    }

    final params = _prayerCalculationService.getCalculationParametersForConfig(
      activeConfig,
    );

    if (activeConfig.country == Country.bangladesh) {
      final madhab = await _settingsService.getMadhab();
      params.madhab = madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    }

    _locationConfigService.setCurrentConfig(activeConfig);
    _locationConfig = activeConfig;
    _coordinates = Coordinates(activeConfig.latitude, activeConfig.longitude);
    _calculationParameters = params;
    _locationLabel = _resolveLocationLabel(activeConfig, prefs);
  }

  String _resolveLocationLabel(
    LocationConfig activeConfig,
    SharedPreferences prefs,
  ) {
    if (activeConfig.country == Country.other) {
      return prefs.getString('last_location_name') ??
          _trCurrent('GPS লোকেশন', 'GPS Location');
    }
    return activeConfig.cityName;
  }

  Future<void> _refreshCalendarData() async {
    if (_isLoading || _isRefreshingDay) {
      return;
    }

    setState(() {
      _isRefreshingDay = true;
      _errorMessage = null;
    });

    await _loadDataForDay(
      _selectedDay,
      reloadLocation: true,
      forceRefreshServer: true,
    );

    if (!mounted) return;
    setState(() {
      _isRefreshingDay = false;
    });
  }

  Future<void> _onDaySelected(DateTime selectedDay, DateTime focusedDay) async {
    if (isSameDay(selectedDay, _selectedDay)) {
      return;
    }

    final normalized = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );

    setState(() {
      _selectedDay = normalized;
      _focusedDay = DateTime(focusedDay.year, focusedDay.month, focusedDay.day);
      _isRefreshingDay = true;
      _errorMessage = null;
    });

    await _loadDataForDay(
      normalized,
      reloadLocation: true,
      forceRefreshServer: false,
    );

    if (!mounted) return;
    setState(() {
      _isRefreshingDay = false;
    });
  }

  void _goToPreviousMonth() {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
    });
  }

  void _goToNextMonth() {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
    });
  }

  int get _effectiveHijriOffset {
    return _locationConfig?.country == Country.bangladesh
        ? _bangladeshHijriOffsetDays
        : 0;
  }

  String _calendarMonthLabel() {
    return DateFormat('MMMM yyyy').format(_focusedDay);
  }

  String _calendarHijriMonthLabel() {
    final monthStart = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final hijriDate = HijriDateConverter.toHijri(
      monthStart,
      dayOffset: _effectiveHijriOffset,
    );
    final monthList = _isEnglishCurrent
        ? _hijriMonthsEnglish
        : _hijriMonthsBangla;
    if (hijriDate.month < 1 || hijriDate.month > monthList.length) {
      return '${hijriDate.month} ${hijriDate.year} AH';
    }
    final monthName = monthList[hijriDate.month - 1];
    return '$monthName ${hijriDate.year} AH';
  }

  String _gregorianDateLine(DateTime day) {
    return DateFormat('d MMM yyyy').format(day);
  }

  String _weekdayLine(DateTime day) {
    return DateFormat('EEEE').format(day);
  }

  String _hijriDateLine(DateTime day) {
    return HijriDateConverter.formatHijriDate(
      day,
      dayOffset: _effectiveHijriOffset,
    );
  }

  String _banglaDateLine(DateTime day) {
    return BanglaCalendar.fromGregorian(day);
  }

  _SelectedDateCardData _selectedDateCardData(DateTime day) {
    return _SelectedDateCardData(
      gregorianDate: _gregorianDateLine(day),
      weekday: _weekdayLine(day),
      banglaDate: _banglaDateLine(day),
      hijriDate: _hijriDateLine(day),
    );
  }

  String _timesSourceCaption(BuildContext context) {
    if (_locationConfig?.jamaatSource == JamaatSource.none) {
      return context.tr(
        bn: 'GPS মোডে জামাত পাওয়া যায় না',
        en: 'Jamaat unavailable in GPS mode',
      );
    }
    if (_jamaatTimes == null || _jamaatTimes!.isEmpty) {
      return context.tr(
        bn: 'এই তারিখে জামাতের সময় পাওয়া যায় না',
        en: 'Jamaat unavailable for this date',
      );
    }
    return context.tr(
      bn: 'নির্বাচিত তারিখের নামাজ ও জামাতের সময়',
      en: 'Prayer + Jamaat Time for Selected Date',
    );
  }

  String _prayerDisplayName(BuildContext context, String prayerName) {
    final strings = AppLocalizations.of(context);
    switch (prayerName) {
      case 'Fajr':
        return strings.prayer_fajr;
      case 'Sunrise':
        return strings.prayer_sunrise;
      case 'Dhuhr':
        return context.isEnglish ? 'Zuhr' : strings.prayer_dhuhr;
      case 'Asr':
        return strings.prayer_asr;
      case 'Maghrib':
        return strings.prayer_maghrib;
      case 'Isha':
        return strings.prayer_isha;
      default:
        return prayerName;
    }
  }

  String _jamaatKeyForPrayer(String prayerName) {
    switch (prayerName) {
      case 'Fajr':
        return 'fajr';
      case 'Dhuhr':
        return 'dhuhr';
      case 'Asr':
        return 'asr';
      case 'Maghrib':
        return 'maghrib';
      case 'Isha':
        return 'isha';
      default:
        return prayerName.toLowerCase();
    }
  }

  String _formatHHmmTo12Hour(String value) {
    try {
      final parsed = DateFormat('HH:mm').parseStrict(value);
      return DateFormat('h:mm a').format(parsed);
    } catch (_) {
      return value;
    }
  }

  String _displayPrayerTimeForPrayer(String prayerName) {
    final prayerTime = _prayerTimes[prayerName];
    if (prayerTime == null) {
      return '--';
    }
    return DateFormat('h:mm a').format(prayerTime.toLocal());
  }

  String _displayJamaatTimeForPrayer(String prayerName) {
    if (prayerName == 'Sunrise') {
      return '-';
    }

    if (_jamaatTimes == null) {
      return '-';
    }

    final key = _jamaatKeyForPrayer(prayerName);
    final rawValue = _jamaatTimes![key];
    if (rawValue == null) {
      return '-';
    }

    final formatted = _jamaatTimeUtility.formatJamaatTime(rawValue.toString());
    if (formatted == '-') {
      return '-';
    }

    return _formatHHmmTo12Hour(formatted);
  }

  Widget _buildDayCell(
    BuildContext context,
    DateTime day, {
    required bool isSelected,
    required bool isToday,
    required bool isOutside,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final hijriDay = HijriDateConverter.toHijri(
      day,
      dayOffset: _effectiveHijriOffset,
    ).day;

    Color dayNumberColor;
    Color hijriColor;
    Color backgroundColor = Colors.transparent;
    Border? border;

    if (isSelected) {
      dayNumberColor = Colors.white;
      hijriColor = Colors.white.withValues(alpha: 0.8);
      backgroundColor = AppConstants.brandGreen;
    } else if (isToday) {
      dayNumberColor = AppConstants.brandGreenDark;
      hijriColor = AppConstants.brandGreenDark.withValues(alpha: 0.75);
      backgroundColor = AppConstants.brandGreen.withValues(alpha: 0.15);
      border = Border.all(
        color: AppConstants.brandGreen.withValues(alpha: 0.35),
      );
    } else if (isOutside) {
      dayNumberColor = isDarkMode ? Colors.white38 : Colors.black38;
      hijriColor = isDarkMode ? Colors.white30 : Colors.black26;
    } else {
      dayNumberColor = isDarkMode ? Colors.white : Colors.black87;
      hijriColor = isDarkMode ? Colors.white60 : Colors.black54;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: border,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: dayNumberColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$hijriDay',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 10,
                color: hijriColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDateCard(
    BuildContext context, {
    required Color cardBackground,
    required Color borderColor,
  }) {
    final dateData = _selectedDateCardData(_selectedDay);
    return CalendarSelectedDateCard(
      gregorianDate: dateData.gregorianDate,
      weekday: dateData.weekday,
      banglaDate: dateData.banglaDate,
      hijriDate: dateData.hijriDate,
      cardBackground: cardBackground,
      borderColor: borderColor,
    );
  }

  IconData _prayerIconForName(String prayerName) {
    switch (prayerName) {
      case 'Fajr':
        return Icons.wb_twilight_outlined;
      case 'Sunrise':
        return Icons.wb_sunny_outlined;
      case 'Dhuhr':
        return Icons.wb_sunny_outlined;
      case 'Asr':
        return Icons.wb_cloudy_outlined;
      case 'Maghrib':
        return Icons.nights_stay_outlined;
      case 'Isha':
        return Icons.dark_mode_outlined;
      default:
        return Icons.schedule_outlined;
    }
  }

  Widget _buildTimesHeader(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? AppConstants.brandGreenDark.withValues(alpha: 0.32)
            : AppConstants.brandGreen.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              context.tr(bn: 'নামাজ', en: 'Prayer'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? Colors.white : AppConstants.brandGreenDark,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              context.tr(bn: 'নামাজের সময়', en: 'Prayer Time'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? Colors.white : AppConstants.brandGreenDark,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              context.tr(bn: 'জামাতের সময়', en: 'Jamaat Time'),
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? Colors.white : AppConstants.brandGreenDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerRow(BuildContext context, String prayerName) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final prayerTime = _displayPrayerTimeForPrayer(prayerName);
    final jamaatTime = _displayJamaatTimeForPrayer(prayerName);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E2B22) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? AppConstants.brandGreen.withValues(alpha: 0.32)
              : AppConstants.brandGreen.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Icon(
                  _prayerIconForName(prayerName),
                  size: 16,
                  color: isDarkMode ? Colors.white70 : AppConstants.brandGreen,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _prayerDisplayName(context, prayerName),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              prayerTime,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    jamaatTime,
                    textAlign: TextAlign.end,
                    style: jamaatTime == '-'
                        ? TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white54 : Colors.black45,
                          )
                        : TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDarkMode
                                ? AppConstants.brandGreen.withValues(alpha: 0.9)
                                : AppConstants.brandGreenDark,
                          ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (jamaatTime != '-') ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.mosque,
                    size: 12,
                    color: isDarkMode
                        ? AppConstants.brandGreen.withValues(alpha: 0.9)
                        : AppConstants.brandGreenDark,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimesSection(
    BuildContext context, {
    required Color cardBackground,
    required Color borderColor,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 24,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _timesSourceCaption(context),
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode
                        ? Colors.white
                        : AppConstants.brandGreenDark,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 14,
                color: isDarkMode ? Colors.white60 : Colors.black54,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _locationLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white60 : Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTimesHeader(context),
          const SizedBox(height: 8),
          ..._prayerOrder.map(
            (prayerName) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildPrayerRow(context, prayerName),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardBackground = isDarkMode ? const Color(0xFF152018) : Colors.white;
    final borderColor = isDarkMode
        ? AppConstants.brandGreen.withValues(alpha: 0.38)
        : AppConstants.brandGreen.withValues(alpha: 0.24);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(bn: 'ক্যালেন্ডার', en: 'Calendar')),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _refreshCalendarData,
            icon: const Icon(Icons.refresh),
            tooltip: context.tr(bn: 'রিফ্রেশ', en: 'Refresh'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshCalendarData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  if (_isRefreshingDay) ...[
                    const LinearProgressIndicator(minHeight: 2),
                    const SizedBox(height: 12),
                  ],

                  Container(
                    decoration: BoxDecoration(
                      color: cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: _goToPreviousMonth,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _calendarMonthLabel(),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: isDarkMode
                                          ? Colors.white
                                          : AppConstants.brandGreenDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _calendarHijriMonthLabel(),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDarkMode
                                          ? Colors.white70
                                          : AppConstants.brandGreenDark
                                                .withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _goToNextMonth,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                        TableCalendar<void>(
                          firstDay: DateTime(2020, 1, 1),
                          lastDay: DateTime(2100, 12, 31),
                          focusedDay: _focusedDay,
                          currentDay: DateTime.now(),
                          selectedDayPredicate: (day) =>
                              isSameDay(day, _selectedDay),
                          availableCalendarFormats: {
                            CalendarFormat.month: context.tr(
                              bn: 'মাস',
                              en: 'Month',
                            ),
                          },
                          calendarFormat: CalendarFormat.month,
                          startingDayOfWeek: StartingDayOfWeek.sunday,
                          headerVisible: false,
                          daysOfWeekHeight: 30,
                          onPageChanged: (focusedDay) {
                            setState(() {
                              _focusedDay = DateTime(
                                focusedDay.year,
                                focusedDay.month,
                                focusedDay.day,
                              );
                            });
                          },
                          onDaySelected: _onDaySelected,
                          daysOfWeekStyle: DaysOfWeekStyle(
                            weekdayStyle: TextStyle(
                              color: isDarkMode
                                  ? Colors.white70
                                  : Colors.black54,
                              fontWeight: FontWeight.w700,
                            ),
                            weekendStyle: TextStyle(
                              color: isDarkMode
                                  ? Colors.white70
                                  : Colors.black54,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          calendarStyle: CalendarStyle(
                            outsideDaysVisible: true,
                            cellMargin: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 3,
                            ),
                            defaultDecoration: const BoxDecoration(),
                            todayDecoration: const BoxDecoration(),
                            selectedDecoration: const BoxDecoration(),
                            outsideDecoration: const BoxDecoration(),
                          ),
                          calendarBuilders: CalendarBuilders(
                            defaultBuilder: (context, day, focusedDay) {
                              return _buildDayCell(
                                context,
                                day,
                                isSelected: isSameDay(day, _selectedDay),
                                isToday: isSameDay(day, DateTime.now()),
                                isOutside: day.month != _focusedDay.month,
                              );
                            },
                            todayBuilder: (context, day, focusedDay) {
                              return _buildDayCell(
                                context,
                                day,
                                isSelected: isSameDay(day, _selectedDay),
                                isToday: true,
                                isOutside: day.month != _focusedDay.month,
                              );
                            },
                            selectedBuilder: (context, day, focusedDay) {
                              return _buildDayCell(
                                context,
                                day,
                                isSelected: true,
                                isToday: isSameDay(day, DateTime.now()),
                                isOutside: day.month != _focusedDay.month,
                              );
                            },
                            outsideBuilder: (context, day, focusedDay) {
                              return _buildDayCell(
                                context,
                                day,
                                isSelected: isSameDay(day, _selectedDay),
                                isToday: isSameDay(day, DateTime.now()),
                                isOutside: true,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildSelectedDateCard(
                    context,
                    cardBackground: cardBackground,
                    borderColor: borderColor,
                  ),
                  const SizedBox(height: 16),

                  _buildTimesSection(
                    context,
                    cardBackground: cardBackground,
                    borderColor: borderColor,
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
