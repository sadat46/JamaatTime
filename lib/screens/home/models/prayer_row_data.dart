/// Row type for conditional styling.
enum PrayerRowType { prayer, info, sahriIftar, forbidden }

/// Pre-computed data for a prayer table row.
class PrayerRowData {
  final String name;
  final String timeStr;
  final String jamaatStr;
  final bool isCurrent;
  final PrayerRowType type;
  final String? endTimeStr;

  const PrayerRowData({
    required this.name,
    required this.timeStr,
    required this.jamaatStr,
    required this.isCurrent,
    this.type = PrayerRowType.prayer,
    this.endTimeStr,
  });
}
