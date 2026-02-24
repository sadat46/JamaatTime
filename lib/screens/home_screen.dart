import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:adhan_dart/adhan_dart.dart';
import 'dart:async';
import '../services/settings_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/jamaat_service.dart';
import '../services/location_config_service.dart';
import '../models/location_config.dart';
import '../services/prayer_calculation_service.dart';
import '../widgets/live_clock_widget.dart';
import '../widgets/prayer_countdown_widget.dart';
import '../widgets/sahri_iftar_widget.dart';
import '../widgets/forbidden_times_widget.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

// Extension to get date part only
extension DateTimeExtension on DateTime {
  DateTime toDate() {
    return DateTime(year, month, day);
  }
}

/// Row type for conditional styling
enum PrayerRowType {
  prayer,      // Standard prayer times (Fajr, Dhuhr, etc.)
  info,        // Informational rows (Sunrise, Dahwah-e-kubrah)
  sahriIftar,  // Sahri/Iftar rows (amber styling)
  forbidden,   // Forbidden time windows (red styling)
}

/// Pre-computed data for a prayer table row (avoids calculations in build())
class PrayerRowData {
  final String name;
  final String timeStr;
  final String jamaatStr;
  final bool isCurrent;
  final PrayerRowType type;
  final String? endTimeStr;  // For forbidden windows (shows range)

  const PrayerRowData({
    required this.name,
    required this.timeStr,
    required this.jamaatStr,
    required this.isCurrent,
    this.type = PrayerRowType.prayer,
    this.endTimeStr,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer;
  DateTime _now = DateTime.now();
  Coordinates? _coords;
  CalculationParameters? params;
  PrayerTimes? prayerTimes;
  Map<String, DateTime?> times = {};

  Map<String, dynamic>? jamaatTimes;
  bool isLoadingJamaat = false;
  String? jamaatError;
  DateTime? _lastJamaatUpdate;  // Track last successful jamaat times fetch
  DateTime selectedDate = DateTime.now(); // Add selected date for jamaat times

  final List<String> canttNames = AppConstants.canttNames;
  String? selectedCity;

  final SettingsService _settingsService = SettingsService();
  final LocationService _locationService = LocationService();
  final NotificationService _notificationService = NotificationService();
  final JamaatService _jamaatService = JamaatService();
  final LocationConfigService _locationConfigService = LocationConfigService();
  LocationConfig? _locationConfig;

  String? currentPlaceName;
  bool isFetchingPlaceName = false;

  // Add notification scheduling control
  bool _notificationsScheduled = false;
  DateTime _lastScheduledDate = DateTime.now().subtract(
    const Duration(days: 1),
  );

  // Pre-computed prayer table data (avoids recalculation in build())
  List<PrayerRowData> _prayerTableData = [];

  // Stream subscription for settings changes (must be cancelled in dispose)
  StreamSubscription<void>? _settingsSubscription;

  @override
  void initState() {
    super.initState();
    // Timezone initialization moved to main.dart for faster startup
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Note: Notification service is already initialized in main.dart
    // No need to initialize again here (singleton pattern handles this)

    selectedCity = AppConstants.defaultCity;

    // Get location config for selected city
    _locationConfig = _locationConfigService.getConfigForCity(selectedCity!);
    _locationConfigService.setCurrentConfig(_locationConfig!);

    // Pass config to notification service
    _notificationService.setLocationConfig(_locationConfig!);

    // Get calculation parameters based on location
    params = PrayerCalculationService.instance.getCalculationParametersForConfig(_locationConfig!);

    // Only apply madhab for Bangladesh (not applicable for Saudi)
    if (_locationConfig!.country == Country.bangladesh) {
      final madhab = await _settingsService.getMadhab();
      params!.madhab = madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    }

    // Initialize times with default values to avoid null issues
    final coords = Coordinates(
      _locationConfig!.latitude,
      _locationConfig!.longitude,
    );
    prayerTimes = PrayerTimes(
      coordinates: coords,
      date: _now,
      calculationParameters: params!,
      precision: true,
    );

    // Initialize times map
    times = {
      'Fajr': prayerTimes!.fajr,
      'Sunrise': prayerTimes!.sunrise,
      'Dahwah-e-kubrah': null, // Will be calculated later
      'Dhuhr': prayerTimes!.dhuhr,
      'Asr': prayerTimes!.asr,
      'Maghrib': prayerTimes!.maghrib,
      'Isha': prayerTimes!.isha,
    };

    // Fetch or calculate jamaat times based on location
    if (_locationConfig!.jamaatSource == JamaatSource.server) {
      await _fetchJamaatTimes(selectedCity!);
    } else if (_locationConfig!.jamaatSource == JamaatSource.localOffset) {
      _calculateLocalJamaatTimes();
    }
    await _loadLastLocation();

    // Initial prayer times calculation and notification scheduling
    _updatePrayerTimes();
    await _scheduleNotificationsIfNeeded();

    // Timer for background tasks only (checking day change, etc.)
    // Clock and countdown widgets now have their own timers
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final newNow = DateTime.now();
      final oldDay = DateTime(_now.year, _now.month, _now.day);
      final newDay = DateTime(newNow.year, newNow.month, newNow.day);

      // Check if day changed - need to recalculate prayer times
      if (newDay.isAfter(oldDay)) {
        _now = newNow;
        selectedDate = newNow;
        _updatePrayerTimes();
        if (selectedCity != null && _locationConfig != null) {
          if (_locationConfig!.jamaatSource == JamaatSource.server) {
            _fetchJamaatTimes(selectedCity!);
          } else if (_locationConfig!.jamaatSource == JamaatSource.localOffset) {
            _calculateLocalJamaatTimes();
          }
        }
      }
      _now = newNow;
    });

    // Single listener for all settings changes (combining madhab and notification settings)
    _settingsSubscription = _settingsService.onSettingsChanged.listen((_) async {
      await _loadMadhab();
      await _handleNotificationSettingsChange();
    });
  }

