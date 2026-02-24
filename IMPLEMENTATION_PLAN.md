# Jamaat Time App - Global Prayer Time Support Implementation Plan

## Executive Summary

Fix two critical issues in the Jamaat Time application:
1. **Issue 1:** Prayer times display incorrectly for users outside Bangladesh (hardcoded Asia/Dhaka timezone)
2. **Issue 2:** Prayer calculation method incorrect for Saudi Arabia (should use Umm al-Qura instead of Muslim World League)

---

## Root Cause Analysis

### Issue 1: Incorrect Time Display Outside Bangladesh

| Location | Problem Code | Issue |
|----------|--------------|-------|
| `notification_service.dart:471-472` | `tz.getLocation('Asia/Dhaka')` | Hardcoded Dhaka timezone for all comparisons |
| `notification_service.dart:475-480` | `tz.TZDateTime.from(entry.value!, dhakaLocation)` | Prayer times forcibly converted to Dhaka timezone |
| `notification_service.dart:626-633` | `tz.TZDateTime(dhakaLocation, ...)` | Jamaat times interpreted as Dhaka time |

### Issue 2: Incorrect Calculation Method for Saudi Arabia

| Location | Problem Code | Issue |
|----------|--------------|-------|
| `prayer_calculation_service.dart:19` | `CalculationMethod.muslimWorldLeague()` | Single method used for all locations |
| `home_screen.dart:94-101` | No location-based method selection | Method initialized once at startup |
| `constants.dart:44-56` | `canttNames` list | Only Bangladesh cities defined |

---

## Solution Architecture

### New Data Model: LocationConfig

```dart
// lib/models/location_config.dart

enum Country { bangladesh, saudiArabia, other }
enum JamaatSource { server, localOffset, none }

class LocationConfig {
  final String cityName;
  final Country country;
  final String timezone;           // IANA timezone string
  final CalculationMethod calculationMethod;
  final JamaatSource jamaatSource;
  final double latitude;
  final double longitude;
  final Map<String, int>? jamaatOffsets;  // Minutes after prayer time (Saudi only)
  
  const LocationConfig({
    required this.cityName,
    required this.country,
    required this.timezone,
    required this.calculationMethod,
    required this.jamaatSource,
    required this.latitude,
    required this.longitude,
    this.jamaatOffsets,
  });
  
  // Factory constructors for predefined locations
  factory LocationConfig.makkah() => LocationConfig(
    cityName: 'Makkah',
    country: Country.saudiArabia,
    timezone: 'Asia/Riyadh',
    calculationMethod: CalculationMethod.ummAlQura,
    jamaatSource: JamaatSource.localOffset,
    latitude: 21.4225,
    longitude: 39.8262,
    jamaatOffsets: {'fajr': 20, 'dhuhr': 20, 'asr': 20, 'maghrib': 10, 'isha': 20},
  );
  
  factory LocationConfig.madinah() => LocationConfig(
    cityName: 'Madinah',
    country: Country.saudiArabia,
    timezone: 'Asia/Riyadh',
    calculationMethod: CalculationMethod.ummAlQura,
    jamaatSource: JamaatSource.localOffset,
    latitude: 24.5247,
    longitude: 39.5692,
    jamaatOffsets: {'fajr': 20, 'dhuhr': 20, 'asr': 20, 'maghrib': 10, 'isha': 20},
  );
  
  factory LocationConfig.jeddah() => LocationConfig(
    cityName: 'Jeddah',
    country: Country.saudiArabia,
    timezone: 'Asia/Riyadh',
    calculationMethod: CalculationMethod.ummAlQura,
    jamaatSource: JamaatSource.localOffset,
    latitude: 21.5433,
    longitude: 39.1728,
    jamaatOffsets: {'fajr': 20, 'dhuhr': 20, 'asr': 20, 'maghrib': 10, 'isha': 20},
  );
  
  factory LocationConfig.bangladeshCantt(String cityName, double lat, double lng) => LocationConfig(
    cityName: cityName,
    country: Country.bangladesh,
    timezone: 'Asia/Dhaka',
    calculationMethod: CalculationMethod.muslimWorldLeague,
    jamaatSource: JamaatSource.server,
    latitude: lat,
    longitude: lng,
  );
}
```

