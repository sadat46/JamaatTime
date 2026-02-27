import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import '../services/settings_service.dart';
import '../services/jamaat_service.dart';
import '../services/notification_service.dart';
import '../core/constants.dart';

class NotificationMonitorScreen extends StatefulWidget {
  const NotificationMonitorScreen({super.key});

  @override
  State<NotificationMonitorScreen> createState() => _NotificationMonitorScreenState();
}

class _NotificationMonitorScreenState extends State<NotificationMonitorScreen> {
  final SettingsService _settingsService = SettingsService();
  final JamaatService _jamaatService = JamaatService();
  final NotificationService _notificationService = NotificationService();
  
  // Reuse the same prayer time calculation logic from HomeScreen
  CalculationParameters? params;
  PrayerTimes? prayerTimes;
  Map<String, DateTime?> times = {};
  
  final Map<String, DateTime?> _notificationTimes = {};
  final Map<String, DateTime?> _jamaatNotificationTimes = {};
  Map<String, dynamic>? jamaatTimes;
  bool _isLoading = true;
  bool _isJamaatLoading = true;

  @override
  void initState() {
    super.initState();
    tzdata.initializeTimeZones();
    // Removed timezone forcing to support global usage - device local time will be used
    _initializePrayerTimes();
    _loadJamaatNotificationTimes();
  }

  // Reuse the same initialization logic from HomeScreen
  Future<void> _initializePrayerTimes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use the same calculation parameters as HomeScreen
      params = CalculationMethod.muslimWorldLeague();
      final madhab = await _settingsService.getMadhab();
      params!.madhab = madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
      params!.adjustments = Map.from(AppConstants.defaultAdjustments);

      // Use default coordinates (same as HomeScreen)
      final coords = Coordinates(
        AppConstants.defaultLatitude,
        AppConstants.defaultLongitude,
      );
      
      final now = DateTime.now();
      prayerTimes = PrayerTimes(
        coordinates: coords,
        date: now,
        calculationParameters: params!,
        precision: true,
      );

      // Use the same times mapping as HomeScreen
      final fajr = prayerTimes!.fajr;
      final sunrise = prayerTimes!.sunrise;
      final dhuhr = prayerTimes!.dhuhr;
      final asr = prayerTimes!.asr;
      final maghrib = prayerTimes!.maghrib;
      final isha = prayerTimes!.isha;

      times = {
        'Fajr': fajr,
        'Sunrise': sunrise,
        'Dhuhr': dhuhr,
        'Asr': asr,
        'Maghrib': maghrib,
        'Isha': isha,
      };

      // Calculate notification trigger times (20 minutes before next prayer)
      _calculateNotificationTimes();

    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _calculateNotificationTimes() {
    // Use the NotificationService to calculate notification times with corrected logic
    _notificationTimes.clear();
    _notificationTimes.addAll(_notificationService.calculatePrayerNotificationTimes(times));
  }

  /// Get Maghrib offset in minutes based on cantt name (same as HomeScreen)
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

  /// Calculate Maghrib jamaat time from prayer time with cantt-specific offset (same as HomeScreen)
  String _calculateMaghribJamaatTime() {
    final maghribPrayerTime = times['Maghrib'];
    if (maghribPrayerTime != null) {
      final offset = _getMaghribOffset(AppConstants.defaultCity);

      // Convert to local time before adding offset
      final localMaghribTime = maghribPrayerTime.toLocal();
      final maghribJamaatTime = localMaghribTime.add(Duration(minutes: offset));

      return '${maghribJamaatTime.hour.toString().padLeft(2, '0')}:${maghribJamaatTime.minute.toString().padLeft(2, '0')}';
    }
    return '-';
  }

