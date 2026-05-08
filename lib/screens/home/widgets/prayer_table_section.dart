import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/app_theme_tokens.dart';
import '../../../core/locale_text.dart';
import '../../../utils/locale_digits.dart';
import '../../../widgets/shared_ui_widgets.dart';
import '../home_controller.dart';
import '../models/prayer_row_data.dart';
import 'prayer_card.dart';

class PrayerTableSection extends StatefulWidget {
  const PrayerTableSection({super.key, required this.controller});

  final HomeController controller;

  @override
  State<PrayerTableSection> createState() => _PrayerTableSectionState();
}

class _PrayerTableSectionState extends State<PrayerTableSection> {
  List<PrayerRowData>? _lastRows;
  Widget? _cachedRows;
  String? _lastLocaleCode;

  @override
  void didUpdateWidget(covariant PrayerTableSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _lastRows = null;
      _cachedRows = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final prayerBandColor = isDarkMode
        ? const Color(0xFF18261E)
        : AppColors.cardBackground;
    final prayerBandBorder = isDarkMode
        ? const Color(0xFF2A4334)
        : AppColors.borderLight;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: prayerBandColor,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: prayerBandBorder),
        boxShadow: isDarkMode ? const [] : AppShadows.softCard,
      ),
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final lastJamaatUpdate = widget.controller.lastJamaatUpdate;
          final isLoadingJamaat = widget.controller.isLoadingJamaat;
          final jamaatError = widget.controller.jamaatError;
          final rows = widget.controller.prayerTableData;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SectionHeader(
                    title: context.tr(bn: 'নামাজের সময়', en: 'Prayer Times'),
                  ),
                  if (lastJamaatUpdate != null && !isLoadingJamaat)
                    Text(
                      '${context.tr(bn: 'সর্বশেষ আপডেট', en: 'Last updated')}: ${_localizedDigitsForContext(context, DateFormat('HH:mm').format(lastJamaatUpdate))}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
              if (isLoadingJamaat)
                const Center(child: CircularProgressIndicator()),
              if (jamaatError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    jamaatError,
                    style: const TextStyle(color: Colors.orange),
                  ),
                ),
              _buildRows(context, rows),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRows(BuildContext context, List<PrayerRowData> rows) {
    final localeCode = Localizations.localeOf(context).languageCode;
    if (_cachedRows != null &&
        _lastLocaleCode == localeCode &&
        _rowsEqual(_lastRows, rows)) {
      return _cachedRows!;
    }

    _lastRows = List<PrayerRowData>.of(rows);
    _lastLocaleCode = localeCode;
    _cachedRows = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: PrayerCard(row: row),
            ),
          )
          .toList(growable: false),
    );
    return _cachedRows!;
  }

  bool _rowsEqual(List<PrayerRowData>? previous, List<PrayerRowData> next) {
    if (previous == null || previous.length != next.length) {
      return false;
    }
    for (var index = 0; index < previous.length; index++) {
      final a = previous[index];
      final b = next[index];
      if (a.name != b.name ||
          a.timeStr != b.timeStr ||
          a.jamaatStr != b.jamaatStr ||
          a.isCurrent != b.isCurrent ||
          a.type != b.type ||
          a.endTimeStr != b.endTimeStr) {
        return false;
      }
    }
    return true;
  }

  String _localizedDigitsForContext(BuildContext context, String value) {
    if (value == '-') return value;
    return LocaleDigits.localize(value, Localizations.localeOf(context));
  }
}