### Calculation Method Comparison

| Parameter | Muslim World League | Umm al-Qura (Saudi) |
|-----------|---------------------|---------------------|
| Fajr Angle | 18° | 18.5° |
| Isha Calculation | 17° below horizon | 90 min after Maghrib |
| Isha (Ramadan) | Same as normal | 120 min after Maghrib |
| Madhab Support | Hanafi/Shafi | Not applicable |
| Used In | Bangladesh, South Asia | Saudi Arabia, Gulf |

---

## Implementation Steps

### Phase 1: Core Data Models (Critical)

#### Task 1.1: Create `lib/models/location_config.dart`
- Create `Country` enum
- Create `JamaatSource` enum
- Create `LocationConfig` class with factory constructors

#### Task 1.2: Update `lib/core/constants.dart`
```dart
// Add Saudi coordinates
static const Map<String, Map<String, double>> saudiCityCoordinates = {
  'Makkah': {'lat': 21.4225, 'lng': 39.8262},
  'Madinah': {'lat': 24.5247, 'lng': 39.5692},
  'Jeddah': {'lat': 21.5433, 'lng': 39.1728},
};

// Saudi jamaat offsets (minutes after prayer time)
static const Map<String, int> saudiJamaatOffsets = {
  'fajr': 20,
  'dhuhr': 20,
  'asr': 20,
  'maghrib': 10,
  'isha': 20,
};

// Updated city list with categories
static const List<String> bangladeshCities = [
  'Barishal Cantt', 'Bogra Cantt', 'Chittagong Cantt', 'Dhaka Cantt',
  'Ghatail Cantt', 'Jashore Cantt', 'Kumilla Cantt', 'Ramu Cantt',
  'Rangpur Cantt', 'Savar Cantt', 'Sylhet Cantt',
];

static const List<String> saudiCities = ['Makkah', 'Madinah', 'Jeddah'];
```

### Phase 2: Location Config Service (Critical)

#### Task 2.1: Create `lib/services/location_config_service.dart`
```dart
class LocationConfigService {
  static final LocationConfigService _instance = LocationConfigService._internal();
  factory LocationConfigService() => _instance;
  LocationConfigService._internal();
  
  LocationConfig? _currentConfig;
  LocationConfig? get currentConfig => _currentConfig;
  
  /// Get LocationConfig for a city name
  LocationConfig getConfigForCity(String cityName) {
    // Check Saudi cities
    if (AppConstants.saudiCities.contains(cityName)) {
      switch (cityName) {
        case 'Makkah': return LocationConfig.makkah();
        case 'Madinah': return LocationConfig.madinah();
        case 'Jeddah': return LocationConfig.jeddah();
      }
    }
    
    // Default to Bangladesh
    return _getBangladeshConfig(cityName);
  }
  
  /// Detect country from coordinates
  Country detectCountryFromCoordinates(double lat, double lng) {
    // Saudi Arabia bounding box: 16.0-32.0°N, 34.5-55.5°E
    if (lat >= 16.0 && lat <= 32.0 && lng >= 34.5 && lng <= 55.5) {
      return Country.saudiArabia;
    }
    // Bangladesh bounding box: 20.5-26.5°N, 88.0-92.5°E
    if (lat >= 20.5 && lat <= 26.5 && lng >= 88.0 && lng <= 92.5) {
      return Country.bangladesh;
    }
    return Country.other;
  }
  
  void setCurrentConfig(LocationConfig config) {
    _currentConfig = config;
  }
}
```

### Phase 3: Prayer Calculation Service Update (Critical)

