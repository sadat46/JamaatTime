# Jamaat Time Application
## Technical Blueprint & Architecture Documentation

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Technical Specifications](#2-technical-specifications)
3. [System Architecture](#3-system-architecture)
4. [Project Structure](#4-project-structure)
5. [Core Services API Reference](#5-core-services-api-reference)
6. [Data Models & Schemas](#6-data-models--schemas)
7. [User Interface Components](#7-user-interface-components)
8. [Notification System](#8-notification-system)
9. [Authentication & Authorization](#9-authentication--authorization)
10. [Configuration Management](#10-configuration-management)
11. [Third-Party Integrations](#11-third-party-integrations)
12. [Security Considerations](#12-security-considerations)
13. [Performance Optimization](#13-performance-optimization)
14. [Deployment Guide](#14-deployment-guide)
15. [Testing Strategy](#15-testing-strategy)
16. [Maintenance & Monitoring](#16-maintenance--monitoring)
17. [Future Roadmap](#17-future-roadmap)
18. [Glossary](#18-glossary)
19. [Appendix](#19-appendix)

---

## 1. Executive Summary

### 1.1 Application Overview

**Jamaat Time** is a production-grade Flutter application designed to provide accurate Islamic prayer times and congregation (jamaat) schedules for Bangladesh military cantonments. The application serves both regular users seeking prayer information and administrators managing jamaat schedules.

### 1.2 Key Metrics

| Metric | Value |
|--------|-------|
| **Version** | 2.0.1+6 |
| **SDK Version** | Dart ^3.8.1 |
| **Target Platforms** | Android, iOS, Windows, macOS, Linux, Web |
| **Primary Market** | Bangladesh Military Cantonments |
| **Supported Locations** | 11 Cantonments |

### 1.3 Core Value Propositions

1. **Precision Prayer Calculations** - Astronomically accurate prayer times using the Adhan library with Muslim World League method
2. **Localized Jamaat Schedules** - Real-time congregation times specific to each cantonment
3. **Smart Notifications** - Configurable alerts 20 minutes before prayer and 10 minutes before jamaat
4. **Role-Based Administration** - Three-tier access control (User, Admin, Superadmin)
5. **Cross-Platform Consistency** - Unified experience across mobile, desktop, and web

### 1.4 Target Users

| User Type | Description | Access Level |
|-----------|-------------|--------------|
| **General User** | Muslims seeking prayer/jamaat times | View only |
| **Admin** | Mosque administrators | Edit jamaat times, CSV import/export |
| **Superadmin** | System administrators | Full access including user management |

---

## 2. Technical Specifications

### 2.1 Development Environment

```yaml
Framework: Flutter
Language: Dart
Minimum SDK: 3.8.1
IDE Support: VS Code, Android Studio, IntelliJ IDEA
Version Control: Git
```

### 2.2 Platform Requirements

| Platform | Minimum Version | Target Version |
|----------|-----------------|----------------|
| Android | API 21 (5.0 Lollipop) | API 34 (14) |
| iOS | 12.0 | 17.0 |
| Windows | Windows 10 | Windows 11 |
| macOS | 10.14 Mojave | 14 Sonoma |
| Linux | Ubuntu 18.04 | Ubuntu 22.04 |
| Web | Chrome 88+ | Latest |

### 2.3 Dependencies Matrix

#### Production Dependencies

| Package | Version | Purpose | Category |
|---------|---------|---------|----------|
| `firebase_core` | ^3.14.0 | Firebase initialization | Backend |
| `firebase_auth` | ^5.6.0 | User authentication | Backend |
| `cloud_firestore` | ^5.6.9 | NoSQL database | Backend |
| `adhan_dart` | ^1.1.2 | Prayer time calculations | Core Logic |
| `geolocator` | ^14.0.1 | GPS location services | Location |
| `geocoding` | ^2.2.0 | Reverse geocoding | Location |
| `flutter_local_notifications` | ^19.3.0 | Local push notifications | Notifications |
| `shared_preferences` | ^2.5.3 | Local key-value storage | Storage |
| `timezone` | ^0.10.1 | Timezone handling | Time |
| `intl` | ^0.20.2 | Internationalization & formatting | Utilities |
| `provider` | ^6.1.5 | State management | Architecture |
| `device_info_plus` | ^10.1.0 | Device information | Utilities |
| `package_info_plus` | ^4.2.0 | App package info | Utilities |
| `file_picker` | ^8.0.0+1 | File selection | Admin Features |
| `csv` | ^5.1.1 | CSV parsing/generation | Admin Features |

#### Development Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_test` | SDK | Unit & widget testing |
| `flutter_lints` | ^5.0.0 | Code quality & linting |
| `flutter_launcher_icons` | ^0.13.1 | App icon generation |
| `msix` | ^3.16.7 | Windows MSIX packaging |

---

## 3. System Architecture

### 3.1 High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CLIENT LAYER                                    │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                         Flutter Application                              ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ ││
│  │  │   Android   │  │     iOS     │  │   Windows   │  │  macOS/Linux/Web│ ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────────┘ ││
│  └─────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           PRESENTATION LAYER                                 │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────────┐   │
│  │   HomeScreen     │  │  SettingsScreen  │  │    ProfileScreen         │   │
│  │  - Prayer Table  │  │  - Theme Select  │  │  - Authentication        │   │
│  │  - City Selector │  │  - Madhab Toggle │  │  - Role Display          │   │
│  │  - Countdown     │  │  - Sound Config  │  │  - Admin Navigation      │   │
│  └──────────────────┘  └──────────────────┘  └──────────────────────────┘   │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────────┐   │
│  │ AdminJamaatPanel │  │UserManagement    │  │NotificationMonitor       │   │
│  │  - Time Editor   │  │  - User List     │  │  - Scheduled List        │   │
│  │  - CSV Import    │  │  - Role Editor   │  │  - Debug Info            │   │
│  │  - Bulk Updates  │  │  - Statistics    │  │  - Test Triggers         │   │
│  └──────────────────┘  └──────────────────┘  └──────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            SERVICE LAYER                                     │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                        Core Services (Singleton Pattern)                 ││
│  │  ┌────────────────────┐  ┌────────────────────┐  ┌──────────────────┐   ││
│  │  │PrayerCalculation   │  │ NotificationService│  │  JamaatService   │   ││
│  │  │    Service         │  │                    │  │                  │   ││
│  │  │ - calculateTimes() │  │ - initialize()     │  │ - getJamaatTimes │   ││
│  │  │ - getCountdown()   │  │ - scheduleAll()    │  │ - saveJamaatTimes│   ││
│  │  │ - getCurrentPrayer │  │ - cancelAll()      │  │ - bulkSave()     │   ││
│  │  └────────────────────┘  └────────────────────┘  └──────────────────┘   ││
│  │  ┌────────────────────┐  ┌────────────────────┐  ┌──────────────────┐   ││
│  │  │   AuthService      │  │  SettingsService   │  │ LocationService  │   ││
│  │  │                    │  │                    │  │                  │   ││
│  │  │ - signIn()         │  │ - getThemeIndex()  │  │ - getPosition()  │   ││
│  │  │ - register()       │  │ - getMadhab()      │  │ - getPlaceName() │   ││
│  │  │ - getUserRole()    │  │ - getSoundMode()   │  │ - requestPerm()  │   ││
│  │  └────────────────────┘  └────────────────────┘  └──────────────────┘   ││
│  └─────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DATA LAYER                                      │
│  ┌─────────────────────────────┐    ┌─────────────────────────────────────┐ │
│  │     Firebase Firestore      │    │       Local Storage                 │ │
│  │  ┌───────────────────────┐  │    │  ┌───────────────────────────────┐  │ │
│  │  │ Collection: users     │  │    │  │    SharedPreferences          │  │ │
│  │  │  - uid (doc id)       │  │    │  │  - theme_index: int           │  │ │
│  │  │  - email: string      │  │    │  │  - madhab: string             │  │ │
│  │  │  - role: string       │  │    │  │  - prayer_sound_mode: int     │  │ │
│  │  │  - preferred_city     │  │    │  │  - jamaat_sound_mode: int     │  │ │
│  │  │  - created_at         │  │    │  │  - last_latitude: double      │  │ │
│  │  │  - updated_at         │  │    │  │  - last_longitude: double     │  │ │
│  │  └───────────────────────┘  │    │  │  - last_location_name: string │  │ │
│  │  ┌───────────────────────┐  │    │  └───────────────────────────────┘  │ │
│  │  │Collection: jamaat_times│ │    │  ┌───────────────────────────────┐  │ │
│  │  │  └── {city}           │  │    │  │    In-Memory Mock Storage     │  │ │
│  │  │      └── daily_times  │  │    │  │  (Fallback when Firebase      │  │ │
│  │  │          └── {date}   │  │    │  │   is unavailable)             │  │ │
│  │  │              - times  │  │    │  └───────────────────────────────┘  │ │
│  │  └───────────────────────┘  │    │                                     │ │
│  └─────────────────────────────┘    └─────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Design Patterns

| Pattern | Implementation | Purpose |
|---------|---------------|---------|
| **Singleton** | All services | Single instance throughout app lifecycle |
| **Factory** | Service constructors | Controlled instance creation |
| **Observer** | StreamController in SettingsService | Settings change notifications |
| **ValueNotifier** | HomeScreen state | Efficient partial UI updates |
| **Repository** | JamaatService, AuthService | Data access abstraction |

### 3.3 Data Flow

```
┌──────────┐    ┌─────────────┐    ┌─────────────┐    ┌──────────────┐
│   User   │───▶│  UI Screen  │───▶│   Service   │───▶│  Data Store  │
│  Action  │    │   Widget    │    │   Layer     │    │  (Firebase/  │
│          │    │             │    │             │    │   Local)     │
└──────────┘    └─────────────┘    └─────────────┘    └──────────────┘
                      │                   │                   │
                      │                   │                   │
                      ▼                   ▼                   ▼
               ┌─────────────┐    ┌─────────────┐    ┌──────────────┐
               │   setState  │    │   Return    │    │   Response   │
               │   or        │◀───│   Data      │◀───│   Data       │
               │ValueNotifier│    │             │    │              │
               └─────────────┘    └─────────────┘    └──────────────┘
```

---

## 4. Project Structure

### 4.1 Directory Tree

```
jamaat_time/
├── android/                          # Android platform files
│   ├── app/
│   │   ├── src/main/
│   │   │   ├── res/raw/             # Audio files (allahu_akbar.mp3)
│   │   │   └── AndroidManifest.xml  # Permissions & config
│   │   └── build.gradle
│   └── build.gradle
├── ios/                              # iOS platform files
│   ├── Runner/
│   │   ├── Info.plist               # iOS permissions
│   │   └── AppDelegate.swift
│   └── Podfile
├── windows/                          # Windows platform files
├── macos/                            # macOS platform files
├── linux/                            # Linux platform files
├── web/                              # Web platform files
├── lib/                              # Main Dart source code
│   ├── main.dart                     # Application entry point
│   ├── firebase_options.dart         # Firebase configuration
│   ├── core/                         # Core utilities & constants
│   │   ├── constants.dart            # App-wide constants
│   │   └── extensions/
│   │       └── date_time_extension.dart
│   ├── screens/                      # UI screens
│   │   ├── home_screen.dart          # Main prayer display
│   │   ├── settings_screen.dart      # User preferences
│   │   ├── profile_screen.dart       # Auth & profile
│   │   ├── admin_jamaat_panel.dart   # Admin management
│   │   ├── notification_monitor_screen.dart
│   │   └── user_management_screen.dart
│   ├── services/                     # Business logic services
│   │   ├── prayer_calculation_service.dart
│   │   ├── notification_service.dart
│   │   ├── jamaat_service.dart
│   │   ├── auth_service.dart
│   │   ├── settings_service.dart
│   │   ├── location_service.dart
│   │   └── jamaat_time_utility.dart
│   ├── widgets/                      # Reusable UI components
│   │   ├── prayer_time_table.dart
│   │   └── prayer_info_card.dart
│   └── themes/                       # Theme definitions
│       ├── white_theme.dart
│       ├── light_theme.dart
│       ├── dark_theme.dart
│       └── green_theme.dart
├── assets/                           # Static assets
│   └── icon/
│       └── icon.png                  # App launcher icon
├── pubspec.yaml                      # Dependencies & metadata
├── analysis_options.yaml             # Lint rules
└── BLUEPRINT.md                      # This document
```

### 4.2 File Responsibilities

| File | Lines | Primary Responsibility |
|------|-------|----------------------|
| `main.dart` | ~112 | App initialization, theme binding, navigation scaffold |
| `home_screen.dart` | ~950 | Prayer/jamaat display, countdown, city selection |
| `notification_service.dart` | ~716 | All notification scheduling and channel management |
| `auth_service.dart` | ~261 | Firebase Auth, role management, user CRUD |
| `jamaat_service.dart` | ~344 | Firestore CRUD for jamaat times |
| `settings_service.dart` | ~85 | SharedPreferences wrapper with change broadcasting |
| `prayer_calculation_service.dart` | ~176 | Adhan library wrapper, time calculations |
| `location_service.dart` | ~63 | GPS and reverse geocoding |
| `constants.dart` | ~32 | Application constants |

---

## 5. Core Services API Reference

### 5.1 PrayerCalculationService

**Pattern:** Singleton
**Location:** `lib/services/prayer_calculation_service.dart`

#### Methods

```dart
/// Initialize timezone data for Bangladesh
void initializeTimeZones()

/// Get calculation parameters based on madhab
/// @param madhab - Hanafi or Shafi
/// @returns CalculationParameters configured for Muslim World League
CalculationParameters getCalculationParameters(Madhab madhab)

/// Calculate prayer times for a specific location and date
/// @param coordinates - GPS coordinates
/// @param date - Date for calculation
/// @param parameters - Calculation parameters (madhab, adjustments)
/// @returns PrayerTimes object with all prayer times
PrayerTimes calculatePrayerTimes({
  required Coordinates coordinates,
  required DateTime date,
  required CalculationParameters parameters,
})

/// Calculate Dahwah-e-kubrah (Islamic noon)
/// @param sunrise - Sunrise time
/// @param dhuhr - Dhuhr time
/// @returns Midpoint between sunrise and dhuhr
DateTime? calculateDahwahKubrah(DateTime? sunrise, DateTime? dhuhr)

/// Create a map of all prayer times
/// @param prayerTimes - Calculated PrayerTimes object
/// @returns Map with prayer names as keys and times as values
Map<String, DateTime?> createPrayerTimesMap(PrayerTimes prayerTimes)

/// Get the currently active prayer name
/// @param times - Prayer times map
/// @param now - Current time
/// @param selectedDate - Selected date for display
/// @returns Name of current prayer
String getCurrentPrayerName({...})

/// Calculate duration until next prayer
/// @returns Duration to next prayer time
Duration getTimeToNextPrayer({...})
```

#### Configuration

| Parameter | Value | Description |
|-----------|-------|-------------|
| Calculation Method | Muslim World League | Fajr: 18°, Isha: 17° |
| Default Madhab | Hanafi | Standard for South Asia |
| Asr Adjustment | +1 minute | Fine-tuning for accuracy |
| Isha Adjustment | +2 minutes | Fine-tuning for accuracy |
| Default Location | 23.8376°N, 90.2820°E | Savar, Dhaka |
| Timezone | Asia/Dhaka | UTC+6 |

---

### 5.2 NotificationService

**Pattern:** Singleton
**Location:** `lib/services/notification_service.dart`

#### Notification Channels (Android)

| Channel ID | Name | Sound | Vibration |
|------------|------|-------|-----------|
| `prayer_channel_custom` | Prayer (Custom Sound) | allahu_akbar.mp3 | Yes |
| `prayer_channel_system` | Prayer (System Sound) | System default | Yes |
| `prayer_channel_silent` | Prayer (Silent) | None | No |
| `jamaat_channel_custom` | Jamaat (Custom Sound) | allahu_akbar.mp3 | Yes |
| `jamaat_channel_system` | Jamaat (System Sound) | System default | Yes |
| `jamaat_channel_silent` | Jamaat (Silent) | None | No |

#### Methods

```dart
/// Initialize notification service and create channels
/// @param context - BuildContext for permissions (optional)
Future<void> initialize([BuildContext? context])

/// Schedule a single notification
/// @param id - Unique notification ID
/// @param title - Notification title
/// @param body - Notification body text
/// @param scheduledTime - When to show notification
/// @param notificationType - 'prayer' or 'jamaat'
Future<void> scheduleNotification({
  required int id,
  required String title,
  required String body,
  required DateTime scheduledTime,
  String notificationType = 'prayer',
})

/// Schedule all prayer notifications for the day
/// @param prayerTimes - Map of prayer names to times
Future<void> schedulePrayerNotifications(Map<String, DateTime?> prayerTimes)

/// Schedule all jamaat notifications for the day
/// @param jamaatTimes - Map of prayer names to jamaat times
Future<void> scheduleJamaatNotifications(Map<String, dynamic>? jamaatTimes)

/// Schedule both prayer and jamaat notifications
/// @param prayerTimes - Prayer times map
/// @param jamaatTimes - Jamaat times map
Future<void> scheduleAllNotifications(
  Map<String, DateTime?> prayerTimes,
  Map<String, dynamic>? jamaatTimes,
)

/// Cancel all pending notifications
Future<void> cancelAllNotifications()

/// Get list of pending notifications (for debugging)
Future<List<PendingNotificationRequest>> getPendingNotifications()

/// Check if notifications are enabled
Future<bool> areNotificationsEnabled()
```

#### Notification Logic

**Prayer Notifications (20 minutes before end of prayer time):**
| Prayer | Notification Timing |
|--------|-------------------|
| Fajr | 20 min before Sunrise |
| Dhuhr | 20 min before Asr |
| Asr | 20 min before Maghrib |
| Maghrib | 20 min before Isha |
| Isha | 20 min before next day's Fajr |

**Jamaat Notifications:**
- Triggered **10 minutes before** jamaat time

---

### 5.3 JamaatService

**Pattern:** Singleton with Firebase + Mock Fallback
**Location:** `lib/services/jamaat_service.dart`

#### Firestore Structure

```
jamaat_times/
├── barishal_cantt/
│   └── daily_times/
│       ├── 2024-12-18/
│       │   ├── date: "2024-12-18"
│       │   ├── city: "Barishal Cantt"
│       │   ├── times: {
│       │   │   fajr: "05:15",
│       │   │   dhuhr: "12:30",
│       │   │   asr: "15:45",
│       │   │   isha: "19:30"
│       │   │   // maghrib calculated dynamically
│       │   │ }
│       │   ├── created_at: Timestamp
│       │   └── updated_at: Timestamp
│       └── 2024-12-19/
│           └── ...
├── dhaka_cantt/
│   └── daily_times/
│       └── ...
└── ... (11 cantonments total)
```

#### Methods

```dart
/// Save jamaat times for a specific city and date
Future<void> saveJamaatTimes({
  required String city,
  required DateTime date,
  required Map<String, String> times,
})

/// Get jamaat times for a specific city and date
/// @returns Map of prayer names to times, or null if not found
Future<Map<String, String>?> getJamaatTimes({
  required String city,
  required DateTime date,
})

/// Get jamaat times for a date range
/// @returns Map of dates to jamaat times maps
Future<Map<String, Map<String, String>>> getJamaatTimesRange({
  required String city,
  required DateTime startDate,
  required DateTime endDate,
})

/// Bulk save jamaat times for multiple dates (batch write)
Future<void> bulkSaveJamaatTimes({
  required String city,
  required Map<String, Map<String, String>> timesByDate,
})

/// Check if jamaat times exist for a city and date
Future<bool> hasJamaatTimes({
  required String city,
  required DateTime date,
})

/// Delete jamaat times for a city and date
Future<void> deleteJamaatTimes({
  required String city,
  required DateTime date,
})

/// Generate yearly jamaat times for all cantonments
Future<void> generateYearlyJamaatTimes({
  required int year,
  Map<String, Map<String, String>>? defaultTimes,
})
```

---

### 5.4 AuthService

**Pattern:** Standard class with Firebase integration
**Location:** `lib/services/auth_service.dart`

#### User Roles

```dart
enum UserRole { user, admin, superadmin }
```

| Role | Permissions |
|------|-------------|
| `user` | View prayer times, view jamaat times |
| `admin` | All user permissions + edit jamaat times, CSV import/export |
| `superadmin` | All admin permissions + manage users, change roles |

#### Methods

```dart
/// Stream of authentication state changes
Stream<User?> get userChanges

/// Current authenticated user
User? get currentUser

/// Sign in with email and password
Future<User?> signIn(String email, String password)

/// Register new user (automatically assigns 'user' role)
Future<User?> register(String email, String password)

/// Sign out current user
Future<void> signOut()

/// Get current user's role from Firestore
Future<UserRole> getUserRole()

/// Check if current user has admin privileges
Future<bool> isAdmin()

/// Check if current user is superadmin
Future<bool> isSuperAdmin()

/// Get all users (superadmin only)
Future<List<Map<String, dynamic>>> getAllUsers()

/// Update user role (superadmin only)
/// - Cannot change own role
/// - Cannot change other superadmins
Future<void> updateUserRole(String userId, UserRole newRole)

/// Delete user (superadmin only)
/// - Cannot delete self
/// - Cannot delete other superadmins
Future<void> deleteUser(String userId)

/// Get user statistics (superadmin only)
Future<Map<String, dynamic>> getUserStats()

/// Save user's preferred city
Future<void> savePreferredCity(String city)

/// Load user's preferred city
Future<String?> loadPreferredCity()
```

---

### 5.5 SettingsService

**Pattern:** Standard class with StreamController for change notifications
**Location:** `lib/services/settings_service.dart`

#### Storage Keys

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `theme_mode` | String | 'light' | Theme mode (light/dark) |
| `theme_index` | int | 0 | Theme index (0-3) |
| `madhab` | String | 'hanafi' | Madhab preference |
| `prayer_notification_sound_mode` | int | 0 | 0=Custom, 1=System, 2=Silent |
| `jamaat_notification_sound_mode` | int | 0 | 0=Custom, 1=System, 2=Silent |

#### Methods

```dart
/// Stream of settings changes
Stream<void> get onSettingsChanged

/// Theme methods
Future<bool> isDarkMode()
Future<void> setDarkMode(bool dark)
Future<int> getThemeIndex()
Future<void> setThemeIndex(int idx)

/// Madhab methods
Future<String> getMadhab()
Future<void> setMadhab(String madhab)

/// Notification sound mode methods
Future<int> getPrayerNotificationSoundMode()
Future<void> setPrayerNotificationSoundMode(int mode)
Future<int> getJamaatNotificationSoundMode()
Future<void> setJamaatNotificationSoundMode(int mode)
```

---

### 5.6 LocationService

**Pattern:** Standard class
**Location:** `lib/services/location_service.dart`

#### Methods

```dart
/// Request location permission from user
/// @returns true if granted, false otherwise
Future<bool> requestPermission()

/// Get current GPS position
/// @throws Exception if services disabled or permission denied
Future<Position> getCurrentPosition()

/// Reverse geocode coordinates to place name
/// @returns Full address string or null
Future<String?> getPlaceName(double latitude, double longitude)

/// Open device location settings
Future<void> openLocationSettings()
```

---

## 6. Data Models & Schemas

### 6.1 Firestore Collections

#### Users Collection

```typescript
interface User {
  uid: string;              // Document ID (Firebase Auth UID)
  email: string;            // User email address
  role: 'user' | 'admin' | 'superadmin';
  preferred_city?: string;  // Selected cantonment
  created_at: Timestamp;    // Account creation time
  updated_at: Timestamp;    // Last modification time
}
```

#### Jamaat Times Collection

```typescript
interface JamaatTimes {
  // Path: jamaat_times/{city_key}/daily_times/{date}
  date: string;             // "YYYY-MM-DD" format
  city: string;             // Display name
  times: {
    fajr: string;           // "HH:mm" format
    dhuhr: string;
    asr: string;
    isha: string;
    // maghrib is calculated dynamically
  };
  created_at: Timestamp;
  updated_at: Timestamp;
}
```

### 6.2 Local Storage Schema

```typescript
interface LocalSettings {
  theme_index: number;                    // 0-3
  theme_mode: 'light' | 'dark';
  madhab: 'hanafi' | 'shafi';
  prayer_notification_sound_mode: number; // 0-2
  jamaat_notification_sound_mode: number; // 0-2
  last_latitude: number;
  last_longitude: number;
  last_location_name: string;
}
```

### 6.3 Runtime Data Structures

#### Prayer Times Map
```dart
Map<String, DateTime?> times = {
  'Fajr': DateTime(...),
  'Sunrise': DateTime(...),
  'Dahwah-e-kubrah': DateTime(...),
  'Dhuhr': DateTime(...),
  'Asr': DateTime(...),
  'Maghrib': DateTime(...),
  'Isha': DateTime(...),
};
```

#### Jamaat Times Map
```dart
Map<String, dynamic> jamaatTimes = {
  'fajr': '05:15',
  'dhuhr': '12:30',
  'asr': '15:45',
  'maghrib': '18:25',  // Calculated
  'isha': '19:30',
};
```

---

## 7. User Interface Components

### 7.1 Screen Hierarchy

```
MainScaffold (BottomNavigationBar)
│
├── Tab 0: HomeScreen
│   ├── Header Card
│   │   ├── City Dropdown Selector
│   │   ├── Date Display
│   │   ├── Current Time (ValueNotifier)
│   │   ├── Countdown to Next Prayer (ValueNotifier)
│   │   └── Location Button + Display
│   └── Prayer Times Table
│       ├── Header Row (Prayer Name, Prayer Time, Jamaat Time)
│       └── 7 Prayer Rows (Fajr, Sunrise, Dahwah-e-kubrah, Dhuhr, Asr, Maghrib, Isha)
│
├── Tab 1: SettingsScreen
│   ├── Theme Selection (4 options)
│   ├── Madhab Toggle (Hanafi/Shafi)
│   ├── Prayer Notification Sound (Custom/System/Silent)
│   └── Jamaat Notification Sound (Custom/System/Silent)
│
└── Tab 2: ProfileScreen
    ├── Authentication Section
    │   ├── Login Form (if not authenticated)
    │   └── User Info + Logout (if authenticated)
    └── Admin Section (if admin/superadmin)
        ├── Admin Jamaat Panel Button
        ├── Notification Monitor Button (debug)
        └── User Management Button (superadmin only)
```

### 7.2 Theme System

| Index | Name | Primary Color | Background |
|-------|------|---------------|------------|
| 0 | White | #388E3C | #FFFFFF |
| 1 | Light | #388E3C | #E8F5E9 |
| 2 | Dark | #4CAF50 | #121212 |
| 3 | Green | #1B5E20 | #E8F5E9 |

All themes use **Material Design 3** with `useMaterial3: true`.

### 7.3 Responsive Design

The app implements responsive layouts:

```dart
// Breakpoints
maxContentWidth: 600.0     // Maximum content width for readability
horizontalPadding:
  < 400px: 8.0            // Mobile
  >= 400px: 16.0          // Tablet/Desktop
cardMaxWidth: 500.0        // Maximum card width
```

---

## 8. Notification System

### 8.1 Notification Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    NotificationService                       │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              FlutterLocalNotificationsPlugin          │  │
│  │  ┌─────────────────┐  ┌─────────────────────────────┐ │  │
│  │  │ Android Plugin  │  │      iOS/Darwin Plugin      │ │  │
│  │  │                 │  │                             │ │  │
│  │  │ 6 Channels:     │  │ - presentAlert: true       │ │  │
│  │  │ - prayer_custom │  │ - presentBadge: true       │ │  │
│  │  │ - prayer_system │  │ - presentSound: true       │ │  │
│  │  │ - prayer_silent │  │                             │ │  │
│  │  │ - jamaat_custom │  │                             │ │  │
│  │  │ - jamaat_system │  │                             │ │  │
│  │  │ - jamaat_silent │  │                             │ │  │
│  │  └─────────────────┘  └─────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 8.2 Notification ID Scheme

```dart
// Prayer notifications use prayer name hashCode
int prayerId = 'Fajr'.hashCode;      // Unique per prayer

// Jamaat notifications add offset to avoid collision
int jamaatId = 'fajr'.hashCode + 1000;
```

### 8.3 Scheduling Logic

```dart
// Only schedule for current date
if (selectedDateOnly != today) return;

// Only schedule if in future
if (notifyTime.isAfter(now)) {
  scheduleNotification(...);
}

// Reschedule when:
// 1. Date changes (midnight)
// 2. Jamaat times updated
// 3. Sound mode changed
// 4. City changed
```

---

## 9. Authentication & Authorization

### 9.1 Authentication Flow

```
┌────────────┐     ┌──────────────┐     ┌───────────────┐
│   User     │────▶│ ProfileScreen│────▶│ Firebase Auth │
│   Action   │     │              │     │               │
└────────────┘     └──────────────┘     └───────────────┘
                          │                     │
                          ▼                     ▼
                   ┌──────────────┐     ┌───────────────┐
                   │ AuthService  │◀────│ Auth State    │
                   │              │     │ Stream        │
                   └──────────────┘     └───────────────┘
                          │
                          ▼
                   ┌──────────────┐
                   │  Firestore   │
                   │  (User Doc)  │
                   └──────────────┘
```

### 9.2 Role-Based Access Control

```dart
// Route protection example
if (await authService.isAdmin()) {
  Navigator.push(context, AdminJamaatPanel());
}

if (await authService.isSuperAdmin()) {
  Navigator.push(context, UserManagementScreen());
}
```

### 9.3 Security Rules (Firestore)

```javascript
// Recommended Firestore security rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null &&
                    (request.auth.uid == userId ||
                     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'superadmin');
      allow write: if request.auth != null &&
                     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'superadmin';
    }

    // Jamaat times collection
    match /jamaat_times/{city}/daily_times/{date} {
      allow read: if true;  // Public read
      allow write: if request.auth != null &&
                     (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['admin', 'superadmin']);
    }
  }
}
```

---

## 10. Configuration Management

### 10.1 Application Constants

**File:** `lib/core/constants.dart`

```dart
class AppConstants {
  // Default coordinates (Dhaka, Bangladesh)
  static const double defaultLatitude = 23.8376;
  static const double defaultLongitude = 90.2820;

  // Time zone
  static const String defaultTimeZone = 'Asia/Dhaka';

  // Default city
  static const String defaultCity = 'Savar Cantt';

  // Prayer time adjustments (minutes)
  static const Map<String, int> defaultAdjustments = {
    'asr': 1,
    'isha': 2,
  };

  // Supported cantonments
  static const List<String> canttNames = [
    'Barishal Cantt',
    'Bogra Cantt',
    'Chittagong Cantt',
    'Dhaka Cantt',
    'Ghatail Cantt',
    'Jashore Cantt',
    'Kumilla Cantt',
    'Ramu Cantt',
    'Rangpur Cantt',
    'Savar Cantt',
    'Sylhet Cantt',
  ];
}
```

### 10.2 Maghrib Offset Configuration

Maghrib jamaat time is calculated dynamically based on city:

```dart
int _getMaghribOffset(String city) {
  switch (city) {
    case 'Savar Cantt':
    case 'Dhaka Cantt':
    case 'Kumilla Cantt':
      return 13;  // 13 minutes after Maghrib prayer
    case 'Rangpur Cantt':
    case 'Jashore Cantt':
    case 'Bogra Cantt':
      return 10;  // 10 minutes after Maghrib prayer
    default:
      return 7;   // 7 minutes after Maghrib prayer
  }
}
```

### 10.3 Firebase Configuration

**File:** `lib/firebase_options.dart` (auto-generated)

```dart
// Platform-specific Firebase options
static const FirebaseOptions android = FirebaseOptions(
  apiKey: '...',
  appId: '...',
  messagingSenderId: '...',
  projectId: '...',
  storageBucket: '...',
);
```

---

## 11. Third-Party Integrations

### 11.1 Adhan Library

**Package:** `adhan_dart`
**Version:** 1.1.2

#### Prayer Time Calculation Method

| Parameter | Value |
|-----------|-------|
| Method | Muslim World League |
| Fajr Angle | 18° |
| Isha Angle | 17° |
| Midnight Mode | Standard |

#### Madhab Support

| Madhab | Asr Calculation |
|--------|-----------------|
| Hanafi | Shadow length = 2× object height |
| Shafi | Shadow length = 1× object height |

### 11.2 Firebase Services

| Service | Usage |
|---------|-------|
| **Authentication** | Email/password authentication |
| **Firestore** | User data, jamaat schedules |
| **Timestamp** | Server-side timestamps |

### 11.3 Location Services

| Platform | Service |
|----------|---------|
| Android | Fused Location Provider |
| iOS | Core Location |
| All | Geocoding API |

---

## 12. Security Considerations

### 12.1 Authentication Security

- [x] Email/password authentication via Firebase
- [x] Secure token management by Firebase SDK
- [x] Role-based access control
- [x] Protected admin routes
- [ ] **Recommended:** Add rate limiting for login attempts
- [ ] **Recommended:** Implement account lockout

### 12.2 Data Security

- [x] Server-side timestamps prevent time manipulation
- [x] Role validation before sensitive operations
- [x] Self-modification prevention for superadmins
- [ ] **Recommended:** Input sanitization for CSV imports
- [ ] **Recommended:** Firestore security rules deployment

### 12.3 Platform Security

| Platform | Security Measure |
|----------|------------------|
| Android | ProGuard/R8 obfuscation |
| iOS | App Transport Security |
| All | HTTPS-only Firebase connections |

### 12.4 Sensitive Data Handling

```dart
// Hardcoded admin emails (should be moved to Firestore)
const superadminEmails = ['sadat46@gmail.com'];  // TODO: Remove
const adminEmails = ['test@gmail.com'];          // TODO: Remove
```

**Recommendation:** Move all admin email configurations to Firestore and use only role-based checks.

---

## 13. Performance Optimization

### 13.1 Implemented Optimizations

| Technique | Implementation | Benefit |
|-----------|---------------|---------|
| **Singleton Services** | All services | Reduced memory, single instance |
| **ValueNotifier** | Time/countdown display | Partial UI rebuilds only |
| **Timer Throttling** | 30-second intervals | Reduced CPU usage |
| **Lazy Loading** | Prayer calculations | On-demand computation |
| **Batch Operations** | Firestore bulk writes | Fewer network requests |

### 13.2 UI Performance

```dart
// ValueNotifier for targeted updates (instead of setState for entire screen)
final ValueNotifier<DateTime> _timeNotifier = ValueNotifier(DateTime.now());
final ValueNotifier<Duration> _countdownNotifier = ValueNotifier(Duration.zero);

// Updates only specific widgets
_timer = Timer.periodic(const Duration(seconds: 30), (timer) {
  _timeNotifier.value = DateTime.now();
  _countdownNotifier.value = _getTimeToNextPrayer();
});
```

### 13.3 Network Optimization

```dart
// Schedule notifications only once per day
if (!_notificationsScheduled || _lastScheduledDate.isBefore(today)) {
  await _notificationService.scheduleAllNotifications(times, jamaatTimes);
  _notificationsScheduled = true;
  _lastScheduledDate = today;
}
```

### 13.4 Recommended Improvements

1. **Implement caching layer** for Firestore responses
2. **Add offline persistence** for jamaat times
3. **Use Firestore listeners** instead of one-time reads
4. **Implement pagination** for user management

---

## 14. Deployment Guide

### 14.1 Android Deployment

```bash
# Generate release APK
flutter build apk --release

# Generate App Bundle (recommended for Play Store)
flutter build appbundle --release

# Output locations
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/bundle/release/app-release.aab
```

**Required configurations:**
- `android/app/build.gradle`: signing config
- `android/app/src/main/AndroidManifest.xml`: permissions

### 14.2 iOS Deployment

```bash
# Build iOS
flutter build ios --release

# Open in Xcode for archive
open ios/Runner.xcworkspace
```

**Required configurations:**
- Apple Developer account
- Provisioning profiles
- `ios/Runner/Info.plist`: permissions

### 14.3 Windows Deployment

```bash
# Build Windows executable
flutter build windows --release

# Build MSIX package
flutter pub run msix:create

# Output
build/windows/runner/Release/
```

### 14.4 Web Deployment

```bash
# Build web
flutter build web --release

# Output (deploy to hosting)
build/web/
```

### 14.5 Environment Variables

Create appropriate Firebase configuration for each environment:
- Development
- Staging
- Production

---

## 15. Testing Strategy

### 15.1 Recommended Test Structure

```
test/
├── unit/
│   ├── services/
│   │   ├── prayer_calculation_service_test.dart
│   │   ├── notification_service_test.dart
│   │   ├── jamaat_service_test.dart
│   │   ├── auth_service_test.dart
│   │   └── settings_service_test.dart
│   └── utils/
│       └── date_time_extension_test.dart
├── widget/
│   ├── screens/
│   │   ├── home_screen_test.dart
│   │   └── settings_screen_test.dart
│   └── widgets/
│       ├── prayer_time_table_test.dart
│       └── prayer_info_card_test.dart
└── integration/
    ├── auth_flow_test.dart
    ├── jamaat_crud_test.dart
    └── notification_scheduling_test.dart
```

### 15.2 Key Test Scenarios

| Category | Test Case |
|----------|-----------|
| **Prayer Calculation** | Verify times for known date/location |
| **Madhab Switch** | Verify Asr time changes correctly |
| **Notifications** | Verify scheduling logic and timing |
| **Authentication** | Login/logout/registration flow |
| **Role Management** | Admin access control |
| **Offline Mode** | Graceful degradation without network |

### 15.3 Testing Tools

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.0        # For mocking
  fake_cloud_firestore:  # For Firestore testing
  network_image_mock:    # For image testing
```

---

## 16. Maintenance & Monitoring

### 16.1 Logging Strategy

```dart
import 'dart:developer' as developer;

// Current logging pattern
developer.log(
  'Message here',
  name: 'ServiceName',
  error: exception,
);
```

### 16.2 Debug Features

**Notification Monitor Screen** (`/lib/screens/notification_monitor_screen.dart`):
- View all scheduled notifications
- Trigger test notifications
- Debug notification channels

### 16.3 Recommended Monitoring

1. **Firebase Crashlytics** - Crash reporting
2. **Firebase Analytics** - User behavior
3. **Firebase Performance** - App performance metrics
4. **Firebase Remote Config** - Feature flags

---

## 17. Future Roadmap

### 17.1 Short-term Improvements

- [ ] Implement comprehensive unit tests
- [ ] Add Firestore offline persistence
- [ ] Create typed data models (replace Maps)
- [ ] Implement proper error boundary widgets
- [ ] Add loading states with shimmer effects

### 17.2 Medium-term Features

- [ ] Prayer time widgets for home screen (Android/iOS)
- [ ] Apple Watch / Wear OS companion app
- [ ] Qibla direction compass
- [ ] Hijri calendar integration
- [ ] Multiple language support (Bengali, Arabic)

### 17.3 Long-term Vision

- [ ] Community features (mosque finder, events)
- [ ] Push notifications via Firebase Cloud Messaging
- [ ] Machine learning for personalized reminders
- [ ] Integration with other Islamic apps

---

## 18. Glossary

| Term | Definition |
|------|------------|
| **Adhan** | Islamic call to prayer |
| **Asr** | Afternoon prayer (3rd daily prayer) |
| **Cantt/Cantonment** | Military station/settlement |
| **Dahwah-e-kubrah** | Islamic noon (midpoint between sunrise and dhuhr) |
| **Dhuhr** | Midday prayer (2nd daily prayer) |
| **Fajr** | Dawn prayer (1st daily prayer) |
| **Hanafi** | One of four major Sunni schools of Islamic jurisprudence |
| **Isha** | Night prayer (5th daily prayer) |
| **Jamaat** | Congregation; group prayer in mosque |
| **Madhab** | School of Islamic jurisprudence |
| **Maghrib** | Sunset prayer (4th daily prayer) |
| **Muslim World League** | International Islamic organization; prayer calculation method |
| **Shafi** | One of four major Sunni schools of Islamic jurisprudence |

---

## 19. Appendix

### 19.1 Supported Cantonments

| # | Name | Maghrib Offset | Region |
|---|------|----------------|--------|
| 1 | Barishal Cantt | 7 min | South |
| 2 | Bogra Cantt | 10 min | North |
| 3 | Chittagong Cantt | 7 min | Southeast |
| 4 | Dhaka Cantt | 13 min | Central |
| 5 | Ghatail Cantt | 7 min | Central |
| 6 | Jashore Cantt | 10 min | Southwest |
| 7 | Kumilla Cantt | 13 min | East |
| 8 | Ramu Cantt | 7 min | Southeast |
| 9 | Rangpur Cantt | 10 min | North |
| 10 | Savar Cantt | 13 min | Central |
| 11 | Sylhet Cantt | 7 min | Northeast |

### 19.2 Sound Modes

| Mode | Value | Prayer Channel | Jamaat Channel |
|------|-------|----------------|----------------|
| Custom Adhan | 0 | allahu_akbar.mp3 | allahu_akbar.mp3 |
| System Default | 1 | System sound | System sound |
| Silent | 2 | No sound | No sound |

### 19.3 Theme Indices

| Index | Theme Name | Description |
|-------|------------|-------------|
| 0 | White | Clean white background |
| 1 | Light | Light green tint |
| 2 | Dark | Dark mode |
| 3 | Green | Rich green theme |

---

## Document Information

| Field | Value |
|-------|-------|
| **Document Version** | 2.0 |
| **Application Version** | 2.0.1+6 |
| **Last Updated** | December 2024 |
| **Author** | Development Team |
| **Status** | Production |

---

*This blueprint serves as the authoritative technical documentation for the Jamaat Time application. For questions or updates, please contact the development team.*
