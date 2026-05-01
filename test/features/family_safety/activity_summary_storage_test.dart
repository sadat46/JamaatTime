import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/features/family_safety/data/activity_summary_storage.dart';
import 'package:jamaat_time/features/family_safety/domain/block_category.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores only date, category id, and count rows', () async {
    final storage = ActivitySummaryStorage();

    await storage.recordBlockedCategory(
      date: DateTime(2026, 5, 1, 22, 30),
      category: BlockCategory.adult,
    );
    await storage.recordBlockedCategory(
      date: DateTime(2026, 5, 1, 23, 45),
      category: BlockCategory.adult,
      incrementBy: 2,
    );

    final entries = await storage.loadEntries();
    expect(entries, hasLength(1));
    expect(entries.single.dateYyyymmdd, '20260501');
    expect(entries.single.categoryId, BlockCategory.adult.id);
    expect(entries.single.count, 3);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(ActivitySummaryStorage.summaryKey);
    final decoded = jsonDecode(raw!) as List<Object?>;
    final row = decoded.single! as Map<String, Object?>;

    expect(row.keys, containsAll({'date_yyyymmdd', 'category_id', 'count'}));
    expect(row.keys, hasLength(3));
  });

  test('drops invalid rows and ignores non-positive increments', () async {
    final storage = ActivitySummaryStorage();
    await storage.saveEntries(const [
      ActivitySummaryEntry(dateYyyymmdd: '', categoryId: 1, count: 1),
      ActivitySummaryEntry(dateYyyymmdd: '20260501', categoryId: 0, count: 1),
      ActivitySummaryEntry(dateYyyymmdd: '20260501', categoryId: 1, count: 0),
    ]);

    await storage.recordBlockedCategory(
      date: DateTime(2026, 5, 1),
      category: BlockCategory.gambling,
      incrementBy: 0,
    );

    expect(await storage.loadEntries(), isEmpty);
  });
}
