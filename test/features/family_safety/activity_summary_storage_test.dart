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

  test('rejects rows containing forbidden domain-leak fields', () {
    expect(
      () => ActivitySummaryEntry.fromJson(<String, Object?>{
        'date_yyyymmdd': '20260501',
        'category_id': 1,
        'count': 1,
        'domain': 'example.com',
      }),
      throwsA(isA<StateError>()),
    );

    for (final key in const <String>[
      'url',
      'host',
      'package_name',
      'qname',
      'query',
      'search_term',
      'time',
      'user_id',
      'device_id',
    ]) {
      expect(
        () => ActivitySummaryEntry.fromJson(<String, Object?>{
          'date_yyyymmdd': '20260501',
          'category_id': 1,
          'count': 1,
          key: 'leaked',
        }),
        throwsA(isA<StateError>()),
        reason: 'forbidden key "$key" should be rejected',
      );
    }
  });

  test('prunes rows older than the retention window on load', () async {
    final storage = ActivitySummaryStorage();
    final now = DateTime(2026, 6, 15);
    final cutoffEdge = ActivitySummaryStorage.formatDate(
      now.subtract(const Duration(days: 30)),
    );
    final beforeCutoff = ActivitySummaryStorage.formatDate(
      now.subtract(const Duration(days: 31)),
    );

    await storage.saveEntries([
      ActivitySummaryEntry(dateYyyymmdd: cutoffEdge, categoryId: 1, count: 5),
      ActivitySummaryEntry(dateYyyymmdd: beforeCutoff, categoryId: 2, count: 9),
      ActivitySummaryEntry(dateYyyymmdd: '20260615', categoryId: 3, count: 1),
    ]);

    final entries = await storage.loadEntries(now: now);
    expect(entries, hasLength(2));
    expect(
      entries.map((e) => e.dateYyyymmdd),
      everyElement(isNot(beforeCutoff)),
    );
  });
}
