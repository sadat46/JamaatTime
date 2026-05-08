import 'package:flutter/material.dart';

import '../core/constants.dart';

class CalendarShareRow {
  const CalendarShareRow({
    required this.name,
    required this.prayer,
    required this.jamaat,
  });

  final String name;
  final String prayer;
  final String jamaat;
}

class CalendarShareCard extends StatelessWidget {
  const CalendarShareCard({
    super.key,
    required this.locationLabel,
    required this.gregorianDate,
    required this.weekday,
    required this.hijriDate,
    required this.banglaDate,
    required this.rows,
  });

  final String locationLabel;
  final String gregorianDate;
  final String weekday;
  final String hijriDate;
  final String banglaDate;
  final List<CalendarShareRow> rows;

  static const double _cardWidth = 720;

  String _normalizeJamaat(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '-' || trimmed == '--') {
      return '—';
    }
    return trimmed;
  }

  TableRow _buildHeaderRow() {
    const headerStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: AppConstants.brandGreenDark,
    );
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text('Name', style: headerStyle),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Prayer',
            style: headerStyle,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Jamaat',
            style: headerStyle,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  TableRow _buildDataRow(CalendarShareRow row) {
    const cellStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    );
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(row.name, style: cellStyle),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            row.prayer,
            style: cellStyle,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            _normalizeJamaat(row.jamaat),
            style: cellStyle,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: const MediaQueryData(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: _cardWidth,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppConstants.brandGreen.withValues(alpha: 0.18),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Prayer & Jamaat Time',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppConstants.brandGreenDark,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  locationLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '$gregorianDate,  $weekday',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hijriDate,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  banglaDate,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 20),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(2),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [_buildHeaderRow()],
                ),
                Container(height: 1, color: Colors.black87),
                const SizedBox(height: 4),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(2),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: rows.map(_buildDataRow).toList(),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Shared from Jamaat Time',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