  Future<void> _fetchJamaatTimes(String city, {bool forceRefresh = false}) async {
    setState(() {
      isLoadingJamaat = true;
      jamaatError = null;
      jamaatTimes = null;
    });

    try {

      // Use JamaatService for consistent data structure
      final times = await _jamaatService.getJamaatTimes(
        city: city,
        date: selectedDate,
        forceRefresh: forceRefresh,
      );
      
      if (times != null) {
        // Create a complete jamaat times map including calculated Maghrib time
        final completeJamaatTimes = Map<String, dynamic>.from(times);

        // Add calculated Maghrib jamaat time to the map
        final maghribJamaatTime = _calculateMaghribJamaatTime();
        if (maghribJamaatTime != '-') {
          completeJamaatTimes['maghrib'] = maghribJamaatTime;
        }

        jamaatTimes = completeJamaatTimes;
        _lastJamaatUpdate = DateTime.now();  // Track successful fetch
        isLoadingJamaat = false;

        // Pre-compute table data after jamaat times update
        _computePrayerTableData();

        // Trigger UI update
        setState(() {});

        // Reset notification scheduling flag when jamaat times change
        _notificationsScheduled = false;
        await _scheduleNotificationsIfNeeded();
      } else {
        jamaatTimes = null;
        isLoadingJamaat = false;
        _computePrayerTableData();
        setState(() {});
      }
    } catch (e) {
      jamaatTimes = null;
      isLoadingJamaat = false;
      jamaatError = 'Error loading Jamaat times: $e';
      _computePrayerTableData();
      setState(() {});
    }
  }

