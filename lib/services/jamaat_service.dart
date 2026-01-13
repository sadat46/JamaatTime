import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import '../core/constants.dart';

class JamaatService {
  static final JamaatService _instance = JamaatService._internal();
  factory JamaatService() => _instance;
  JamaatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Mock storage for testing when Firebase is not available
  static final Map<String, Map<String, Map<String, String>>> _mockStorage = {};

  // In-memory cache for jamaat times (reduces network calls)
  static final Map<String, _CachedJamaatTimes> _cache = {};

  /// Get cache expiry duration based on target date (Smart Cache)
  /// - Today: 30 minutes (data may change)
  /// - Future: 6 hours (unlikely to change)
  /// - Past: 24 hours (won't change)
  static Duration _getSmartCacheExpiry(DateTime targetDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);

    if (target == today) {
      return const Duration(minutes: 30);
    } else if (target.isAfter(today)) {
      return const Duration(hours: 6);
    } else {
      return const Duration(hours: 24);
    }
  }

  /// Save jamaat times for a specific city and date
  Future<void> saveJamaatTimes({
    required String city,
    required DateTime date,
    required Map<String, String> times,
  }) async {
    try {
      final dateString = _formatDate(date);
      final cityKey = city.toLowerCase().replaceAll(' ', '_');
      
      // Try Firebase first
      try {
        await _firestore
            .collection('jamaat_times')
            .doc(cityKey)
            .collection('daily_times')
            .doc(dateString)
            .set({
          'date': dateString,
          'city': city,
          'times': times,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        developer.log(
          'Jamaat times saved to Firebase for $city on $dateString',
          name: 'JamaatService',
        );
      } catch (firebaseError) {
        // Fallback to mock storage if Firebase fails
        developer.log(
          'Firebase save failed, using mock storage: $firebaseError',
          name: 'JamaatService',
        );
        
        if (!_mockStorage.containsKey(cityKey)) {
          _mockStorage[cityKey] = {};
        }
        _mockStorage[cityKey]![dateString] = times;
        
        developer.log(
          'Jamaat times saved to mock storage for $city on $dateString',
          name: 'JamaatService',
        );
      }
    } catch (e) {
      developer.log(
        'Error saving jamaat times for $city: $e',
        name: 'JamaatService',
        error: e,
      );
      rethrow;
    }
  }

  /// Get jamaat times for a specific city and date (with caching)
  Future<Map<String, String>?> getJamaatTimes({
    required String city,
    required DateTime date,
    bool forceRefresh = false,
  }) async {
    try {
      final cacheKey = _getCacheKey(city, date);

      // Check cache first (skip if forceRefresh is true)
      if (!forceRefresh && _cache.containsKey(cacheKey)) {
        final cached = _cache[cacheKey]!;
        final cacheExpiry = _getSmartCacheExpiry(date);
        if (!cached.isExpired(cacheExpiry)) {
          developer.log(
            'Cache hit for $city on ${_formatDate(date)} (expiry: ${cacheExpiry.inMinutes}min)',
            name: 'JamaatService',
          );
          return Map<String, String>.from(cached.times);
        } else {
          // Remove expired cache entry
          _cache.remove(cacheKey);
        }
      }

      // Log if force refresh was requested
      if (forceRefresh) {
        developer.log(
          'Force refresh requested for $city on ${_formatDate(date)}',
          name: 'JamaatService',
        );
      }

      final dateString = _formatDate(date);
      final cityKey = city.toLowerCase().replaceAll(' ', '_');

      // Try Firebase first
      try {
        final doc = await _firestore
            .collection('jamaat_times')
            .doc(cityKey)
            .collection('daily_times')
            .doc(dateString)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          final times = Map<String, String>.from(data['times'] ?? {});

          // Cache the result
          _cache[cacheKey] = _CachedJamaatTimes(
            times: times,
            cachedAt: DateTime.now(),
          );

          return times;
        }
      } catch (firebaseError) {
        // Fallback to mock storage if Firebase fails
        developer.log(
          'Firebase get failed, using mock storage: $firebaseError',
          name: 'JamaatService',
        );

        if (_mockStorage.containsKey(cityKey) && _mockStorage[cityKey]!.containsKey(dateString)) {
          final times = Map<String, String>.from(_mockStorage[cityKey]![dateString]!);

          // Cache mock result too
          _cache[cacheKey] = _CachedJamaatTimes(
            times: times,
            cachedAt: DateTime.now(),
          );

          return times;
        }
      }

      return null;
    } catch (e) {
      developer.log(
        'Error getting jamaat times for $city: $e',
        name: 'JamaatService',
        error: e,
      );
      return null;
    }
  }

  /// Clear the jamaat times cache
  void clearCache() {
    _cache.clear();
  }

  /// Update a single prayer's jamaat time with proper schema and cache clearing
  Future<void> updateSingleJamaatTime({
    required String city,
    required DateTime date,
    required String prayerName,
    required String time,
  }) async {
    final cityKey = city.toLowerCase().replaceAll(' ', '_');
    final dateString = _formatDate(date);

    // 1. Clear cache for this city/date
    final cacheKey = _getCacheKey(city, date);
    _cache.remove(cacheKey);

    // 2. Save with correct schema (nested under 'times')
    await _firestore
        .collection('jamaat_times')
        .doc(cityKey)
        .collection('daily_times')
        .doc(dateString)
        .set({
      'times': {prayerName.toLowerCase(): time},
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    developer.log(
      'Updated $prayerName time for $city on $dateString: $time',
      name: 'JamaatService',
    );
  }

  /// Get jamaat times for a date range
  Future<Map<String, Map<String, String>>> getJamaatTimesRange({
    required String city,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final cityKey = city.toLowerCase().replaceAll(' ', '_');
      final startString = _formatDate(startDate);
      final endString = _formatDate(endDate);
      
      final query = await _firestore
          .collection('jamaat_times')
          .doc(cityKey)
          .collection('daily_times')
          .where('date', isGreaterThanOrEqualTo: startString)
          .where('date', isLessThanOrEqualTo: endString)
          .get();

      final Map<String, Map<String, String>> result = {};
      for (final doc in query.docs) {
        final data = doc.data();
        final date = data['date'] as String;
        final times = Map<String, String>.from(data['times'] ?? {});
        result[date] = times;
      }

      return result;
    } catch (e) {
      developer.log(
        'Error getting jamaat times range for $city: $e',
        name: 'JamaatService',
        error: e,
      );
      return {};
    }
  }

  /// Bulk save jamaat times for multiple dates
  Future<void> bulkSaveJamaatTimes({
    required String city,
    required Map<String, Map<String, String>> timesByDate,
  }) async {
    try {
      final cityKey = city.toLowerCase().replaceAll(' ', '_');
      
      // Try Firebase first
      try {
        final batch = _firestore.batch();
        
        for (final entry in timesByDate.entries) {
          final dateString = entry.key;
          final times = entry.value;
          
          final docRef = _firestore
              .collection('jamaat_times')
              .doc(cityKey)
              .collection('daily_times')
              .doc(dateString);
          
          batch.set(docRef, {
            'date': dateString,
            'city': city,
            'times': times,
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
        
        await batch.commit();
        developer.log(
          'Bulk saved ${timesByDate.length} days of jamaat times to Firebase for $city',
          name: 'JamaatService',
        );
      } catch (firebaseError) {
        // Fallback to mock storage if Firebase fails
        developer.log(
          'Firebase bulk save failed, using mock storage: $firebaseError',
          name: 'JamaatService',
        );
        
        if (!_mockStorage.containsKey(cityKey)) {
          _mockStorage[cityKey] = {};
        }
        
        for (final entry in timesByDate.entries) {
          final dateString = entry.key;
          final times = entry.value;
          _mockStorage[cityKey]![dateString] = times;
        }
        
        developer.log(
          'Bulk saved ${timesByDate.length} days of jamaat times to mock storage for $city',
          name: 'JamaatService',
        );
      }
    } catch (e) {
      developer.log(
        'Error bulk saving jamaat times for $city: $e',
        name: 'JamaatService',
        error: e,
      );
      rethrow;
    }
  }

  /// Get all available cities with jamaat times
  Future<List<String>> getAvailableCities() async {
    try {
      final query = await _firestore.collection('jamaat_times').get();
      return query.docs.map((doc) => doc.id.replaceAll('_', ' ')).toList();
    } catch (e) {
      developer.log(
        'Error getting available cities: $e',
        name: 'JamaatService',
        error: e,
      );
      return [];
    }
  }

  /// Check if jamaat times exist for a city and date
  Future<bool> hasJamaatTimes({
    required String city,
    required DateTime date,
  }) async {
    try {
      final dateString = _formatDate(date);
      final cityKey = city.toLowerCase().replaceAll(' ', '_');
      
      final doc = await _firestore
          .collection('jamaat_times')
          .doc(cityKey)
          .collection('daily_times')
          .doc(dateString)
          .get();

      return doc.exists;
    } catch (e) {
      developer.log(
        'Error checking jamaat times existence for $city: $e',
        name: 'JamaatService',
        error: e,
      );
      return false;
    }
  }

  /// Delete jamaat times for a specific city and date
  Future<void> deleteJamaatTimes({
    required String city,
    required DateTime date,
  }) async {
    try {
      final dateString = _formatDate(date);
      final cityKey = city.toLowerCase().replaceAll(' ', '_');
      
      await _firestore
          .collection('jamaat_times')
          .doc(cityKey)
          .collection('daily_times')
          .doc(dateString)
          .delete();

      developer.log(
        'Jamaat times deleted for $city on $dateString',
        name: 'JamaatService',
      );
    } catch (e) {
      developer.log(
        'Error deleting jamaat times for $city: $e',
        name: 'JamaatService',
        error: e,
      );
      rethrow;
    }
  }

  /// Generate jamaat times for all cantts for a year
  Future<void> generateYearlyJamaatTimes({
    required int year,
    Map<String, Map<String, String>>? defaultTimes,
  }) async {
    try {
      final startDate = DateTime(year, 1, 1);
      final endDate = DateTime(year, 12, 31);
      
      for (final cantt in AppConstants.canttNames) {
        final timesByDate = <String, Map<String, String>>{};
        
        DateTime currentDate = startDate;
        while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
          final dateString = _formatDate(currentDate);
          
          // Use default times or generate based on prayer calculation
          final times = defaultTimes?[cantt] ?? {
            'fajr': '05:15',
            'dhuhr': '12:15',
            'asr': '15:45',
            'maghrib': '18:15',
            'isha': '19:45',
          };
          
          timesByDate[dateString] = times;
          currentDate = currentDate.add(const Duration(days: 1));
        }
        
        await bulkSaveJamaatTimes(city: cantt, timesByDate: timesByDate);
      }
      
      developer.log(
        'Generated yearly jamaat times for all cantts for year $year',
        name: 'JamaatService',
      );
    } catch (e) {
      developer.log(
        'Error generating yearly jamaat times: $e',
        name: 'JamaatService',
        error: e,
      );
      rethrow;
    }
  }

  /// Helper method to format date as YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Generate cache key from city and date
  String _getCacheKey(String city, DateTime date) {
    return '${city.toLowerCase().replaceAll(' ', '_')}_${_formatDate(date)}';
  }
}

/// Cache entry for jamaat times with expiration
class _CachedJamaatTimes {
  final Map<String, String> times;
  final DateTime cachedAt;

  _CachedJamaatTimes({required this.times, required this.cachedAt});

  bool isExpired(Duration expiry) {
    return DateTime.now().difference(cachedAt) > expiry;
  }
} 