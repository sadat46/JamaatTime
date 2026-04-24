# 🕌 Jamaat Time – Flutter Android App

**Jamaat Time** is a Flutter-based Android app that provides accurate Islamic prayer times and fixed Jamaat times for 10 key locations in Bangladesh. The app features a clean UI, location-based prayer time calculation, admin-controlled Jamaat time updates, and customizable settings.

---

## 📱 Key Features

- 🔍 Auto-calculated prayer start times based on location
- 🕌 Fixed Jamaat times for 10 cities: Kumilla, Bogra, Rangpur, Ramu, Sylhet, Jashore, Savar, Dhaka, Chittagong, Padma
- 🧭 User location detection with permission
- 📅 Displays current time, date, weekday, and time remaining for the next prayer
- 📋 Table layout: Prayer Name | Start Time | Jamaat Time (includes Sunrise & Dahwa-e-Kubra)
- 👤 Optional user login with email
- 🔐 Admin login to manage Jamaat times
- 🎛 Settings tab to switch between light/dark theme and Hanafi/Shafi methods
- 🔄 Firebase-based real-time Jamaat time sync
- 📱 Clean, beautiful,white-background UI
- 📌 3 Bottom Tabs: Home | Settings | Profile

---

## 🔔 Active Initiatives

- **Notification Broadcast System** — Android-only FCM broadcast (manual + auto on jamaat change). See [`NOTIFICATION_BROADCAST_PLAN.md`](NOTIFICATION_BROADCAST_PLAN.md).

---

## 🛠️ Phase-by-Phase Execution Plan

### 📌 Phase 1: Project Initialization
- Create a new Flutter project
- Add necessary dependencies:
  - `firebase_core`, `firebase_auth`, `cloud_firestore`
  - `adhan_dart`, `geolocator`, `intl`, `provider`
- Configure Firebase for Android with `google-services.json`

---

### 📌 Phase 2: Bottom Navigation Structure
- Setup BottomNavigationBar with 3 tabs:
  - 🏠 Home
  - ⚙️ Settings
  - 👤 Profile
- Create empty screen widgets for each tab

---

### 📌 Phase 3: Home Screen UI
- Add header with:
  - Current time
  - Date
  - Weekday
  - Remaining time for next prayer
- Add 3-column prayer table:
  - Prayer Name (including Sunrise & Dahwa-e-Kubra)
  - Prayer Time (from adhan_dart)
  - Jamaat Time (from Firebase)

---

### 📌 Phase 4: Location & Prayer Time Calculation
- Request location permission
- Fetch user location with `geolocator`
- Use `adhan_dart` to calculate prayer times for the day
- Adjust Asr/Isha time based on selected method (Hanafi/Shafi)

---

### 📌 Phase 5: Firestore Integration for Jamaat Times
- Firestore structure:
  ```
  jamaat_times/
    dhaka/
      2024-06-28/
        times: {
          fajr: "04:30",
          dhuhr: "13:00",
          asr: "17:00",
          maghrib: "18:50",
          isha: "20:10",
          ...
        }
  ```
- Dropdown for users to select preferred location
- Load and display Jamaat times from Firestore based on selected city

---

### 📌 Phase 6: Optional User Login (Email)
- Firebase Email/Password login
- Under Profile tab:
  - Show login option
  - Save user's preferred Jamaat location after login

---

### 📌 Phase 7: Settings Tab
- Toggle for light/dark theme
- Toggle for prayer time method (Hanafi/Shafi)
- Save preferences using `SharedPreferences` or Firebase

---

### 📌 Phase 8: Admin Login and Jamaat Update
- Admin login with Firebase Auth
- If admin, show editable Jamaat time input form
- Save updates to Firestore, reflected in real time on user devices

---

### 📌 Phase 9: Final Polish and Deployment
- Add error handling, loading spinners
- Validate flows:
  - Location + calculation
  - Firestore data sync
  - Admin updates
  - Theme + method changes
- Build APK and prepare for Play Store submission

---

## 🧱 Suggested Folder Structure

```
lib/
├── main.dart
├── screens/
│   ├── home_screen.dart
│   ├── profile_screen.dart
│   └── settings_screen.dart
├── services/
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   ├── location_service.dart
│   └── prayer_time_service.dart
├── models/
├── widgets/
├── constants/
└── theme/
```

---

## 🔧 Setup Instructions

1. Clone this repo
   ```bash
   git clone https://github.com/yourusername/jamaat_time.git
   cd jamaat_time
   ```

2. Install dependencies
   ```bash
   flutter pub get
   ```

3. Firebase setup
   - Create Firebase project
   - Add Android app, download `google-services.json` into `android/app/`
   - Enable Firestore and Email/Password Auth

4. Run app
   ```bash
   flutter run
   ```

---

## 📧 Contact

For feedback/support: yourname@email.com