  /// Calculate local jamaat times based on fixed offsets (for Saudi Arabia)
  void _calculateLocalJamaatTimes() {
    if (_locationConfig == null || _locationConfig!.jamaatOffsets == null) {
      return;
    }

    final offsets = _locationConfig!.jamaatOffsets!;
    final newJamaatTimes = <String, dynamic>{};

    // Map prayer names to offset keys
    final prayerMapping = {
      'fajr': 'Fajr',
      'dhuhr': 'Dhuhr',
      'asr': 'Asr',
      'maghrib': 'Maghrib',
      'isha': 'Isha',
    };

    for (final entry in offsets.entries) {
      final prayerKey = entry.key;
      final offset = entry.value;
      final prayerName = prayerMapping[prayerKey];

      if (prayerName != null && times[prayerName] != null) {
        final prayerTime = times[prayerName]!;
        final jamaatTime = prayerTime.add(Duration(minutes: offset));
        newJamaatTimes[prayerKey] = DateFormat('HH:mm').format(jamaatTime.toLocal());
      }
    }

    setState(() {
      jamaatTimes = newJamaatTimes;
      isLoadingJamaat = false;
      jamaatError = null;
    });

    _computePrayerTableData();
    _scheduleNotificationsIfNeeded();
  }

  void _updatePrayerTimes() {
    final coords = _coords ??
        (_locationConfig != null
            ? Coordinates(
                _locationConfig!.latitude,
                _locationConfig!.longitude,
              )
            : Coordinates(
                AppConstants.defaultLatitude,
                AppConstants.defaultLongitude,
              ));
    
    // Use selectedDate for prayer times calculation instead of _now
    final dateForCalculation = selectedDate;
    
    prayerTimes = PrayerTimes(
      coordinates: coords,
      date: dateForCalculation,
      calculationParameters: params!,
      precision: true,
    );
    final fajr = prayerTimes!.fajr;
    final sunrise = prayerTimes!.sunrise;
    final dhuhr = prayerTimes!.dhuhr;
    final asr = prayerTimes!.asr;
    final maghrib = prayerTimes!.maghrib;
    final isha = prayerTimes!.isha;

    // Calculate Dahwah-e-kubrah (midpoint between Fajr and Maghrib)
    DateTime? dahwaKubrah;
    if (fajr != null && maghrib != null) {
      final diff = maghrib.difference(fajr);
      dahwaKubrah = fajr.add(
        Duration(milliseconds: diff.inMilliseconds ~/ 2),
      );
    }

    times = {
      'Fajr': fajr,
      'Sunrise': sunrise,
      'Dahwah-e-kubrah': dahwaKubrah,
      'Dhuhr': dhuhr,
      'Asr': asr,
      'Maghrib': maghrib,
      'Isha': isha,
    };

    // Update jamaat times if they exist, to recalculate Maghrib jamaat time
    if (jamaatTimes != null) {
      final updatedJamaatTimes = Map<String, dynamic>.from(jamaatTimes!);
      final maghribJamaatTime = _calculateMaghribJamaatTime();
      if (maghribJamaatTime != '-') {
        updatedJamaatTimes['maghrib'] = maghribJamaatTime;
      }
      jamaatTimes = updatedJamaatTimes;

      // Reschedule notifications with updated times
      _notificationsScheduled = false;
      _scheduleNotificationsIfNeeded();
    }

    // Pre-compute table data after prayer times update
    _computePrayerTableData();
  }

