import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/features/family_safety/domain/block_category.dart';
import 'package:jamaat_time/features/family_safety/domain/safety_summary_metrics.dart';

void main() {
  test('short-video blocks today uses focus guard category only', () {
    final rows = <SafetySummaryRow>[
      const SafetySummaryRow(
        dateYyyymmdd: '20260502',
        category: BlockCategory.focusGuardShortVideo,
        count: 2,
      ),
      const SafetySummaryRow(
        dateYyyymmdd: '20260502',
        category: BlockCategory.adult,
        count: 5,
      ),
    ];

    final count = SafetySummaryMetrics.countForDate(
      rows: rows,
      date: DateTime(2026, 5, 2),
      categories: const <BlockCategory>{BlockCategory.focusGuardShortVideo},
    );

    expect(count, 2);
  });

  test('date rollover resets today displayed short-video count', () {
    final rows = <SafetySummaryRow>[
      const SafetySummaryRow(
        dateYyyymmdd: '20260501',
        category: BlockCategory.focusGuardShortVideo,
        count: 7,
      ),
    ];

    final count = SafetySummaryMetrics.countForDate(
      rows: rows,
      date: DateTime(2026, 5, 2),
      categories: const <BlockCategory>{BlockCategory.focusGuardShortVideo},
    );

    expect(count, 0);
  });

  test('website blocks today excludes focus guard short-video category', () {
    final rows = <SafetySummaryRow>[
      const SafetySummaryRow(
        dateYyyymmdd: '20260502',
        category: BlockCategory.focusGuardShortVideo,
        count: 3,
      ),
      const SafetySummaryRow(
        dateYyyymmdd: '20260502',
        category: BlockCategory.proxyBypass,
        count: 4,
      ),
    ];

    final count = SafetySummaryMetrics.countForDate(
      rows: rows,
      date: DateTime(2026, 5, 2),
      categories: websiteProtectionBlockCategories,
    );

    expect(count, 4);
  });
}
