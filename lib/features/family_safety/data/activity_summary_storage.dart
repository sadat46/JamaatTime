import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ActivitySummaryStorage {
  static const String summaryKey = 'family_safety_activity_summary';

  Future<Map<String, int>> loadCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(summaryKey);
    if (raw == null || raw.isEmpty) {
      return const <String, int>{};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) {
      return const <String, int>{};
    }
    return decoded.map((key, value) => MapEntry(key, value is int ? value : 0));
  }

  Future<void> saveCounts(Map<String, int> counts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(summaryKey, jsonEncode(counts));
  }
}
