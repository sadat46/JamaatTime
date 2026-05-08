import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/block_category.dart';

class ActivitySummaryEntry {
  const ActivitySummaryEntry({
    required this.dateYyyymmdd,
    required this.categoryId,
    required this.count,
  });

  static const Set<String> _forbiddenKeys = <String>{
    'domain',
    'url',
    'host',
    'hostname',
    'qname',
    'query',
    'category',
    'time',
    'timestamp',
    'app',
    'app_usage',
    'app_usage_history',
    'package',
    'package_name',
    'search',
    'search_term',
    'user',
    'user_id',
    'device',
    'device_id',
  };

  factory ActivitySummaryEntry.fromJson(Map<String, Object?> json) {
    assert(() {
      for (final key in json.keys) {
        if (_forbiddenKeys.contains(key)) {
          throw StateError(
            'Activity summary must not store "$key": only (date_yyyymmdd, '
            'category_id, count) are allowed.',
          );
        }
      }
      return true;
    }());
    final dateYyyymmdd = json['date_yyyymmdd'];
    final categoryId = json['category_id'];
    final count = json['count'];
    return ActivitySummaryEntry(
      dateYyyymmdd: dateYyyymmdd is String ? dateYyyymmdd : '',
      categoryId: categoryId is int ? categoryId : 0,
      count: count is int ? count : 0,
    );
  }

  final String dateYyyymmdd;
  final int categoryId;
  final int count;

  Map<String, Object> toJson() {
    return <String, Object>{
      'date_yyyymmdd': dateYyyymmdd,
      'category_id': categoryId,
      'count': count,
    };
  }
}

class ActivitySummaryStorage {
  static const String summaryKey = 'family_safety_activity_summary';
  static const int defaultRetentionDays = 30;

  Future<List<ActivitySummaryEntry>> loadEntries({
    int retentionDays = defaultRetentionDays,
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(summaryKey);
    if (raw == null || raw.isEmpty) {
      return const <ActivitySummaryEntry>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <ActivitySummaryEntry>[];
    }
    final cutoff = ActivitySummaryStorage.formatDate(
      (now ?? DateTime.now()).subtract(Duration(days: retentionDays)),
    );
    final entries = decoded
        .whereType<Map<String, Object?>>()
        .map(ActivitySummaryEntry.fromJson)
        .where(
          (entry) =>
              entry.dateYyyymmdd.isNotEmpty &&
              entry.categoryId > 0 &&
              entry.count > 0 &&
              entry.dateYyyymmdd.compareTo(cutoff) >= 0,
        )
        .toList(growable: false);
    if (entries.length != decoded.length) {
      // Persist the pruned set so the next load doesn't re-walk expired rows.
      await _persist(prefs, entries);
    }
    return entries;
  }

  Future<void> _persist(
    SharedPreferences prefs,
    List<ActivitySummaryEntry> entries,
  ) async {
    final rows = entries.map((entry) => entry.toJson()).toList(growable: false);
    await prefs.setString(summaryKey, jsonEncode(rows));
  }

  Future<void> saveEntries(List<ActivitySummaryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final rows = entries
        .where(
          (entry) =>
              entry.dateYyyymmdd.isNotEmpty &&
              entry.categoryId > 0 &&
              entry.count > 0,
        )
        .map((entry) => entry.toJson())
        .toList(growable: false);
    await prefs.setString(summaryKey, jsonEncode(rows));
  }

  Future<void> recordBlockedCategory({
    required DateTime date,
    required BlockCategory category,
    int incrementBy = 1,
  }) async {
    if (incrementBy <= 0) {
      return;
    }

    final dateKey = formatDate(date);
    final entries = await loadEntries();
    final updated = <ActivitySummaryEntry>[];
    var found = false;

    for (final entry in entries) {
      if (entry.dateYyyymmdd == dateKey && entry.categoryId == category.id) {
        updated.add(
          ActivitySummaryEntry(
            dateYyyymmdd: entry.dateYyyymmdd,
            categoryId: entry.categoryId,
            count: entry.count + incrementBy,
          ),
        );
        found = true;
      } else {
        updated.add(entry);
      }
    }

    if (!found) {
      updated.add(
        ActivitySummaryEntry(
          dateYyyymmdd: dateKey,
          categoryId: category.id,
          count: incrementBy,
        ),
      );
    }

    await saveEntries(updated);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(summaryKey);
  }

  static String formatDate(DateTime date) {
    final localDate = date.toLocal();
    final year = localDate.year.toString().padLeft(4, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final day = localDate.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }
}
