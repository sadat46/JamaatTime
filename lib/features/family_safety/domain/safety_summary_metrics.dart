import 'block_category.dart';

class SafetySummaryRow {
  const SafetySummaryRow({
    required this.dateYyyymmdd,
    required this.category,
    required this.count,
  });

  final String dateYyyymmdd;
  final BlockCategory category;
  final int count;
}

class SafetySummaryMetrics {
  const SafetySummaryMetrics._();

  static Map<BlockCategory, int> totals(Iterable<SafetySummaryRow> rows) {
    final counts = <BlockCategory, int>{};
    for (final row in rows) {
      if (row.count <= 0) continue;
      counts[row.category] = (counts[row.category] ?? 0) + row.count;
    }
    return counts;
  }

  static int countForDate({
    required Iterable<SafetySummaryRow> rows,
    required DateTime date,
    required Set<BlockCategory> categories,
  }) {
    final dateKey = formatDate(date);
    return rows
        .where(
          (row) =>
              row.dateYyyymmdd == dateKey && categories.contains(row.category),
        )
        .fold<int>(0, (total, row) => total + row.count);
  }

  static String formatDate(DateTime date) {
    final localDate = date.toLocal();
    final year = localDate.year.toString().padLeft(4, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final day = localDate.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }
}