  // Reuse the same jamaat time loading logic from HomeScreen
  Future<void> _loadJamaatNotificationTimes() async {
    setState(() {
      _isJamaatLoading = true;
    });

    try {
      // Use the same jamaat service as HomeScreen
      final fetchedTimes = await _jamaatService.getJamaatTimes(
        city: AppConstants.defaultCity,
        date: DateTime.now(),
      );

      if (fetchedTimes != null) {
        // Create a complete jamaat times map including calculated Maghrib time (same as HomeScreen)
        final completeJamaatTimes = Map<String, dynamic>.from(fetchedTimes);

        // Add calculated Maghrib jamaat time to the map
        final maghribJamaatTime = _calculateMaghribJamaatTime();
        if (maghribJamaatTime != '-') {
          completeJamaatTimes['maghrib'] = maghribJamaatTime;
        }

        setState(() {
          jamaatTimes = completeJamaatTimes;
          _isJamaatLoading = false;
        });

        // Calculate jamaat notification times (10 minutes before jamaat)
        _calculateJamaatNotificationTimes();
      } else {
        setState(() {
          jamaatTimes = null;
          _isJamaatLoading = false;
        });
        // Add fallback data for testing
        _addFallbackJamaatTimes(DateTime.now());
      }
    } catch (e) {
      setState(() {
        jamaatTimes = null;
        _isJamaatLoading = false;
      });
      // Add fallback data for testing
      _addFallbackJamaatTimes(DateTime.now());
    }
  }

  void _calculateJamaatNotificationTimes() {
    // Use the NotificationService to calculate jamaat notification times (same logic as home screen)
    final calculatedTimes = _notificationService.calculateJamaatNotificationTimes(jamaatTimes);
    
    // Convert lowercase keys to capitalized prayer names for display
    _jamaatNotificationTimes.clear();
    for (final entry in calculatedTimes.entries) {
      final prayerName = entry.key.substring(0, 1).toUpperCase() + entry.key.substring(1);
      _jamaatNotificationTimes[prayerName] = entry.value;
    }
  }

  void _addFallbackJamaatTimes(DateTime today) {
    // Fallback Jamaat times for testing
    final fallbackTimes = {
      'Fajr': DateTime(today.year, today.month, today.day, 5, 30),
      'Dhuhr': DateTime(today.year, today.month, today.day, 13, 15),
      'Asr': DateTime(today.year, today.month, today.day, 16, 45),
      'Maghrib': DateTime(today.year, today.month, today.day, 18, 30),
      'Isha': DateTime(today.year, today.month, today.day, 20, 0),
    };
    
    _jamaatNotificationTimes.clear();
    for (final entry in fallbackTimes.entries) {
      final jamaatTime = entry.value;
      final notifyTime = jamaatTime.subtract(const Duration(minutes: 10));
      _jamaatNotificationTimes[entry.key] = notifyTime;
    }
  }

