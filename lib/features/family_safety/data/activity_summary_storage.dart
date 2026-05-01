import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/block_category.dart';

class ActivitySummaryEntry {
  const ActivitySummaryEntry({
    required this.dateYyyymmdd,
    required this.categoryId,
    required this.count,
  });

  factory ActivitySummaryEntry.fromJson(Map<String, Object?> json) {
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

  Future<List<ActivitySummaryEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(summaryKey);
    if (raw == null || raw.isEmpty) {
      return const <ActivitySummaryEntry>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <ActivitySummaryEntry>[];
    }
    return decoded
        .whereType<Map<String, Object?>>()
        .map(ActivitySummaryEntry.fromJson)
        .where(
          (entry) =>
              entry.dateYyyymmdd.isNotEmpty &&
              entry.categoryId > 0 &&
              entry.count > 0,
        )
        .toList(growable: false);
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