  Future<void> _scheduleNotificationsIfNeeded() async {
    if (jamaatTimes == null) {
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDateOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    // Only schedule notifications for current date
    if (selectedDateOnly != today) {
      return;
    }

    // Schedule notifications if:
    // 1. Not scheduled yet today, OR
    // 2. Last scheduled date is different from today
    if (!_notificationsScheduled || _lastScheduledDate.isBefore(today)) {
      try {
        await _notificationService.scheduleAllNotifications(times, jamaatTimes);
        _notificationsScheduled = true;
        _lastScheduledDate = today;
      } catch (e) {
        // Handle error silently
      }
    }
  }

  /// Handle notification settings changes (like sound mode)
  Future<void> _handleNotificationSettingsChange() async {
    try {
      // Reset notification scheduling flag to force rescheduling
      _notificationsScheduled = false;
      
      // Reschedule notifications with new settings
      if (jamaatTimes != null) {
        await _scheduleNotificationsIfNeeded();
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadMadhab() async {
    // Only apply madhab for Bangladesh locations
    if (_locationConfig == null || _locationConfig!.country != Country.bangladesh) {
      return;
    }

    final madhab = await _settingsService.getMadhab();
    setState(() {
      params!.madhab = madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;

      // Set prayer time adjustments
      // In adhan_dart, adjustments is a Map<String, int>
      if (madhab == 'hanafi') {
        // For Hanafi, we might need a slight adjustment for more accuracy
        params!.adjustments = Map.from(AppConstants.defaultAdjustments);
      } else {
        // For Shafi, reset asr adjustment but keep isha adjustment
        params!.adjustments = {
          'asr': 0, // No adjustment for Asr time
          'isha': 2, // Small adjustment for Isha time
        };
      }

      _updatePrayerTimes();
    });
  }

  Future<void> _fetchUserLocation() async {
    // Set loading state once at the start
    _coords = null;
    isFetchingPlaceName = true;
    currentPlaceName = null;
    setState(() {});

    try {
      final position = await _locationService.getCurrentPosition();

      // Update coordinates immediately
      _coords = Coordinates(position.latitude, position.longitude);

      // Save and fetch place name in parallel with SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_latitude', position.latitude);
      await prefs.setDouble('last_longitude', position.longitude);

      // Fetch place name
      final place = await _locationService.getPlaceName(
        position.latitude,
        position.longitude,
      );

      // Detect country from coordinates
      final country = _locationConfigService.detectCountryFromCoordinates(
        position.latitude,
        position.longitude,
      );

      // Handle different country scenarios
      if (country == Country.other) {
        // REST OF WORLD: Create dynamic config for GPS location
        final placeName = place ?? 'Current Location';

        // Create world config
        _locationConfig = LocationConfig.world(
          placeName,
          position.latitude,
          position.longitude,
        );
        _locationConfigService.setCurrentConfig(_locationConfig!);
        _notificationService.setLocationConfig(_locationConfig!);

        // Update calculation parameters (no Bangladesh/Saudi adjustments)
        params = PrayerCalculationService.instance
            .getCalculationParametersForConfig(_locationConfig!);

        // Clear jamaat times - not available for random locations
        jamaatTimes = null;
        jamaatError = null;
        isLoadingJamaat = false;

        // Unselect city dropdown (user is in GPS mode)
        selectedCity = null;

        // Save GPS mode state
        await prefs.setBool('is_gps_mode', true);
        await prefs.remove('selected_city');
      } else if (country == Country.saudiArabia) {
        // SAUDI ARABIA: Find nearest city and use its config
        final nearestCity = _locationConfigService.getNearestSaudiCity(
          position.latitude,
          position.longitude,
        );

        if (nearestCity != null) {
          selectedCity = nearestCity;
          _locationConfig = _locationConfigService.getConfigForCity(nearestCity);
          _locationConfigService.setCurrentConfig(_locationConfig!);
          _notificationService.setLocationConfig(_locationConfig!);

          params = PrayerCalculationService.instance
              .getCalculationParametersForConfig(_locationConfig!);

          // Calculate local jamaat times for Saudi
          _calculateLocalJamaatTimes();

          await prefs.setBool('is_gps_mode', false);
          await prefs.setString('selected_city', nearestCity);
        }
      } else if (country == Country.bangladesh) {
        // BANGLADESH: Keep existing selected city or default
        // (User is physically in Bangladesh but using GPS)
        // Keep the selected city config, just update coordinates
        if (_locationConfig == null || _locationConfig!.country != Country.bangladesh) {
          selectedCity = AppConstants.defaultCity;
          _locationConfig = _locationConfigService.getConfigForCity(selectedCity!);
          _locationConfigService.setCurrentConfig(_locationConfig!);
          _notificationService.setLocationConfig(_locationConfig!);

          params = PrayerCalculationService.instance
              .getCalculationParametersForConfig(_locationConfig!);

          final madhab = await _settingsService.getMadhab();
          params!.madhab = madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;

          await _fetchJamaatTimes(selectedCity!);
        }
      }

      // Single setState for all success updates
      currentPlaceName = place;
      isFetchingPlaceName = false;
      _updatePrayerTimes();
      _computePrayerTableData();
      setState(() {});

      // Save last fetched location name
      if (place != null && place.isNotEmpty) {
        await prefs.setString('last_location_name', place);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location: ${position.latitude}, ${position.longitude}${place != null ? ' ($place)' : ''}',
          ),
        ),
      );
    } catch (e) {
      // On error, check if it's a permission error and prompt to open settings
      if (e.toString().contains('permission')) {
        await _locationService.openLocationSettings();
      }

      // On error, load last known location and coordinates
      final prefs = await SharedPreferences.getInstance();
      final lastPlace = prefs.getString('last_location_name');
      final lastLat = prefs.getDouble('last_latitude');
      final lastLng = prefs.getDouble('last_longitude');

      // Single setState for all error state updates
      isFetchingPlaceName = false;
      if (lastLat != null && lastLng != null) {
        _coords = Coordinates(lastLat, lastLng);
        _updatePrayerTimes();
      }
      if (lastPlace != null && lastPlace.isNotEmpty) {
        currentPlaceName = lastPlace;
      }
      _computePrayerTableData();
      setState(() {});

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Location error: $e')));
    }
  }

  Future<void> _loadLastLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lastPlace = prefs.getString('last_location_name');
    final lastLat = prefs.getDouble('last_latitude');
    final lastLng = prefs.getDouble('last_longitude');

    // Combine all state updates into a single setState
    bool needsUpdate = false;
    if (lastLat != null && lastLng != null) {
      _coords = Coordinates(lastLat, lastLng);
      _updatePrayerTimes();
      needsUpdate = true;
    }
    if (lastPlace != null && lastPlace.isNotEmpty) {
      currentPlaceName = lastPlace;
      needsUpdate = true;
    }
    if (needsUpdate) {
      _computePrayerTableData();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _settingsSubscription?.cancel();
    super.dispose();
  }

  String _getCurrentPrayerName() {
    // For selected date, we need to determine which prayer is current
    // If viewing a past date, show the last prayer of that day
    // If viewing today, show current prayer
    // If viewing future date, show first prayer (Fajr)
    
    final now = DateTime.now();
    final selectedDateOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final todayOnly = DateTime(now.year, now.month, now.day);
    
    if (selectedDateOnly.isBefore(todayOnly)) {
      // Past date - show last prayer (Isha)
      return 'Isha';
    } else if (selectedDateOnly.isAfter(todayOnly)) {
      // Future date - show first prayer (Fajr)
      return 'Fajr';
    } else {
      // Today - show current prayer
      final current = prayerTimes?.currentPrayer(date: _now);
      if (current == Prayer.fajr) return 'Fajr';
      if (current == Prayer.sunrise) return 'Sunrise';
      if (current == Prayer.dhuhr) return 'Dhuhr';
      if (current == Prayer.asr) return 'Asr';
      if (current == Prayer.maghrib) return 'Maghrib';
      if (current == Prayer.isha) return 'Isha';
      return 'Fajr';
    }
  }

  String _formatJamaatTime(String value) {
    value = value.trim();
    if (value.isEmpty) return '-';
    try {
      final time = DateFormat('HH:mm').parseStrict(value);
      return DateFormat('HH:mm').format(time);
    } catch (_) {
      try {
        final time = DateFormat('hh:mm a').parseStrict(value);
        return DateFormat('HH:mm').format(time);
      } catch (_) {
        return '-';
      }
    }
  }

  /// Get Maghrib offset in minutes based on cantt name
  int _getMaghribOffset(String city) {
    switch (city) {
      case 'Savar Cantt':
      case 'Dhaka Cantt':
      case 'Kumilla Cantt':
        return 13;
      case 'Rangpur Cantt':
      case 'Jashore Cantt':
      case 'Bogra Cantt':
        return 10;
      default:
        return 7;
    }
  }

  /// Calculate Maghrib jamaat time from prayer time with cantt-specific offset
  String _calculateMaghribJamaatTime() {
    final maghribPrayerTime = times['Maghrib'];
    if (maghribPrayerTime != null && selectedCity != null) {
      final offset = _getMaghribOffset(selectedCity!);

      // Use device local time to support global usage
      final maghribLocal = maghribPrayerTime.toLocal();
      final maghribJamaatTime = maghribLocal.add(Duration(minutes: offset));

      return DateFormat('HH:mm').format(maghribJamaatTime);
    }
    return '-';
  }

  /// Pre-compute prayer table data to avoid expensive calculations in build()
  void _computePrayerTableData() {
    final currentPrayer = _getCurrentPrayerName();
    final List<PrayerRowData> tableData = [];

    // Only Main Prayer Times (7 rows)
    const prayerNames = [
      'Fajr',
      'Sunrise',
      'Dahwah-e-kubrah',
      'Dhuhr',
      'Asr',
      'Maghrib',
      'Isha',
    ];

    for (final name in prayerNames) {
      // Compute time string using device local time
      final t = times[name];
      final timeStr = t != null
          ? DateFormat('HH:mm').format(t.toLocal())
          : '-';

      // Determine row type
      PrayerRowType type;
      if (name == 'Sunrise' || name == 'Dahwah-e-kubrah') {
        type = PrayerRowType.info;
      } else {
        type = PrayerRowType.prayer;
      }

      // Map prayer names to jamaat time keys
      String jamaatKey;
      switch (name) {
        case 'Fajr':
          jamaatKey = 'fajr';
          break;
        case 'Dhuhr':
          jamaatKey = 'dhuhr';
          break;
        case 'Asr':
          jamaatKey = 'asr';
          break;
        case 'Maghrib':
          jamaatKey = 'maghrib';
          break;
        case 'Isha':
          jamaatKey = 'isha';
          break;
        case 'Sunrise':
        case 'Dahwah-e-kubrah':
          jamaatKey = name.toLowerCase();
          break;
        default:
          jamaatKey = name.toLowerCase();
      }

      // Compute jamaat string
      String jamaatStr = '-';
      if (name == 'Maghrib') {
        jamaatStr = _calculateMaghribJamaatTime();
      } else if (jamaatTimes != null && jamaatTimes!.containsKey(jamaatKey)) {
        final value = jamaatTimes![jamaatKey];
        if (value != null && value.toString().isNotEmpty) {
          jamaatStr = _formatJamaatTime(value.toString());
        }
      }

      tableData.add(PrayerRowData(
        name: name,
        timeStr: timeStr,
        jamaatStr: jamaatStr,
        isCurrent: name == currentPrayer,
        type: type,
      ));
    }

    _prayerTableData = tableData;
  }

  /// Get row decoration based on row type
  BoxDecoration? _getRowDecoration(PrayerRowData row, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (row.type) {
      case PrayerRowType.forbidden:
        return BoxDecoration(
          color: isDark ? Colors.red.shade900.withValues(alpha: 0.3) : Colors.red.shade50,
        );
      case PrayerRowType.sahriIftar:
        return BoxDecoration(
          color: isDark ? Colors.orange.shade900.withValues(alpha: 0.3) : Colors.orange.shade50,
        );
      case PrayerRowType.prayer:
      case PrayerRowType.info:
        if (row.isCurrent) {
          return BoxDecoration(
            color: isDark ? Colors.green.shade900.withValues(alpha: 0.3) : Colors.green.shade100,
          );
        }
        return null;
    }
  }

  /// Build grouped city dropdown items (Bangladesh and Saudi Arabia)
  List<DropdownMenuItem<String>> _buildCityDropdownItems() {
    final items = <DropdownMenuItem<String>>[];

    // Bangladesh cities section
    items.add(const DropdownMenuItem(
      enabled: false,
      value: null,
      child: Text(
        '🇧🇩 Bangladesh',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    ));
    for (final city in AppConstants.bangladeshCities) {
      items.add(DropdownMenuItem(
        value: city,
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(city),
        ),
      ));
    }

    // Saudi Arabia cities section
    items.add(const DropdownMenuItem(
      enabled: false,
      value: null,
      child: Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          '🇸🇦 Saudi Arabia',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    ));
    for (final city in AppConstants.saudiCities) {
      items.add(DropdownMenuItem(
        value: city,
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(city),
        ),
      ));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, d MMM, yyyy').format(selectedDate);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxContentWidth = constraints.maxWidth < 600
            ? constraints.maxWidth
            : 600.0;
        final horizontalPadding = constraints.maxWidth < 400 ? 8.0 : 16.0;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Jamaat Time'),
            centerTitle: true,
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
            elevation: 2,
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: RefreshIndicator(
                onRefresh: () async {
                  if (selectedCity != null) {
                    await _fetchJamaatTimes(selectedCity!, forceRefresh: true);
                    _updatePrayerTimes();
                  }
                },
                color: Theme.of(context).colorScheme.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 8.0,
                    ),
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final maxCardWidth = constraints.maxWidth < 500
                            ? constraints.maxWidth
                            : 500.0;
                        return Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxCardWidth),
                            child: Card(
                              elevation: 4,
                              color: Theme.of(context).cardColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: constraints.maxWidth < 400
                                      ? 8.0
                                      : 16.0,
                                  vertical: 20.0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          _locationConfig != null &&
                                                  _locationConfig!.jamaatSource == JamaatSource.none
                                              ? 'GPS Location: '
                                              : 'Your Mosque at: ',
                                        ),
                                        if (_locationConfig == null ||
                                            _locationConfig!.jamaatSource != JamaatSource.none)
                                          DropdownButton<String>(
                                            value: selectedCity,
                                            items: _buildCityDropdownItems(),
                                            onChanged: (value) async {
                                            if (value == null || value == selectedCity) return;

                                            setState(() {
                                              selectedCity = value;
                                            });

                                            // Update location config
                                            _locationConfig = _locationConfigService.getConfigForCity(value);
                                            _locationConfigService.setCurrentConfig(_locationConfig!);
                                            _notificationService.setLocationConfig(_locationConfig!);

                                            // Update calculation parameters
                                            params = PrayerCalculationService.instance.getCalculationParametersForConfig(_locationConfig!);

                                            // Only apply madhab for Bangladesh
                                            if (_locationConfig!.country == Country.bangladesh) {
                                              final madhab = await _settingsService.getMadhab();
                                              params!.madhab = madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
                                            }

                                            // Cancel existing notifications and reschedule
                                            _notificationsScheduled = false;

                                            // Update coordinates for the new location
                                            _coords = Coordinates(
                                              _locationConfig!.latitude,
                                              _locationConfig!.longitude,
                                            );

                                            // Recalculate prayer times
                                            _updatePrayerTimes();

                                            // Fetch/calculate jamaat times based on location
                                            if (_locationConfig!.jamaatSource == JamaatSource.server) {
                                              await _fetchJamaatTimes(value);
                                            } else if (_locationConfig!.jamaatSource == JamaatSource.localOffset) {
                                              _calculateLocalJamaatTimes();
                                            }
                                          },
                                        ),
                                        // Show current location name in GPS mode
                                        if (_locationConfig != null &&
                                            _locationConfig!.jamaatSource == JamaatSource.none)
                                          Flexible(
                                            child: Text(
                                              currentPlaceName ?? 'Detecting...',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          dateStr,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.access_time,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 4),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                right: 12.0,
                                              ),
                                              child: LiveClockWidget(
                                                textStyle: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.copyWith(
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // Jamaat times status
                                    if (isLoadingJamaat)
                                      const Row(
                                        children: [
                                          SizedBox(width: 16),
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                          SizedBox(width: 8),
                                          Text('Loading jamaat times...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                        ],
                                      ),
                                    if (jamaatError != null)
                                      Row(
                                        children: [
                                          const SizedBox(width: 16),
                                          const Icon(Icons.error, size: 16, color: Colors.red),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              jamaatError!,
                                              style: const TextStyle(fontSize: 12, color: Colors.red),
                                            ),
                                          ),
                                        ],
                                      ),
                                    // Show message when jamaat times not available (GPS mode in unsupported location)
                                    if (_locationConfig != null &&
                                        _locationConfig!.jamaatSource == JamaatSource.none &&
                                        !isLoadingJamaat &&
                                        jamaatError == null)
                                      Row(
                                        children: [
                                          const SizedBox(width: 16),
                                          const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '📍 GPS Mode: Jamaat times not available for this location',
                                              style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                                            ),
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.access_time, size: 18),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              right: 24.0,
                                            ),
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: PrayerCountdownWidget(
                                                prayerTimes: times,
                                                selectedDate: selectedDate,
                                                coordinates: _coords,
                                                calculationParams: params,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.my_location),
                                          onPressed: _fetchUserLocation,
                                        ),
                                        Expanded(
                                          child: currentPlaceName != null
                                              ? SingleChildScrollView(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  child: Text(
                                                    currentPlaceName!,
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodyMedium,
                                                    overflow:
                                                        TextOverflow.visible,
                                                  ),
                                                )
                                              : isFetchingPlaceName
                                              ? const Padding(
                                                  padding: EdgeInsets.only(
                                                    left: 8.0,
                                                  ),
                                                  child: SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'Prayer Times',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF2E7D32),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_lastJamaatUpdate != null && !isLoadingJamaat)
                          Text(
                            'Last updated: ${DateFormat('HH:mm').format(_lastJamaatUpdate!)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (isLoadingJamaat)
                      const Center(child: CircularProgressIndicator()),
                    if (jamaatError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          jamaatError!,
                          style: const TextStyle(color: Colors.orange),
                        ),
                      ),
                    Table(
                      border: TableBorder.all(color: Colors.grey.shade300),
                      columnWidths: const {
                        0: FlexColumnWidth(3),
                        1: FlexColumnWidth(3),
                        2: FlexColumnWidth(3),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF145A32)
                                : const Color(0xFF43A047),
                          ),
                          children: const [
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Prayer Name',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Prayer Time',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Jamaat Time',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        // Use pre-computed prayer table data (avoids expensive calculations in build)
                        ..._prayerTableData.map((row) => TableRow(
                          decoration: _getRowDecoration(row, context),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(row.name),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Center(
                                child: Text(
                                  row.timeStr,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      row.jamaatStr,
                                      style: row.jamaatStr == '-'
                                          ? const TextStyle(color: Colors.grey)
                                          : (row.type == PrayerRowType.forbidden
                                              ? const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)
                                              : const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                    ),
                                    if (row.jamaatStr != '-' && row.type != PrayerRowType.forbidden) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.mosque, size: 12, color: Colors.green),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Sahri & Iftar Times Table
                    SahriIftarWidget(
                      fajrTime: times['Fajr'],
                      maghribTime: times['Maghrib'],
                    ),
                    const SizedBox(height: 24),

                    // Forbidden Prayer Times Table
                    ForbiddenTimesWidget(
                      prayerTimes: prayerTimes,
                    ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
}