  // Refresh method that uses the same logic as HomeScreen
  Future<void> _refreshAllData() async {
    await _initializePrayerTimes();
    await _loadJamaatNotificationTimes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Monitor'),
        centerTitle: true,
        backgroundColor: const Color(0xFF388E3C),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAllData,
            tooltip: 'Refresh all data',
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFE8F5E9),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Prayer Time Notification List Box (Upper Portion)
              Expanded(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule,
                              color: Colors.green,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Prayer notification',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _initializePrayerTimes,
                              icon: const Icon(
                                Icons.refresh,
                                color: Colors.green,
                              ),
                              tooltip: 'Refresh notification times',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Prayer notification list with 3 columns
                        Expanded(
                          child: _isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                              : Column(
                                  children: [
                                    // Header row for column labels
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.1),
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.green,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // Prayer name header
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Prayer',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: Colors.green[700],
                                              ),
                                            ),
                                          ),
                                          // Prayer time header
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              'Prayer',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: Colors.blue[700],
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Notification time header
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              'Notify',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: Colors.green[700],
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Fixed list of all 5 prayers in table format with 3 columns
                                    ...['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'].map((prayer) {
                                      final prayerTime = times[prayer];
                                      final notifyTime = _notificationTimes[prayer];
                                      final now = DateTime.now();
                                      final isPast = notifyTime != null && notifyTime.isBefore(now);
                                      
                                      return Container(
                                        margin: const EdgeInsets.symmetric(vertical: 1),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isPast ? Colors.green[50] : Colors.white,
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.green.withValues(alpha: 0.2),
                                              width: 0.5,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            // Prayer name column
                                            Expanded(
                                              flex: 2,
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.schedule,
                                                    size: 14,
                                                    color: isPast ? Colors.grey : Colors.green,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    prayer,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 13,
                                                      color: isPast ? Colors.grey[600] : Colors.black87,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Prayer time column (middle)
                                            Expanded(
                                              flex: 1,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: Colors.blue,
                                                    width: 0.5,
                                                  ),
                                                ),
                                                child: Text(
                                                  prayerTime != null 
                                                      ? DateFormat('HH:mm').format(
                                                          tz.TZDateTime.from(
                                                            prayerTime,
                                                            tz.getLocation('Asia/Dhaka'),
                                                          ),
                                                        )
                                                      : '--:--',
                                                  style: const TextStyle(
                                                    color: Colors.blue,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Notification time column
                                            Expanded(
                                              flex: 1,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isPast 
                                                      ? Colors.grey.withValues(alpha: 0.1)
                                                      : Colors.green.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: isPast ? Colors.grey : Colors.green,
                                                    width: 0.5,
                                                  ),
                                                ),
                                                child: Text(
                                                  notifyTime != null 
                                                      ? DateFormat('HH:mm').format(notifyTime)
                                                      : '--:--',
                                                  style: TextStyle(
                                                    color: isPast ? Colors.grey : Colors.green,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Jamaat Time Notification List Box (Lower Portion)
              Expanded(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.mosque,
                              color: Colors.orange,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Jamaat notification',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _loadJamaatNotificationTimes,
                              icon: const Icon(
                                Icons.refresh,
                                color: Colors.orange,
                              ),
                              tooltip: 'Refresh jamaat notification times',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Jamaat notification list with different format
                        Expanded(
                          child: _isJamaatLoading
                              ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                              : Column(
                                  children: [
                                    // Header row for column labels
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.1),
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.orange,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // Prayer name header
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Prayer',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: Colors.orange[700],
                                              ),
                                            ),
                                          ),
                                          // Jamaat time header
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              'Jamaat',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: Colors.blue[700],
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Notification time header
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              'Notify',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: Colors.orange[700],
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Fixed list of all 5 prayers in table format with 3 columns
                                    ...['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'].map((prayer) {
                                      // Get jamaat time from jamaatTimes map (same as HomeScreen)
                                      String jamaatKey;
                                      switch (prayer) {
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
                                        default:
                                          jamaatKey = prayer.toLowerCase();
                                      }
                                      
                                      final jamaatTimeString = jamaatTimes?[jamaatKey];
                                      final notifyTime = _jamaatNotificationTimes[prayer];
                                      final now = DateTime.now();
                                      final isPast = notifyTime != null && notifyTime.isBefore(now);
                                      
                                      // Format jamaat time string (same as HomeScreen)
                                      String jamaatStr = '-';
                                      if (jamaatTimeString != null && jamaatTimeString.toString().isNotEmpty) {
                                        try {
                                          final time = DateFormat('HH:mm').parseStrict(jamaatTimeString.toString());
                                          jamaatStr = DateFormat('HH:mm').format(time);
                                        } catch (_) {
                                          jamaatStr = '-';
                                        }
                                      }
                                      
                                      return Container(
                                        margin: const EdgeInsets.symmetric(vertical: 1),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isPast ? Colors.orange[50] : Colors.white,
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.orange.withValues(alpha: 0.2),
                                              width: 0.5,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            // Prayer name column
                                            Expanded(
                                              flex: 2,
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.mosque,
                                                    size: 14,
                                                    color: isPast ? Colors.grey : Colors.orange,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    prayer,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 13,
                                                      color: isPast ? Colors.grey[600] : Colors.black87,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Jamaat time column (middle)
                                            Expanded(
                                              flex: 1,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: Colors.blue,
                                                    width: 0.5,
                                                  ),
                                                ),
                                                child: Text(
                                                  jamaatStr,
                                                  style: TextStyle(
                                                    color: jamaatStr == '-' ? Colors.grey : Colors.blue,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Notification time column
                                            Expanded(
                                              flex: 1,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isPast 
                                                      ? Colors.grey.withValues(alpha: 0.1)
                                                      : Colors.orange.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: isPast ? Colors.grey : Colors.orange,
                                                    width: 0.5,
                                                  ),
                                                ),
                                                child: Text(
                                                  notifyTime != null 
                                                      ? DateFormat('HH:mm').format(notifyTime)
                                                      : '--:--',
                                                  style: TextStyle(
                                                    color: isPast ? Colors.grey : Colors.orange,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
