import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:adhan_dart/adhan_dart.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/settings_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/jamaat_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import '../core/constants.dart';

// Extension to get date part only
extension DateTimeExtension on DateTime {
  DateTime toDate() {
    return DateTime(year, month, day);
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Timer _timer;
  DateTime _now = DateTime.now();
  Coordinates? _coords;
  late CalculationParameters params;
  late PrayerTimes prayerTimes;
  late Map<String, DateTime?> times;

  Map<String, dynamic>? jamaatTimes;
  bool isLoadingJamaat = false;
  String? jamaatError;
  DateTime selectedDate = DateTime.now(); // Add selected date for jamaat times

  final List<String> canttNames = AppConstants.canttNames;
  String? selectedCity;

  final SettingsService _settingsService = SettingsService();
  final LocationService _locationService = LocationService();
  final NotificationService _notificationService = NotificationService();
  final JamaatService _jamaatService = JamaatService();

  String? currentPlaceName;
  bool isFetchingPlaceName = false;

  // Add notification scheduling control
  bool _notificationsScheduled = false;
  DateTime _lastScheduledDate = DateTime.now().subtract(
    const Duration(days: 1),
  );

  @override
  void initState() {
    super.initState();
    developer.log('HomeScreen initState', name: 'HomeScreen');
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(AppConstants.defaultTimeZone));
    // Ensure notification service is initialized with context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().initialize(context);
    });
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    developer.log('Initializing app', name: 'HomeScreen');
    developer.log('Notifications initialized', name: 'HomeScreen');

    // Use more accurate parameters for Bangladesh
    // Start with Muslim World League method which is generally more accurate for South Asia
    params = CalculationMethod.muslimWorldLeague();
    // Load madhab setting immediately to ensure correct Asr calculation
    final madhab = await _settingsService.getMadhab();
    params.madhab = madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;

    // Set prayer time adjustments
    // In adhan_dart, adjustments is a Map<String, int>
    params.adjustments = Map.from(AppConstants.defaultAdjustments);

    selectedCity = AppConstants.defaultCity;

    // Initialize times with default values to avoid null issues
    final coords = Coordinates(
      AppConstants.defaultLatitude,
      AppConstants.defaultLongitude,
    ); // Default coordinates
    prayerTimes = PrayerTimes(
      coordinates: coords,
      date: _now,
      calculationParameters: params,
      precision: true,
    );

    // Initialize times map
    times = {
      'Fajr': prayerTimes.fajr,
      'Sunrise': prayerTimes.sunrise,
      'Dahwah-e-kubrah': null, // Will be calculated later
      'Dhuhr': prayerTimes.dhuhr,
      'Asr': prayerTimes.asr,
      'Maghrib': prayerTimes.maghrib,
      'Isha': prayerTimes.isha,
    };

    await _fetchJamaatTimes(selectedCity!);
    await _loadLastLocation();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final newNow = DateTime.now();
      
      setState(() {
        _now = newNow;
        _updatePrayerTimes();
      });
    });

    _settingsService.onSettingsChanged.listen((_) => _loadMadhab());
    
    // Listen for notification sound mode changes and reschedule notifications
    _settingsService.onSettingsChanged.listen((_) async {
      // Check if notification sound mode changed and reschedule if needed
      await _handleNotificationSettingsChange();
    });
  }

  Future<void> _fetchJamaatTimes(String city) async {
    setState(() {
      isLoadingJamaat = true;
      jamaatError = null;
      jamaatTimes = null;
    });
    
    try {
      developer.log('Fetching jamaat times for city: $city, date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}', name: 'HomeScreen');
      
      // Use JamaatService for consistent data structure
      final times = await _jamaatService.getJamaatTimes(
        city: city,
        date: selectedDate,
      );
      
      if (times != null) {
        developer.log('Loaded jamaat times for $city: $times', name: 'HomeScreen');
        developer.log('Available keys: ${times.keys.toList()}', name: 'HomeScreen');
        
        setState(() {
          jamaatTimes = times;
          isLoadingJamaat = false;
        });
        
        // Reset notification scheduling flag when jamaat times change
        _notificationsScheduled = false;
        await _scheduleNotificationsIfNeeded();
      } else {
        setState(() {
          jamaatTimes = null;
          isLoadingJamaat = false;
        });
        developer.log('No jamaat times found for $city', name: 'HomeScreen');
      }
    } catch (e) {
      setState(() {
        jamaatTimes = null;
        isLoadingJamaat = false;
        jamaatError = 'Error loading Jamaat times: $e';
      });
      developer.log('Error loading jamaat times for $city: $e', name: 'HomeScreen');
    }
  }



  void _updatePrayerTimes() {
    final coords =
        _coords ??
        Coordinates(
          AppConstants.defaultLatitude,
          AppConstants.defaultLongitude,
        );
    
    // Use selectedDate for prayer times calculation instead of _now
    final dateForCalculation = selectedDate;
    
    prayerTimes = PrayerTimes(
      coordinates: coords,
      date: dateForCalculation,
      calculationParameters: params,
      precision: true,
    );
    final fajr = prayerTimes.fajr;
    final sunrise = prayerTimes.sunrise;
    final dhuhr = prayerTimes.dhuhr;
    final asr = prayerTimes.asr;
    final maghrib = prayerTimes.maghrib;
    final isha = prayerTimes.isha;

    // Calculate Dahwah-e-kubrah as midpoint between sunrise and dhuhr
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

    // Debug logging for prayer times
    developer.log('Prayer times calculated for ${dateForCalculation.toString().split(' ')[0]}:', name: 'HomeScreen');
    for (final entry in times.entries) {
      if (entry.value != null) {
        developer.log(
          '${entry.key}: ${entry.value!.toString()} (${entry.value!.hour}:${entry.value!.minute.toString().padLeft(2, '0')})',
          name: 'HomeScreen',
        );
      }
    }

    // Update the widget with real data
    try {
      // WidgetService.updatePrayerWidget(
      //   currentPrayerName: _getCurrentPrayerName(),
      //   currentPrayerTime: times[_getCurrentPrayerName()]?.toString() ?? '-',
      //   remainingLabel: 'Remaining Time',
      //   remainingTime: _getTimeToNextPrayer().isNegative
      //       ? '--:--'
      //       : '${_getTimeToNextPrayer().inHours.toString().padLeft(2, '0')}:${(_getTimeToNextPrayer().inMinutes.remainder(60)).toString().padLeft(2, '0')}',
      //   fajrTime: fajr != null ? DateFormat('HH:mm').format(fajr) : '-',
      //   asrTime: asr != null ? DateFormat('HH:mm').format(asr) : '-',
      //   maghribTime: maghrib != null ? DateFormat('HH:mm').format(maghrib) : '-',
      //   ishaTime: isha != null ? DateFormat('HH:mm').format(isha) : '-',
      //   islamicDate: DateFormat('d MMMM, yyyy').format(_now),
      //   location: currentPlaceName ?? selectedCity ?? '-',
      // );
    } catch (e) {
      developer.log('Error updating widget: $e', name: 'HomeScreen');
    }

    // Only schedule notifications once per day or when jamaatTimes changes
    _scheduleNotificationsIfNeeded();
    
    // Debug: Log current notification scheduling status
    developer.log(
      'Notification scheduling status - Scheduled: $_notificationsScheduled, Last date: ${_lastScheduledDate.toString()}',
      name: 'HomeScreen',
    );
  }

  Future<void> _scheduleNotificationsIfNeeded() async {
    if (jamaatTimes == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Schedule notifications if:
    // 1. Not scheduled yet today, OR
    // 2. Last scheduled date is different from today
    if (!_notificationsScheduled || _lastScheduledDate.isBefore(today)) {
      developer.log(
        'Scheduling notifications for today: ${today.toString()}',
        name: 'HomeScreen',
      );
      await _notificationService.scheduleAllNotifications(times, jamaatTimes);
      _notificationsScheduled = true;
      _lastScheduledDate = today;
      developer.log('Notifications scheduled successfully', name: 'HomeScreen');
    }
  }

  /// Handle notification settings changes (like sound mode)
  Future<void> _handleNotificationSettingsChange() async {
    try {
      developer.log(
        'Handling notification settings change...',
        name: 'HomeScreen',
      );

      // Reset notification scheduling flag to force rescheduling
      _notificationsScheduled = false;
      
      // Reschedule notifications with new settings
      if (jamaatTimes != null) {
        await _scheduleNotificationsIfNeeded();
        developer.log(
          'Notifications rescheduled after settings change',
          name: 'HomeScreen',
        );
      }
    } catch (e) {
      developer.log(
        'Error handling notification settings change: $e',
        name: 'HomeScreen',
        error: e,
      );
    }
  }

  Future<void> _loadMadhab() async {
    final madhab = await _settingsService.getMadhab();
    setState(() {
      params.madhab = madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;

      // Set prayer time adjustments
      // In adhan_dart, adjustments is a Map<String, int>
      if (madhab == 'hanafi') {
        // For Hanafi, we might need a slight adjustment for more accuracy
        params.adjustments = Map.from(AppConstants.defaultAdjustments);
      } else {
        // For Shafi, reset asr adjustment but keep isha adjustment
        params.adjustments = {
          'asr': 0, // No adjustment for Asr time
          'isha': 2, // Small adjustment for Isha time
        };
      }

      _updatePrayerTimes();
    });
  }

  Future<void> _fetchUserLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      setState(() {
        _coords = Coordinates(position.latitude, position.longitude);
        isFetchingPlaceName = true;
        currentPlaceName = null;
      });
      // Save last fetched coordinates
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_latitude', position.latitude);
      await prefs.setDouble('last_longitude', position.longitude);
      // Fetch place name
      final place = await _locationService.getPlaceName(
        position.latitude,
        position.longitude,
      );
      setState(() {
        currentPlaceName = place;
        isFetchingPlaceName = false;
      });
      _updatePrayerTimes();
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
      setState(() {
        isFetchingPlaceName = false;
      });
      // On error, check if it's a permission error and prompt to open settings
      if (e.toString().contains('permission')) {
        await _locationService.openLocationSettings();
      }
      // On error, load last known location and coordinates
      final prefs = await SharedPreferences.getInstance();
      final lastPlace = prefs.getString('last_location_name');
      final lastLat = prefs.getDouble('last_latitude');
      final lastLng = prefs.getDouble('last_longitude');
      if (lastLat != null && lastLng != null) {
        setState(() {
          _coords = Coordinates(lastLat, lastLng);
        });
        _updatePrayerTimes();
      }
      if (lastPlace != null && lastPlace.isNotEmpty) {
        setState(() {
          currentPlaceName = lastPlace;
        });
      }
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
    if (lastLat != null && lastLng != null) {
      setState(() {
        _coords = Coordinates(lastLat, lastLng);
      });
      _updatePrayerTimes();
    }
    if (lastPlace != null && lastPlace.isNotEmpty) {
      setState(() {
        currentPlaceName = lastPlace;
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
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
      final current = prayerTimes.currentPrayer(date: _now);
      if (current == Prayer.fajr) return 'Fajr';
      if (current == Prayer.sunrise) return 'Sunrise';
      if (current == Prayer.dhuhr) return 'Dhuhr';
      if (current == Prayer.asr) return 'Asr';
      if (current == Prayer.maghrib) return 'Maghrib';
      if (current == Prayer.isha) return 'Isha';
      return 'Fajr';
    }
  }

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
    // Next day's Fajr
    final tomorrow = now.add(const Duration(days: 1));
    final coords = _coords ?? Coordinates(23.8376, 90.2820);
    final tomorrowPrayerTimes = PrayerTimes(
      coordinates: coords,
      date: tomorrow,
      calculationParameters: params,
      precision: true,
    );
    final tomorrowFajr = tomorrowPrayerTimes.fajr;
    return tomorrowFajr != null
        ? tomorrowFajr.difference(now)
        : const Duration();
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
      
      // Debug logging
      developer.log('Maghrib prayer time: $maghribPrayerTime (type: ${maghribPrayerTime.runtimeType})', name: 'HomeScreen');
      developer.log('Maghrib prayer time formatted: ${DateFormat('HH:mm').format(maghribPrayerTime)}', name: 'HomeScreen');
      developer.log('Offset for $selectedCity: $offset minutes', name: 'HomeScreen');
      
      // Convert to local time before adding offset
      final localMaghribTime = maghribPrayerTime.toLocal();
      final maghribJamaatTime = localMaghribTime.add(Duration(minutes: offset));
      
      developer.log('Local Maghrib prayer time: $localMaghribTime', name: 'HomeScreen');
      developer.log('Calculated Maghrib jamaat time: $maghribJamaatTime', name: 'HomeScreen');
      developer.log('Formatted Maghrib jamaat time: ${DateFormat('HH:mm').format(maghribJamaatTime)}', name: 'HomeScreen');
      
      return DateFormat('HH:mm').format(maghribJamaatTime);
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, d MMM, yyyy').format(selectedDate);
    final timeStr = DateFormat('HH:mm:ss').format(_now);
    final currentPrayer = _getCurrentPrayerName();
    final timeToNext = _getTimeToNextPrayer();

    // Customize countdown text based on prayer name and selected date
    String countdownText;
    final now = DateTime.now();
    final selectedDateOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final todayOnly = DateTime(now.year, now.month, now.day);
    
    if (selectedDateOnly.isBefore(todayOnly)) {
      // Past date
      countdownText = 'Viewing past date: ${DateFormat('dd MMM yyyy').format(selectedDate)}';
    } else if (selectedDateOnly.isAfter(todayOnly)) {
      // Future date
      countdownText = 'Viewing future date: ${DateFormat('dd MMM yyyy').format(selectedDate)}';
    } else {
      // Today
      if (currentPrayer == 'Sunrise') {
        countdownText = 'Coming Dahwa-e-kubrah';
      } else if (currentPrayer == 'Dahwah-e-kubrah') {
        countdownText = 'Coming Dhuhr';
      } else {
        String countdown = timeToNext.isNegative
            ? '--:--'
            : '${timeToNext.inHours.toString().padLeft(2, '0')}:${(timeToNext.inMinutes.remainder(60)).toString().padLeft(2, '0')}';
        countdownText = '$currentPrayer time remaining: $countdown';
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxContentWidth = constraints.maxWidth < 600
            ? constraints.maxWidth
            : 600.0;
        final horizontalPadding = constraints.maxWidth < 400 ? 8.0 : 16.0;
        return Scaffold(
          backgroundColor: const Color(0xFFE8F5E9),
          appBar: AppBar(
            title: const Text('Jamaat Time'),
            centerTitle: true,
            backgroundColor: const Color(0xFF388E3C),
            foregroundColor: Colors.white,
            elevation: 2,
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
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
                                        const Text('Your Mosque at: '),
                                        DropdownButton<String>(
                                          value: selectedCity,
                                          items: canttNames.map((cantt) {
                                            return DropdownMenuItem<String>(
                                              value: cantt,
                                              child: Text(cantt),
                                            );
                                          }).toList(),
                                          onChanged: (value) {
                                            setState(() {
                                              selectedCity = value;
                                            });
                                            if (selectedCity != null) {
                                              _fetchJamaatTimes(selectedCity!);
                                              _updatePrayerTimes();
                                            }
                                          },
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
                                              child: Text(
                                                timeStr,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                              child: Text(
                                                countdownText,
                                                style: TextStyle(
                                                  fontSize:
                                                      currentPrayer ==
                                                              'Sunrise' ||
                                                          currentPrayer ==
                                                              'Dahwah-e-kubrah'
                                                      ? 16
                                                      : 24,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF1B5E20),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Debug button
                                        TextButton(
                                          onPressed: () {
                                            if (selectedCity != null) {
                                              _fetchJamaatTimes(selectedCity!);
                                            }
                                          },
                                          child: const Text(
                                            'Debug Fetch',
                                            style: TextStyle(fontSize: 12, color: Colors.blue),
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

                    Text(
                      'Prayer Times',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                      ),
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
                        ...[
                          'Fajr',
                          'Sunrise',
                          'Dahwah-e-kubrah',
                          'Dhuhr',
                          'Asr',
                          'Maghrib',
                          'Isha',
                        ].map((name) {
                          final t = times[name];
                          final timeStr = t != null
                              ? DateFormat('HH:mm').format(
                                  tz.TZDateTime.from(
                                    t,
                                    tz.getLocation('Asia/Dhaka'),
                                  ),
                                )
                              : '-';
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
                          
                          // Debug logging for jamaat times mapping
                          if (jamaatTimes != null) {
                            developer.log('For $name - Looking for key: $jamaatKey, available keys: ${jamaatTimes!.keys.toList()}', name: 'HomeScreen');
                            developer.log('Value for $jamaatKey: ${jamaatTimes![jamaatKey]}', name: 'HomeScreen');
                          }
                          
                          String jamaatStr = '-';
                          if (name == 'Maghrib') {
                            // For Maghrib, use calculated time from prayer time
                            jamaatStr = _calculateMaghribJamaatTime();
                            developer.log('Calculated Maghrib jamaat time: $jamaatStr (offset: ${_getMaghribOffset(selectedCity ?? '')} min)', name: 'HomeScreen');
                          } else if (jamaatTimes != null && jamaatTimes!.containsKey(jamaatKey)) {
                            final value = jamaatTimes![jamaatKey];
                            developer.log('Raw value for $jamaatKey: $value (type: ${value.runtimeType})', name: 'HomeScreen');
                            if (value != null && value.toString().isNotEmpty) {
                              jamaatStr = _formatJamaatTime(value.toString());
                              developer.log('Formatted jamaat time for $jamaatKey: $jamaatStr', name: 'HomeScreen');
                            }
                          } else {
                            developer.log('No jamaat time found for key: $jamaatKey', name: 'HomeScreen');
                          }
                          
                          // Debug logging for jamaat times
                          if (jamaatTimes != null && (name == 'Fajr' || name == 'Maghrib')) {
                            developer.log('For $name - Looking for key: $jamaatKey, found: ${jamaatTimes![jamaatKey]}', name: 'HomeScreen');
                            developer.log('All available keys: ${jamaatTimes!.keys.toList()}', name: 'HomeScreen');
                          }
                          final isCurrent = name == _getCurrentPrayerName();
                          return TableRow(
                            decoration: isCurrent
                                ? BoxDecoration(color: Colors.green.shade100)
                                : null,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(name),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Center(
                                  child: Text(
                                    timeStr,
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
                                        jamaatStr,
                                        style: jamaatStr == '-'
                                            ? const TextStyle(color: Colors.grey)
                                            : const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                      ),
                                      if (jamaatStr != '-') ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.mosque, size: 12, color: Colors.green),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                    // Remove the widget test button and WidgetService usage
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
