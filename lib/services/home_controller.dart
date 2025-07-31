import 'package:flutter/material.dart';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../core/constants.dart';
import 'settings_service.dart';
import 'location_service.dart';
import 'notification_service.dart';
import 'jamaat_service.dart';

class HomeController {
  // Services
  final SettingsService _settingsService = SettingsService();
  final LocationService _locationService = LocationService();
  final NotificationService _notificationService = NotificationService();
  final JamaatService _jamaatService = JamaatService();

  // State variables
  Timer? _timer;
  DateTime _now = DateTime.now();
  Coordinates? _coords;
  CalculationParameters? params;
  PrayerTimes? prayerTimes;
  Map<String, DateTime?> times = {};

  // ValueNotifiers for UI updates
  final ValueNotifier<DateTime> timeNotifier = ValueNotifier(DateTime.now());
  final ValueNotifier<Duration> countdownNotifier = ValueNotifier(Duration.zero);

  // Jamaat times
  Map<String, dynamic>? jamaatTimes;
  bool isLoadingJamaat = false;
  String? jamaatError;

  // UI state
  String? selectedCity;
  String? currentPlaceName;
  bool isFetchingPlaceName = false;
  DateTime selectedDate = DateTime.now();

  // Notification control
  bool _notificationsScheduled = false;
  DateTime _lastScheduledDate = DateTime.now().subtract(const Duration(days: 1));

  // Getters
  Map<String, DateTime?> get prayerTimesMap => times;
  Map<String, dynamic>? get jamaatTimesData => jamaatTimes;
  bool get isJamaatLoading => isLoadingJamaat;
  String? get jamaatErrorMessage => jamaatError;
  String? get currentLocation => currentPlaceName;
  bool get isLocationLoading => isFetchingPlaceName;
  String? get currentCity => selectedCity;