#### Task 3.1: Update `lib/services/prayer_calculation_service.dart`
```dart
/// Get calculation parameters based on LocationConfig
CalculationParameters getCalculationParametersForConfig(LocationConfig config) {
  CalculationParameters params;
  
  if (config.country == Country.saudiArabia) {
    // Use Umm al-Qura for Saudi Arabia
    params = CalculationMethod.ummAlQura();
    
    // Apply Ramadan adjustment if needed
    if (_isRamadan()) {
      // Isha is 120 min after Maghrib during Ramadan (default is 90)
      params.adjustments = {'isha': 30}; // Additional 30 minutes
    }
  } else {
    // Bangladesh and others use Muslim World League
    params = CalculationMethod.muslimWorldLeague();
    params.adjustments = Map.from(AppConstants.defaultAdjustments);
  }
  
  return params;
}

/// Check if current date is Ramadan (Hijri month 9)
bool _isRamadan() {
  // Simple Hijri month calculation
  // For more accuracy, use a dedicated Hijri calendar library
  final now = DateTime.now();
  // This is a simplified check - implement proper Hijri conversion
  // or use package:hijri_calendar
  return false; // TODO: Implement proper Ramadan detection
}
```

### Phase 4: Notification Service Fix (Critical)

#### Task 4.1: Update `lib/services/notification_service.dart`

**Add state variable:**
```dart
LocationConfig? _currentLocationConfig;

void setLocationConfig(LocationConfig config) {
  _currentLocationConfig = config;
}
```

**Replace hardcoded timezone:**
```dart
// BEFORE:
final dhakaLocation = tz.getLocation('Asia/Dhaka');
final nowInDhaka = tz.TZDateTime.now(dhakaLocation);

// AFTER:
String _getTimezone() {
  return _currentLocationConfig?.timezone ?? 'Asia/Dhaka';
}

tz.Location _getLocation() {
  return tz.getLocation(_getTimezone());
}

// In schedulePrayerNotifications():
final location = _getLocation();
final now = tz.TZDateTime.now(location);

// Convert prayer times to correct timezone
final Map<String, tz.TZDateTime> localPrayerTimes = {};
for (final entry in prayerTimes.entries) {
  if (entry.value != null) {
    final localTime = tz.TZDateTime.from(entry.value!, location);
    localPrayerTimes[entry.key] = localTime;
  }
}
```

**Update scheduleJamaatNotifications():**
```dart
Future<void> scheduleJamaatNotifications(Map<String, dynamic>? jamaatTimes) async {
  if (jamaatTimes == null) return;
  
  final location = _getLocation();
  final now = tz.TZDateTime.now(location);
  
  for (final entry in jamaatTimes.entries) {
    final name = entry.key;
    final value = entry.value;
    
    if (value != null && value is String && value.isNotEmpty && value != '-') {
      final parts = value.split(':');
      if (parts.length != 2) continue;
      
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;
      
      // Create time in the CORRECT timezone (not hardcoded Dhaka)
      final jamaatTime = tz.TZDateTime(
        location,  // Dynamic timezone!
        now.year, now.month, now.day,
        hour, minute,
      );
      
      final notifyTime = jamaatTime.subtract(const Duration(minutes: 10));
      
      if (notifyTime.isAfter(now)) {
        await scheduleNotification(
          id: name.hashCode + 1000,
          title: '${_capitalize(name)} Jamaat',
          body: '${_capitalize(name)} Jamaat is in 10 minutes.',
          scheduledTime: notifyTime,
          notificationType: 'jamaat',
        );
      }
    }
  }
}
```

### Phase 5: UI Integration (High)

#### Task 5.1: Update `lib/screens/home_screen.dart`

**Add state:**
```dart
final LocationConfigService _locationConfigService = LocationConfigService();
LocationConfig? _locationConfig;
```

**Update initialization:**
```dart
Future<void> _initializeApp() async {
  // Get location config for selected city
  _locationConfig = _locationConfigService.getConfigForCity(selectedCity!);
  _locationConfigService.setCurrentConfig(_locationConfig!);
  
  // Pass config to notification service
  _notificationService.setLocationConfig(_locationConfig!);
  
  // Get calculation parameters based on location
  params = PrayerCalculationService.instance.getCalculationParametersForConfig(_locationConfig!);
  
  // Only apply madhab for Bangladesh
  if (_locationConfig!.country == Country.bangladesh) {
    final madhab = await _settingsService.getMadhab();
    params!.madhab = madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
  }
  
  // ... rest of initialization
}
```

