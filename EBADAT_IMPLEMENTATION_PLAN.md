# Jamaat Time - Ebadat Feature Implementation Plan
## Professional Technical Blueprint v1.0

---

## Executive Summary

This document outlines the comprehensive plan to enhance the Jamaat Time application with **Ebadat (ইবাদত)** - an Islamic content module featuring Umrah guides, Quranic Ayats, and Daily Duas. The implementation will restructure the bottom navigation, merge Settings into Profile, and add bookmark functionality for authenticated users.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Current Architecture Analysis](#2-current-architecture-analysis)
3. [Proposed Architecture](#3-proposed-architecture)
4. [Navigation Restructuring](#4-navigation-restructuring)
5. [Ebadat Module Design](#5-ebadat-module-design)
6. [Data Models & Schemas](#6-data-models--schemas)
7. [UI/UX Specifications](#7-uiux-specifications)
8. [Bookmark System](#8-bookmark-system)
9. [Implementation Phases](#9-implementation-phases)
10. [File Structure](#10-file-structure)
11. [Performance Considerations](#11-performance-considerations)
12. [Testing Strategy](#12-testing-strategy)

---

## 1. Project Overview

### 1.1 Objectives

| # | Objective | Priority |
|---|-----------|----------|
| 1 | Move Settings functionality into Profile screen | High |
| 2 | Add "ইবাদত" (Ebadat) tab at middle position in bottom navigation | High |
| 3 | Implement Umrah section with authentic rules and duas | High |
| 4 | Implement 50 important Ayats with Arabic, reference, Bangla pronunciation, meaning | High |
| 5 | Implement 50 important Duas with Arabic, reference, Bangla pronunciation, meaning | High |
| 6 | Add bookmark functionality for logged-in users | Medium |
| 7 | Maintain existing design language and responsiveness | High |

### 1.2 Success Criteria

- Seamless navigation between Home, Ebadat, and Profile
- Offline-first architecture (all Islamic content works without internet)
- Smooth scrolling and fast page loads (<100ms)
- Consistent UI matching existing green theme aesthetic
- Bookmark sync across devices for authenticated users

---

## 2. Current Architecture Analysis

### 2.1 Existing Navigation Structure

```
┌─────────────────────────────────────────────────────────┐
│                    Bottom Navigation                     │
├─────────────────┬─────────────────┬─────────────────────┤
│     🏠 Home     │   ⚙️ Settings   │    👤 Profile       │
│   (index: 0)    │    (index: 1)   │     (index: 2)      │
└─────────────────┴─────────────────┴─────────────────────┘
```

### 2.2 Current File Structure

```
lib/
├── main.dart                    # MainScaffold with 3-tab bottom nav
├── screens/
│   ├── home_screen.dart         # Prayer times display (953 lines)
│   ├── settings_screen.dart     # Theme, madhab, notifications (262 lines)
│   └── profile_screen.dart      # Auth, admin controls (466 lines)
├── services/
│   ├── auth_service.dart        # Firebase Auth
│   ├── settings_service.dart    # SharedPreferences
│   └── ...
└── themes/
    └── green_theme.dart         # Primary: #388E3C, Background: #E8F5E9
```

### 2.3 Design Constants (To Preserve)

| Element | Value | Usage |
|---------|-------|-------|
| Primary Color | `#388E3C` | AppBar, active icons |
| Background | `#E8F5E9` | Scaffold background |
| Card Elevation | `4` | All cards |
| Card Border Radius | `16` | Rounded corners |
| Content Max Width | `500` | Centered content constraint |
| Padding | `24.0` | Screen padding |

---

## 3. Proposed Architecture

### 3.1 New Navigation Structure

```
┌─────────────────────────────────────────────────────────┐
│                    Bottom Navigation                     │
├─────────────────┬─────────────────┬─────────────────────┤
│     🏠 Home     │   ☪️ ইবাদত     │    👤 Profile       │
│   (index: 0)    │    (index: 1)   │     (index: 2)      │
│  Prayer Times   │  Umrah/Ayat/Dua │  Settings + Auth    │
└─────────────────┴─────────────────┴─────────────────────┘
```

### 3.2 Profile Screen Enhancement

```
Profile Screen (Merged with Settings)
├── Settings Section (Collapsible Card)
│   ├── Theme Selection
│   ├── Madhab Selection
│   ├── Prayer Notification Sound
│   └── Jamaat Notification Sound
├── My Bookmarks (If logged in)
│   └── Quick access to saved Ayats/Duas
├── Authentication Section
│   ├── Login/Register (if not logged in)
│   └── User info + Logout (if logged in)
└── Admin Section (If admin role)
    ├── Edit/Import Data
    └── Notification Monitor
```

---

## 4. Navigation Restructuring

### 4.1 Modified main.dart Structure

```dart
// New screen list (3 tabs)
static const List<Widget> _screens = <Widget>[
  HomeScreen(),           // index: 0 - Prayer times
  EbadatScreen(),         // index: 1 - Islamic content (NEW)
  ProfileScreen(),        // index: 2 - Settings + Auth (MERGED)
];

// New bottom navigation items
BottomNavigationBar(
  items: const [
    BottomNavigationBarItem(
      icon: Icon(Icons.home),
      label: 'Home',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.mosque),  // or Icons.auto_awesome for ☪️ effect
      label: 'ইবাদত',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person),
      label: 'Profile',
    ),
  ],
)
```

### 4.2 Settings Migration to Profile

| Current Location | New Location | Notes |
|-----------------|--------------|-------|
| `settings_screen.dart` | Inside `profile_screen.dart` | As collapsible card at top |
| Theme dropdown | Profile → Settings Card | No change in functionality |
| Madhab dropdown | Profile → Settings Card | No change in functionality |
| Sound settings | Profile → Settings Card | No change in functionality |
| Version info | Profile → Bottom footer | Keep as is |

---

## 5. Ebadat Module Design

### 5.1 Ebadat Screen Structure

```
EbadatScreen
├── AppBar: "ইবাদত" (Ebadat)
├── TabBar (3 tabs)
│   ├── ওমরাহ (Umrah)
│   ├── আয়াত (Ayat)
│   └── দোয়া (Dua)
└── TabBarView
    ├── UmrahTab → UmrahScreen
    ├── AyatTab → AyatListScreen
    └── DuaTab → DuaListScreen
```

### 5.2 Visual Hierarchy

```
┌─────────────────────────────────────────────────────────┐
│  ইবাদত                                           [🔖]   │  ← AppBar
├─────────────────────────────────────────────────────────┤
│  ┌──────────┬──────────┬──────────┐                     │
│  │  ওমরাহ   │   আয়াত   │   দোয়া   │  ← TabBar          │
│  └──────────┴──────────┴──────────┘                     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   ┌─────────────────────────────────────────────────┐   │
│   │  📿 আয়াতুল কুরসী                           [🔖] │   │  ← Card
│   │  সূরা আল-বাকারা : ২৫৫                            │   │
│   │  "আল্লাহ, তিনি ছাড়া কোনো উপাস্য নেই..."          │   │
│   └─────────────────────────────────────────────────┘   │
│                                                         │
│   ┌─────────────────────────────────────────────────┐   │
│   │  📿 সূরা আল-ফাতিহা                          [🔖] │   │
│   │  সূরা আল-ফাতিহা : ১-৭                            │   │
│   │  "সমস্ত প্রশংসা আল্লাহর জন্য..."                  │   │
│   └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 5.3 Tab Content Details

#### 5.3.1 Umrah Tab (ওমরাহ)

**Content Structure:**
```
Umrah Section
├── Introduction (ওমরাহর পরিচিতি)
├── Prerequisites (ওমরাহর শর্তাবলী)
├── Step-by-Step Guide
│   ├── 1. Ihram (ইহরাম)
│   │   ├── Rules
│   │   ├── Niyyah Dua (Arabic + Bangla)
│   │   └── Talbiyah (Arabic + Bangla)
│   ├── 2. Tawaf (তাওয়াফ)
│   │   ├── Rules (7 rounds)
│   │   ├── Duas for each round
│   │   └── Istilam Dua
│   ├── 3. Sa'i (সাঈ)
│   │   ├── Rules (7 rounds between Safa-Marwa)
│   │   ├── Dua at Safa
│   │   └── Dua at Marwa
│   └── 4. Halq/Taqsir (হালক/তাকসীর)
│       └── Completion rules
├── Common Duas
│   ├── Entering Masjid al-Haram
│   ├── Seeing Kaaba
│   ├── At Multazam
│   ├── At Maqam Ibrahim
│   └── Zamzam Dua
└── Prohibitions (নিষিদ্ধ বিষয়সমূহ)
```

#### 5.3.2 Ayat Tab (আয়াত)

**50 Important Ayats covering:**
- Ayatul Kursi (2:255)
- Last 2 verses of Surah Baqarah (2:285-286)
- Surah Fatiha (1:1-7)
- Ayats about Jannah (Paradise)
- Ayats about Jahannam (Hell)
- Ayats about Day of Judgment
- Ayats about Tawbah (Repentance)
- Ayats about Sabr (Patience)
- Ayats about Tawakkul (Trust in Allah)
- Ayats about Parents
- Ayats about Salah
- And more...

#### 5.3.3 Dua Tab (দোয়া)

**50 Important Duas covering:**
- Morning/Evening Duas (সকাল/সন্ধ্যার দোয়া)
- Before/After Sleep (ঘুমের আগে/পরে)
- Before/After Eating (খাওয়ার আগে/পরে)
- Entering/Leaving Home (ঘরে প্রবেশ/বের হওয়া)
- Entering/Leaving Mosque (মসজিদে প্রবেশ/বের হওয়া)
- Before/After Wudu (অজুর আগে/পরে)
- Travel Duas (সফরের দোয়া)
- Seeking Forgiveness (ইস্তিগফার)
- Protection Duas (হেফাজতের দোয়া)
- Guidance Duas (হেদায়াতের দোয়া)
- And more...

---

## 6. Data Models & Schemas

### 6.1 Ayat Model

```dart
class AyatModel {
  final int id;
  final String titleBangla;         // "আয়াতুল কুরসী"
  final String surahName;           // "আল-বাকারা"
  final String surahNameArabic;     // "البقرة"
  final int surahNumber;            // 2
  final String ayatNumber;          // "255" or "285-286"
  final String arabicText;          // Full Arabic text
  final String banglaTransliteration; // "আল্লাহু লা ইলাহা ইল্লা হুওয়াল..."
  final String banglaMeaning;       // Full Bangla translation
  final String reference;           // "সূরা আল-বাকারা, আয়াত ২৫৫"
  final String category;            // "জান্নাত", "জাহান্নাম", "তওবা", etc.
  final String? audioUrl;           // Optional audio recitation
  final int displayOrder;           // For sorting
}
```

### 6.2 Dua Model

```dart
class DuaModel {
  final int id;
  final String titleBangla;         // "ঘুম থেকে জাগার দোয়া"
  final String titleArabic;         // Optional Arabic title
  final String arabicText;          // Full Arabic text
  final String banglaTransliteration; // "আলহামদুলিল্লাহিল্লাজি আহইয়ানা..."
  final String banglaMeaning;       // Full Bangla translation
  final String reference;           // "সহীহ বুখারী: ৬৩১৪"
  final String category;            // "সকাল", "সন্ধ্যা", "খাবার", etc.
  final String? audioUrl;           // Optional audio
  final int displayOrder;           // For sorting
}
```

### 6.3 Umrah Section Model

```dart
class UmrahSectionModel {
  final int id;
  final String titleBangla;         // "ইহরাম"
  final String titleArabic;         // "الإحرام"
  final String description;         // Detailed description in Bangla
  final List<UmrahRuleModel> rules; // List of rules
  final List<DuaModel> relatedDuas; // Duas for this section
  final int displayOrder;
}

class UmrahRuleModel {
  final int id;
  final String ruleBangla;
  final String? ruleArabic;
  final bool isMandatory;           // ফরজ/ওয়াজিব vs সুন্নত
}
```

### 6.4 Bookmark Model

```dart
class BookmarkModel {
  final String id;                  // Firestore document ID
  final String oderId;              // Auth user ID
  final String contentType;         // "ayat" | "dua" | "umrah"
  final int contentId;              // Reference to content
  final DateTime createdAt;
  final String? note;               // Optional user note
}
```

### 6.5 Local JSON Data Structure

**File: `assets/data/ayats.json`**
```json
{
  "version": "1.0",
  "lastUpdated": "2025-01-01",
  "ayats": [
    {
      "id": 1,
      "titleBangla": "আয়াতুল কুরসী",
      "surahName": "আল-বাকারা",
      "surahNameArabic": "البقرة",
      "surahNumber": 2,
      "ayatNumber": "255",
      "arabicText": "اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ...",
      "banglaTransliteration": "আল্লাহু লা ইলাহা ইল্লা হুওয়াল হাইয়্যুল কাইয়্যূম...",
      "banglaMeaning": "আল্লাহ, তিনি ছাড়া কোনো উপাস্য নেই...",
      "reference": "সূরা আল-বাকারা, আয়াত ২৫৫",
      "category": "হেফাজত",
      "displayOrder": 1
    }
  ]
}
```

**File: `assets/data/duas.json`**
```json
{
  "version": "1.0",
  "lastUpdated": "2025-01-01",
  "duas": [
    {
      "id": 1,
      "titleBangla": "ঘুম থেকে জাগার দোয়া",
      "arabicText": "الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ",
      "banglaTransliteration": "আলহামদু লিল্লাহিল্লাযী আহইয়ানা বা'দা মা আমাতানা ওয়া ইলাইহিন নুশূর",
      "banglaMeaning": "সমস্ত প্রশংসা সেই আল্লাহর যিনি আমাদের মৃত্যুর (ঘুমের) পর জীবিত করেছেন এবং তাঁর কাছেই আমাদের ফিরে যেতে হবে।",
      "reference": "সহীহ বুখারী: ৬৩১৪",
      "category": "ঘুম",
      "displayOrder": 1
    }
  ]
}
```

---

## 7. UI/UX Specifications

### 7.1 Color Scheme (Maintain Existing)

```dart
// Primary Colors
const Color primaryGreen = Color(0xFF388E3C);      // AppBar, active states
const Color backgroundLight = Color(0xFFE8F5E9);  // Scaffold background
const Color cardBackground = Colors.white;         // Card background

// Accent Colors for Ebadat
const Color ayatAccent = Color(0xFF1565C0);        // Blue for Ayat
const Color duaAccent = Color(0xFF6A1B9A);         // Purple for Dua
const Color umrahAccent = Color(0xFFE65100);       // Orange for Umrah

// Text Colors
const Color arabicTextColor = Color(0xFF1B5E20);  // Dark green for Arabic
const Color banglaTextColor = Color(0xFF212121);  // Near black for Bangla
const Color referenceColor = Color(0xFF757575);   // Grey for reference
```

### 7.2 Typography

```dart
// Arabic Text Style
TextStyle arabicStyle = TextStyle(
  fontFamily: 'Amiri',  // Or 'Scheherazade New'
  fontSize: 24,
  height: 2.0,          // Line height for Arabic
  color: arabicTextColor,
);

// Bangla Text Style
TextStyle banglaStyle = TextStyle(
  fontFamily: 'NotoSansBengali',  // Or 'HindSiliguri'
  fontSize: 16,
  height: 1.6,
  color: banglaTextColor,
);

// Transliteration Style
TextStyle transliterationStyle = TextStyle(
  fontFamily: 'NotoSansBengali',
  fontSize: 14,
  fontStyle: FontStyle.italic,
  color: Colors.grey[700],
);
```

### 7.3 Card Design

```dart
Card(
  elevation: 4,
  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  ),
  child: InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: () => _navigateToDetail(),
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with bookmark icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: titleStyle),
              IconButton(
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                ),
                onPressed: _toggleBookmark,
              ),
            ],
          ),
          // Reference
          Text(reference, style: referenceStyle),
          SizedBox(height: 8),
          // Preview text (truncated)
          Text(
            banglaMeaning,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  ),
)
```

### 7.4 Detail Screen Layout

```
┌─────────────────────────────────────────────────────────┐
│  ← আয়াতুল কুরসী                               🔖 📤    │  ← AppBar
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │                                                 │    │
│  │     اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ        │    │  ← Arabic
│  │     الْقَيُّومُ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ   │    │     (Centered)
│  │                                                 │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
│  📖 সূরা আল-বাকারা, আয়াত ২৫৫                           │  ← Reference
│                                                         │
│  ─────────────────────────────────────────────────────  │
│                                                         │
│  বাংলা উচ্চারণ:                                         │  ← Section
│  আল্লাহু লা ইলাহা ইল্লা হুওয়াল হাইয়্যুল কাইয়্যূম...   │
│                                                         │
│  ─────────────────────────────────────────────────────  │
│                                                         │
│  বাংলা অর্থ:                                            │  ← Section
│  আল্লাহ, তিনি ছাড়া কোনো উপাস্য নেই। তিনি চিরঞ্জীব,     │
│  সর্বসত্তার ধারক। তাঁকে তন্দ্রা ও নিদ্রা স্পর্শ করে না। │
│  আসমান ও জমিনে যা কিছু আছে সবই তাঁর...                  │
│                                                         │
│  ─────────────────────────────────────────────────────  │
│                                                         │
│  [🔊 শুনুন]  [📋 কপি]  [📤 শেয়ার]                        │  ← Action Buttons
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 7.5 Responsive Breakpoints

```dart
// Screen width breakpoints
const double mobileBreakpoint = 600;
const double tabletBreakpoint = 900;
const double desktopBreakpoint = 1200;

// Content max width (maintain existing)
const double contentMaxWidth = 500;

// Responsive font scaling
double getArabicFontSize(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width < mobileBreakpoint) return 22;
  if (width < tabletBreakpoint) return 26;
  return 30;
}
```

---

## 8. Bookmark System

### 8.1 Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Bookmark System                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │   User UI   │───▶│  Bookmark   │───▶│  Firebase   │  │
│  │  (Toggle)   │    │   Service   │    │  Firestore  │  │
│  └─────────────┘    └─────────────┘    └─────────────┘  │
│         │                  │                  │         │
│         │                  ▼                  │         │
│         │         ┌─────────────┐            │         │
│         │         │   Local     │            │         │
│         └────────▶│   Cache     │◀───────────┘         │
│                   │ (Hive/Prefs)│                       │
│                   └─────────────┘                       │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 8.2 Bookmark Service

```dart
class BookmarkService {
  static final BookmarkService _instance = BookmarkService._internal();
  factory BookmarkService() => _instance;
  BookmarkService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Cache for fast lookups
  final Set<String> _bookmarkedIds = {};

  /// Check if user is logged in (bookmark requirement)
  bool get canBookmark => _authService.currentUser != null;

  /// Initialize bookmarks from Firestore
  Future<void> initializeBookmarks() async {
    if (!canBookmark) return;
    
    final userId = _authService.currentUser!.uid;
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('bookmarks')
        .get();
    
    _bookmarkedIds.clear();
    for (var doc in snapshot.docs) {
      _bookmarkedIds.add('${doc['contentType']}_${doc['contentId']}');
    }
  }

  /// Check if content is bookmarked
  bool isBookmarked(String contentType, int contentId) {
    return _bookmarkedIds.contains('${contentType}_$contentId');
  }

  /// Toggle bookmark
  Future<bool> toggleBookmark(String contentType, int contentId) async {
    if (!canBookmark) return false;

    final userId = _authService.currentUser!.uid;
    final key = '${contentType}_$contentId';
    final ref = _firestore
        .collection('users')
        .doc(userId)
        .collection('bookmarks')
        .doc(key);

    if (_bookmarkedIds.contains(key)) {
      await ref.delete();
      _bookmarkedIds.remove(key);
      return false;
    } else {
      await ref.set({
        'contentType': contentType,
        'contentId': contentId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _bookmarkedIds.add(key);
      return true;
    }
  }

  /// Get all bookmarks for a content type
  Future<List<int>> getBookmarkIds(String contentType) async {
    return _bookmarkedIds
        .where((key) => key.startsWith('${contentType}_'))
        .map((key) => int.parse(key.split('_')[1]))
        .toList();
  }
}
```

### 8.3 Firestore Structure

```
firestore/
└── users/
    └── {userId}/
        └── bookmarks/
            ├── ayat_1
            │   ├── contentType: "ayat"
            │   ├── contentId: 1
            │   └── createdAt: Timestamp
            ├── dua_5
            │   ├── contentType: "dua"
            │   ├── contentId: 5
            │   └── createdAt: Timestamp
            └── ...
```

### 8.4 UI Integration

```dart
// In card widget
IconButton(
  icon: Icon(
    _bookmarkService.isBookmarked('ayat', ayat.id)
        ? Icons.bookmark
        : Icons.bookmark_border,
    color: _bookmarkService.isBookmarked('ayat', ayat.id)
        ? primaryGreen
        : Colors.grey,
  ),
  onPressed: _bookmarkService.canBookmark
      ? () async {
          final isNowBookmarked = await _bookmarkService.toggleBookmark(
            'ayat',
            ayat.id,
          );
          setState(() {});
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isNowBookmarked
                    ? 'বুকমার্কে যোগ করা হয়েছে'
                    : 'বুকমার্ক থেকে সরানো হয়েছে',
              ),
              duration: Duration(seconds: 1),
            ),
          );
        }
      : () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('বুকমার্ক করতে লগইন করুন'),
              action: SnackBarAction(
                label: 'লগইন',
                onPressed: () => _navigateToProfile(),
              ),
            ),
          );
        },
)
```

---

## 9. Implementation Phases

### Phase 1: Navigation Restructuring (Day 1-2)

| Task | File | Effort |
|------|------|--------|
| Remove Settings from bottom nav | `main.dart` | 30 min |
| Add Ebadat placeholder screen | `ebadat_screen.dart` | 1 hr |
| Merge Settings into Profile | `profile_screen.dart` | 2 hr |
| Update navigation indices | `main.dart` | 30 min |
| Test navigation flow | - | 1 hr |

**Deliverable:** App with Home → Ebadat → Profile navigation

### Phase 2: Ebadat Screen Structure (Day 3-4)

| Task | File | Effort |
|------|------|--------|
| Create EbadatScreen with TabBar | `ebadat_screen.dart` | 2 hr |
| Create UmrahTab placeholder | `umrah_tab.dart` | 1 hr |
| Create AyatTab placeholder | `ayat_tab.dart` | 1 hr |
| Create DuaTab placeholder | `dua_tab.dart` | 1 hr |
| Style TabBar to match theme | - | 1 hr |
| Test tab switching | - | 1 hr |

**Deliverable:** Ebadat screen with 3 working tabs

### Phase 3: Data Layer (Day 5-7)

| Task | File | Effort |
|------|------|--------|
| Create AyatModel | `models/ayat_model.dart` | 1 hr |
| Create DuaModel | `models/dua_model.dart` | 1 hr |
| Create UmrahSectionModel | `models/umrah_model.dart` | 1 hr |
| Create ayats.json with 50 Ayats | `assets/data/ayats.json` | 4 hr |
| Create duas.json with 50 Duas | `assets/data/duas.json` | 4 hr |
| Create umrah.json | `assets/data/umrah.json` | 3 hr |
| Create EbadatDataService | `services/ebadat_data_service.dart` | 2 hr |
| Test data loading | - | 1 hr |

**Deliverable:** Complete data layer with all Islamic content

### Phase 4: List Screens (Day 8-10)

| Task | File | Effort |
|------|------|--------|
| Create AyatCard widget | `widgets/ayat_card.dart` | 2 hr |
| Create DuaCard widget | `widgets/dua_card.dart` | 2 hr |
| Create UmrahSectionCard widget | `widgets/umrah_card.dart` | 2 hr |
| Implement AyatListScreen | `screens/ayat_list_screen.dart` | 2 hr |
| Implement DuaListScreen | `screens/dua_list_screen.dart` | 2 hr |
| Implement UmrahScreen | `screens/umrah_screen.dart` | 3 hr |
| Add category filtering | - | 2 hr |
| Test list performance | - | 1 hr |

**Deliverable:** Functional list screens with cards

### Phase 5: Detail Screens (Day 11-13)

| Task | File | Effort |
|------|------|--------|
| Create AyatDetailScreen | `screens/ayat_detail_screen.dart` | 3 hr |
| Create DuaDetailScreen | `screens/dua_detail_screen.dart` | 3 hr |
| Create UmrahDetailScreen | `screens/umrah_detail_screen.dart` | 3 hr |
| Implement copy to clipboard | - | 1 hr |
| Implement share functionality | - | 2 hr |
| Add Arabic font support | `pubspec.yaml` | 1 hr |
| Test RTL text rendering | - | 1 hr |

**Deliverable:** Complete detail screens with all content

### Phase 6: Bookmark System (Day 14-16)

| Task | File | Effort |
|------|------|--------|
| Create BookmarkService | `services/bookmark_service.dart` | 3 hr |
| Add Firestore bookmark collection | - | 1 hr |
| Integrate bookmark toggle in cards | - | 2 hr |
| Add "My Bookmarks" in Profile | `profile_screen.dart` | 3 hr |
| Create BookmarksScreen | `screens/bookmarks_screen.dart` | 2 hr |
| Test bookmark sync | - | 2 hr |

**Deliverable:** Working bookmark system

### Phase 7: Polish & Optimization (Day 17-18)

| Task | File | Effort |
|------|------|--------|
| Performance optimization | - | 3 hr |
| Lazy loading for lists | - | 2 hr |
| Add loading shimmer effects | - | 2 hr |
| Edge case testing | - | 2 hr |
| UI consistency review | - | 2 hr |
| Final testing on multiple devices | - | 3 hr |

**Deliverable:** Production-ready implementation

---

## 10. File Structure

### 10.1 New Directory Structure

```
lib/
├── main.dart                           # Updated with 3-tab nav
├── firebase_options.dart
├── core/
│   ├── constants.dart                  # Add Ebadat constants
│   └── extensions/
│       └── date_time_extension.dart
├── models/                             # NEW FOLDER
│   ├── ayat_model.dart
│   ├── dua_model.dart
│   ├── umrah_model.dart
│   └── bookmark_model.dart
├── screens/
│   ├── home_screen.dart
│   ├── profile_screen.dart             # MERGED with settings
│   ├── ebadat/                         # NEW FOLDER
│   │   ├── ebadat_screen.dart          # Main screen with TabBar
│   │   ├── umrah_tab.dart
│   │   ├── ayat_tab.dart
│   │   ├── dua_tab.dart
│   │   ├── ayat_detail_screen.dart
│   │   ├── dua_detail_screen.dart
│   │   └── umrah_detail_screen.dart
│   ├── bookmarks_screen.dart           # NEW
│   ├── admin_jamaat_panel.dart
│   ├── notification_monitor_screen.dart
│   └── user_management_screen.dart
├── services/
│   ├── auth_service.dart
│   ├── settings_service.dart
│   ├── jamaat_service.dart
│   ├── notification_service.dart
│   ├── prayer_calculation_service.dart
│   ├── location_service.dart
│   ├── jamaat_time_utility.dart
│   ├── ebadat_data_service.dart        # NEW
│   └── bookmark_service.dart           # NEW
├── widgets/
│   ├── prayer_time_table.dart
│   ├── prayer_info_card.dart
│   ├── ebadat/                         # NEW FOLDER
│   │   ├── ayat_card.dart
│   │   ├── dua_card.dart
│   │   ├── umrah_section_card.dart
│   │   └── arabic_text_widget.dart
│   └── settings_card.dart              # NEW (extracted from settings)
└── themes/
    ├── white_theme.dart
    ├── light_theme.dart
    ├── dark_theme.dart
    └── green_theme.dart

assets/
├── icon/
│   └── icon.png
├── data/                               # NEW FOLDER
│   ├── ayats.json
│   ├── duas.json
│   └── umrah.json
└── fonts/                              # NEW FOLDER
    ├── Amiri-Regular.ttf
    └── NotoSansBengali-Regular.ttf
```

### 10.2 Files to Delete

```
lib/screens/settings_screen.dart        # Merged into profile_screen.dart
```

### 10.3 pubspec.yaml Additions

```yaml
flutter:
  assets:
    - assets/icon/
    - assets/data/
    
  fonts:
    - family: Amiri
      fonts:
        - asset: assets/fonts/Amiri-Regular.ttf
    - family: NotoSansBengali
      fonts:
        - asset: assets/fonts/NotoSansBengali-Regular.ttf

dependencies:
  share_plus: ^7.2.1          # For sharing content
  flutter_html: ^3.0.0-beta.2 # For rendering Arabic with diacritics (optional)
```

---

## 11. Performance Considerations

### 11.1 Optimization Strategies

| Area | Strategy | Implementation |
|------|----------|----------------|
| **Data Loading** | Lazy loading | Load data only when tab is first accessed |
| **List Performance** | ListView.builder | Use builder pattern for all lists |
| **Image Caching** | N/A | No images in Islamic content |
| **Memory** | Dispose controllers | Properly dispose TabController, ScrollController |
| **JSON Parsing** | Compute isolate | Use `compute()` for large JSON parsing |
| **Bookmarks** | Local cache | Cache bookmark IDs in memory |

### 11.2 Lightweight Requirements

```dart
// Use const constructors where possible
const AyatCard({Key? key, required this.ayat}) : super(key: key);

// Avoid unnecessary rebuilds
@override
bool operator ==(Object other) =>
    identical(this, other) ||
    other is AyatModel && id == other.id;

// Use selective rebuilds
ValueListenableBuilder<bool>(
  valueListenable: _isBookmarkedNotifier,
  builder: (context, isBookmarked, child) {
    return Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border);
  },
)
```

### 11.3 Smooth Scrolling

```dart
// Use physics for smooth scrolling
ListView.builder(
  physics: const BouncingScrollPhysics(),
  cacheExtent: 500,  // Pre-render items
  itemBuilder: (context, index) => AyatCard(ayat: ayats[index]),
)
```

---

## 12. Testing Strategy

### 12.1 Unit Tests

```dart
// test/unit/services/ebadat_data_service_test.dart
void main() {
  group('EbadatDataService', () {
    test('loads 50 ayats from JSON', () async {
      final service = EbadatDataService();
      final ayats = await service.loadAyats();
      expect(ayats.length, 50);
    });

    test('loads 50 duas from JSON', () async {
      final service = EbadatDataService();
      final duas = await service.loadDuas();
      expect(duas.length, 50);
    });

    test('filters ayats by category', () async {
      final service = EbadatDataService();
      final jannah = await service.getAyatsByCategory('জান্নাত');
      expect(jannah.every((a) => a.category == 'জান্নাত'), true);
    });
  });
}
```

### 12.2 Widget Tests

```dart
// test/widget/ebadat/ayat_card_test.dart
void main() {
  testWidgets('AyatCard displays title and reference', (tester) async {
    final ayat = AyatModel(
      id: 1,
      titleBangla: 'আয়াতুল কুরসী',
      reference: 'সূরা আল-বাকারা : ২৫৫',
      // ... other fields
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: AyatCard(ayat: ayat))),
    );

    expect(find.text('আয়াতুল কুরসী'), findsOneWidget);
    expect(find.text('সূরা আল-বাকারা : ২৫৫'), findsOneWidget);
  });
}
```

### 12.3 Integration Tests

```dart
// test/integration/ebadat_flow_test.dart
void main() {
  testWidgets('Complete Ebadat navigation flow', (tester) async {
    await tester.pumpWidget(const MyApp());
    
    // Navigate to Ebadat
    await tester.tap(find.text('ইবাদত'));
    await tester.pumpAndSettle();
    
    // Verify TabBar visible
    expect(find.text('ওমরাহ'), findsOneWidget);
    expect(find.text('আয়াত'), findsOneWidget);
    expect(find.text('দোয়া'), findsOneWidget);
    
    // Tap Ayat tab
    await tester.tap(find.text('আয়াত'));
    await tester.pumpAndSettle();
    
    // Verify list loads
    expect(find.byType(AyatCard), findsWidgets);
    
    // Tap first card
    await tester.tap(find.byType(AyatCard).first);
    await tester.pumpAndSettle();
    
    // Verify detail screen
    expect(find.byType(AyatDetailScreen), findsOneWidget);
  });
}
```

---

## Summary

This implementation plan provides a comprehensive roadmap for adding the Ebadat feature to the Jamaat Time application. The plan ensures:

1. **Minimal Disruption** - Settings moved to Profile without losing functionality
2. **Consistent Design** - New screens match existing green theme aesthetic
3. **Performance** - Lightweight, offline-first architecture
4. **Scalability** - Modular structure allows easy content additions
5. **User Experience** - Bookmark system for personalization

**Estimated Total Effort:** 18 working days

**Key Dependencies:**
- 50 Ayats content (Arabic + Bangla)
- 50 Duas content (Arabic + Bangla)
- Umrah rules and duas content
- Arabic font files (Amiri)
- Bengali font files (NotoSansBengali)

---

*Document Version: 1.0*
*Last Updated: December 2025*
*Author: Development Team*