  /// Initialize the controller
  Future<void> initialize() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(AppConstants.defaultTimeZone));
    
    await _initializeServices();
    await _loadInitialData();
    _startTimer();
    _setupListeners();
  }

  /// Initialize services
  Future<void> _initializeServices() async {
    try {
      await _notificationService.initialize();
      debugPrint('Notification service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing notification service: $e');
    }
  }

  /// Load initial data
  Future<void> _loadInitialData() async {
    // Initialize prayer calculation parameters
    params = CalculationMethod.muslimWorldLeague();
    final madhab = await _settingsService.getMadhab();
    params!.madhab = madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    params!.adjustments = Map.from(AppConstants.defaultAdjustments);

    selectedCity = AppConstants.defaultCity;

    // Initialize prayer times
    final coords = Coordinates(
      AppConstants.defaultLatitude,
      AppConstants.defaultLongitude,
    );
    prayerTimes = PrayerTimes(
      coordinates: coords,
      date: _now,
      calculationParameters: params!,
      precision: true,
    );

    times = {
      'Fajr': prayerTimes!.fajr,
      'Sunrise': prayerTimes!.sunrise,
      'Dahwah-e-kubrah': null,
      'Dhuhr': prayerTimes!.dhuhr,
      'Asr': prayerTimes!.asr,
      'Maghrib': prayerTimes!.maghrib,
      'Isha': prayerTimes!.isha,
    };

    await _fetchJamaatTimes(selectedCity!);
    await _loadLastLocation();
    _updatePrayerTimes();
    await _scheduleNotificationsIfNeeded();
    await _checkNotificationStatus();
  }

  /// Start timer for updates
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      final newNow = DateTime.now();
      timeNotifier.value = newNow;
      countdownNotifier.value = _getTimeToNextPrayer();
      _now = newNow;
    });
  }

  /// Setup listeners
  void _setupListeners() {
    _settingsService.onSettingsChanged.listen((_) => _loadMadhab());
    _settingsService.onSettingsChanged.listen((_) async {
      await _handleNotificationSettingsChange();
    });
  }

  /// Dispose resources
  void dispose() {
    _timer?.cancel();
    timeNotifier.dispose();
    countdownNotifier.dispose();
  }

  /// Fetch jamaat times
  Future<void> _fetchJamaatTimes(String city) async {
    isLoadingJamaat = true;
    jamaatError = null;
    jamaatTimes = null;

    try {
      final times = await _jamaatService.getJamaatTimes(
        city: city,
        date: selectedDate,
      );

      if (times != null) {
        final completeJamaatTimes = Map<String, dynamic>.from(times);
        final maghribJamaatTime = _calculateMaghribJamaatTime();
        if (maghribJamaatTime != '-') {
          completeJamaatTimes['maghrib'] = maghribJamaatTime;
        }

        jamaatTimes = completeJamaatTimes;
        _notificationsScheduled = false;
        await _scheduleNotificationsIfNeeded();
      }
    } catch (e) {
      jamaatError = 'Error loading Jamaat times: $e';
    } finally {
      isLoadingJamaat = false;
    }
  }

  /// Update prayer times
  void _updatePrayerTimes() {
    final coords = _coords ?? Coordinates(
      AppConstants.defaultLatitude,
      AppConstants.defaultLongitude,
    );

    prayerTimes = PrayerTimes(
      coordinates: coords,
      date: selectedDate,
      calculationParameters: params!,
      precision: true,
    );

    final fajr = prayerTimes!.fajr;
    final sunrise = prayerTimes!.sunrise;
    final dhuhr = prayerTimes!.dhuhr;
    final asr = prayerTimes!.asr;
    final maghrib = prayerTimes!.maghrib;
    final isha = prayerTimes!.isha;

    DateTime? dahwaKubrah;
    if (sunrise != null && dhuhr != null) {
      final diff = dhuhr.difference(sunrise);
      dahwaKubrah = sunrise.add(
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

    // Update jamaat times if they exist
    if (jamaatTimes != null) {
      final updatedJamaatTimes = Map<String, dynamic>.from(jamaatTimes!);
      final maghribJamaatTime = _calculateMaghribJamaatTime();
      if (maghribJamaatTime != '-') {
        updatedJamaatTimes['maghrib'] = maghribJamaatTime;
      }
      jamaatTimes = updatedJamaatTimes;
      _notificationsScheduled = false;
      _scheduleNotificationsIfNeeded();
    }
  }

  /// Calculate Maghrib jamaat time
  String _calculateMaghribJamaatTime() {
    final maghribPrayerTime = times['Maghrib'];
    if (maghribPrayerTime != null && selectedCity != null) {
      final offset = _getMaghribOffset(selectedCity!);
      final localMaghribTime = maghribPrayerTime.toLocal();
      final maghribJamaatTime = localMaghribTime.add(Duration(minutes: offset));
      return DateFormat('HH:mm').format(maghribJamaatTime);
    }
    return '-';
  }

  /// Get Maghrib offset
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

  /// Get current prayer name
  String getCurrentPrayerName() {
    final now = DateTime.now();
    final selectedDateOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final todayOnly = DateTime(now.year, now.month, now.day);

    if (selectedDateOnly.isBefore(todayOnly)) {
      return 'Isha';
    } else if (selectedDateOnly.isAfter(todayOnly)) {
      return 'Fajr';
    } else {
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

  /// Get time to next prayer
  Duration _getTimeToNextPrayer() {
    final now = _now;
    final order = [
      'Fajr',
      'Sunrise',
      'Dahwah-e-kubrah',
      'Dhuhr',
      'Asr',
      'Maghrib',
      'Isha',
    ];
    for (final name in order) {
      final t = times[name];
      if (t != null && now.isBefore(t)) {
        return t.difference(now);
      }
    }
    final tomorrow = now.add(const Duration(days: 1));
    final coords = _coords ?? Coordinates(23.8376, 90.2820);
    final tomorrowPrayerTimes = PrayerTimes(
      coordinates: coords,
      date: tomorrow,
      calculationParameters: params!,
      precision: true,
    );
    final tomorrowFajr = tomorrowPrayerTimes.fajr;
    return tomorrowFajr != null
        ? tomorrowFajr.difference(now)
        : const Duration();
  }

  /// Get countdown text
  String getCountdownText() {
    final currentPrayer = getCurrentPrayerName();
    final timeToNext = _getTimeToNextPrayer();
    final now = DateTime.now();
    final selectedDateOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final todayOnly = DateTime(now.year, now.month, now.day);

    if (selectedDateOnly.isBefore(todayOnly)) {
      return 'Viewing past date: ${DateFormat('dd MMM yyyy').format(selectedDate)}';
    } else if (selectedDateOnly.isAfter(todayOnly)) {
      return 'Viewing future date: ${DateFormat('dd MMM yyyy').format(selectedDate)}';
    } else {
      if (currentPrayer == 'Sunrise') {
        return 'Coming Dahwa-e-kubrah';
      } else if (currentPrayer == 'Dahwah-e-kubrah') {
        return 'Coming Dhuhr';
      } else {
        String countdown = timeToNext.isNegative
            ? '--:--'
            : '${timeToNext.inHours.toString().padLeft(2, '0')}:${(timeToNext.inMinutes.remainder(60)).toString().padLeft(2, '0')}';
        return '$currentPrayer time remaining: $countdown';
      }
    }
  }

  /// Load madhab setting
  Future<void> _loadMadhab() async {
    final madhab = await _settingsService.getMadhab();
    params!.madhab = madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;

    if (madhab == 'hanafi') {
      params!.adjustments = Map.from(AppConstants.defaultAdjustments);
    } else {
      params!.adjustments = {
        'asr': 0,
        'isha': 2,
      };
    }

    _updatePrayerTimes();
  }

  /// Fetch user location
  Future<void> fetchUserLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      _coords = Coordinates(position.latitude, position.longitude);
      isFetchingPlaceName = true;
      currentPlaceName = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_latitude', position.latitude);
      await prefs.setDouble('last_longitude', position.longitude);

      final place = await _locationService.getPlaceName(
        position.latitude,
        position.longitude,
      );
      currentPlaceName = place;
      isFetchingPlaceName = false;

      _updatePrayerTimes();

      if (place != null && place.isNotEmpty) {
        await prefs.setString('last_location_name', place);
      }
    } catch (e) {
      isFetchingPlaceName = false;
      if (e.toString().contains('permission')) {
        await _locationService.openLocationSettings();
      }
      await _loadLastLocation();
    }
  }

  /// Load last known location
  Future<void> _loadLastLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lastPlace = prefs.getString('last_location_name');
    final lastLat = prefs.getDouble('last_latitude');
    final lastLng = prefs.getDouble('last_longitude');

    if (lastLat != null && lastLng != null) {
      _coords = Coordinates(lastLat, lastLng);
      _updatePrayerTimes();
    }
    if (lastPlace != null && lastPlace.isNotEmpty) {
      currentPlaceName = lastPlace;
    }
  }

  /// Change selected city
  Future<void> changeCity(String? city) async {
    selectedCity = city;
    if (selectedCity != null) {
      await _fetchJamaatTimes(selectedCity!);
      _updatePrayerTimes();
    }
  }

  /// Schedule notifications if needed
  Future<void> _scheduleNotificationsIfNeeded() async {
    if (jamaatTimes == null) {
      debugPrint('Jamaat times is null, skipping notification scheduling');
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDateOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    if (selectedDateOnly != today) {
      debugPrint('Selected date ($selectedDateOnly) is not today ($today), skipping notification scheduling');
      return;
    }

    if (!_notificationsScheduled || _lastScheduledDate.isBefore(today)) {
      try {
        debugPrint('Scheduling notifications for today: $today');
        debugPrint('Jamaat times: $jamaatTimes');
        debugPrint('Prayer times: $times');
        await _notificationService.scheduleAllNotifications(times, jamaatTimes);
        _notificationsScheduled = true;
        _lastScheduledDate = today;
        debugPrint('Notifications scheduled successfully');
      } catch (e) {
        debugPrint('Error scheduling notifications: $e');
      }
    } else {
      debugPrint('Notifications already scheduled for today');
    }
  }

  /// Handle notification settings change
  Future<void> _handleNotificationSettingsChange() async {
    try {
      _notificationsScheduled = false;
      if (jamaatTimes != null) {
        await _scheduleNotificationsIfNeeded();
      }
    } catch (e) {
      debugPrint('Error updating settings: $e');
    }
  }

  /// Check notification status
  Future<void> _checkNotificationStatus() async {
    try {
      final isEnabled = await _notificationService.areNotificationsEnabled();
      final isReady = await _notificationService.isReady();
      final isInitialized = _notificationService.isInitialized;

      debugPrint('Notification Status:');
      debugPrint('- Enabled: $isEnabled');
      debugPrint('- Ready: $isReady');
      debugPrint('- Initialized: $isInitialized');
      debugPrint('- Jamaat Times: ${jamaatTimes != null ? 'Loaded' : 'Not loaded'}');
      debugPrint('- Selected Date: $selectedDate');
      debugPrint('- Current Date: ${DateTime.now()}');

      if (!isEnabled) {
        debugPrint('WARNING: Notifications are not enabled on this device');
      }
      if (!isInitialized) {
        debugPrint('WARNING: Notification service is not initialized');
      }
    } catch (e) {
      debugPrint('Error checking notification status: $e');
    }
  }

  // Debug methods
  Future<void> checkPendingNotifications() async {
    try {
      final pendingNotifications = await _notificationService.getPendingNotifications();
      debugPrint('Pending notifications: ${pendingNotifications.length}');
      for (final notification in pendingNotifications) {
        debugPrint('Pending: ID=${notification.id}, Title=${notification.title}');
      }
    } catch (e) {
      debugPrint('Error checking pending notifications: $e');
    }
  }

  Future<void> scheduleTestJamaatNotification() async {
    try {
      final now = DateTime.now();
      final testTime = now.add(const Duration(minutes: 2));

      await _notificationService.scheduleNotification(
        id: 9999,
        title: 'Test Jamaat',
        body: 'This is a test jamaat notification',
        scheduledTime: testTime,
        notificationType: 'jamaat',
      );

      debugPrint('Test jamaat notification scheduled for: $testTime');
    } catch (e) {
      debugPrint('Error scheduling test jamaat notification: $e');
    }
  }

  Future<void> rescheduleNotifications() async {
    debugPrint('Manual notification scheduling test');
    debugPrint('Current jamaat times: $jamaatTimes');
    debugPrint('Current prayer times: $times');
    await _scheduleNotificationsIfNeeded();
  }

  Future<void> showTestNotification() async {
    await _notificationService.showTestNotification();
  }
} 