**Update city dropdown:**
```dart
// Build grouped city list
List<DropdownMenuItem<String>> _buildCityDropdownItems() {
  final items = <DropdownMenuItem<String>>[];
  
  // Bangladesh cities
  items.add(DropdownMenuItem(
    enabled: false,
    child: Text('🇧🇩 Bangladesh', style: TextStyle(fontWeight: FontWeight.bold)),
  ));
  for (final city in AppConstants.bangladeshCities) {
    items.add(DropdownMenuItem(value: city, child: Text('  $city')));
  }
  
  // Saudi cities
  items.add(DropdownMenuItem(
    enabled: false,
    child: Text('🇸🇦 Saudi Arabia', style: TextStyle(fontWeight: FontWeight.bold)),
  ));
  for (final city in AppConstants.saudiCities) {
    items.add(DropdownMenuItem(value: city, child: Text('  $city')));
  }
  
  return items;
}
```

**Handle city change:**
```dart
void _onCityChanged(String? newCity) async {
  if (newCity == null || newCity == selectedCity) return;
  
  selectedCity = newCity;
  
  // Update location config
  _locationConfig = _locationConfigService.getConfigForCity(newCity);
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
  
  // Recalculate prayer times
  _updatePrayerTimes();
  
  // Fetch/calculate jamaat times based on location
  if (_locationConfig!.jamaatSource == JamaatSource.server) {
    await _fetchJamaatTimes(newCity);
  } else if (_locationConfig!.jamaatSource == JamaatSource.localOffset) {
    _calculateLocalJamaatTimes();
  }
}
```

**Calculate local jamaat times for Saudi:**
```dart
void _calculateLocalJamaatTimes() {
  if (_locationConfig == null || _locationConfig!.jamaatOffsets == null) return;
  
  final offsets = _locationConfig!.jamaatOffsets!;
  final newJamaatTimes = <String, dynamic>{};
  
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
```

---

## Files to Modify/Create

| File | Action | Priority |
|------|--------|----------|
| `lib/models/location_config.dart` | CREATE | Critical |
| `lib/services/location_config_service.dart` | CREATE | Critical |
| `lib/core/constants.dart` | MODIFY | Critical |
| `lib/services/prayer_calculation_service.dart` | MODIFY | Critical |
| `lib/services/notification_service.dart` | MODIFY | Critical |
| `lib/screens/home_screen.dart` | MODIFY | High |
| `lib/services/jamaat_time_utility.dart` | MODIFY | Medium |

---

## Testing Checklist

- [ ] Bangladesh user, Dhaka Cantt: Muslim World League, UTC+6, server jamaat
- [ ] Saudi user, Makkah: Umm al-Qura, UTC+3, local offset jamaat
- [ ] Device timezone = UTC: Times display correctly in city timezone
- [ ] City switch Dhaka→Makkah: Method/timezone/notifications all switch
- [ ] Notification fires at correct local time regardless of device timezone
- [ ] Firebase unavailable: Bangladesh shows error, Saudi continues working

---

## Validation Sources

1. **Makkah times:** Compare with official Masjid al-Haram schedule
2. **Madinah times:** Compare with Masjid an-Nabawi official times
3. **Cross-reference:** IslamicFinder.org for multiple cities
4. **Notification timing:** Test with device in UTC, UTC+3, UTC+6, UTC-5

---

## Implementation Order

1. Create `lib/models/location_config.dart`
2. Update `lib/core/constants.dart`
3. Create `lib/services/location_config_service.dart`
4. Update `lib/services/prayer_calculation_service.dart`
5. Update `lib/services/jamaat_time_utility.dart`
6. Update `lib/services/notification_service.dart`
7. Update `lib/screens/home_screen.dart`
8. End-to-end testing
