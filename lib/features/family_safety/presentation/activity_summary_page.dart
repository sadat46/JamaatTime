import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/block_category.dart';
import '../platform/family_safety_channel.dart';

class ActivitySummaryPage extends StatefulWidget {
  const ActivitySummaryPage({super.key});

  @override
  State<ActivitySummaryPage> createState() => _ActivitySummaryPageState();
}

class _ActivitySummaryPageState extends State<ActivitySummaryPage> {
  static const Color _brandGreen = Color(0xFF388E3C);
  static const int _rangeDays = 30;

  final FamilySafetyChannel _channel = FamilySafetyChannel();
  Map<BlockCategory, int> _counts = const <BlockCategory, int>{};
  List<_DailyCategoryRow> _rows = const <_DailyCategoryRow>[];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await _channel.getActivitySummary(rangeDays: _rangeDays);
    final counts = <BlockCategory, int>{};
    final rows = <_DailyCategoryRow>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final date = entry['date_yyyymmdd'];
      final categoryId = entry['category_id'];
      final count = entry['count'];
      if (date is! String || date.isEmpty) continue;
      if (categoryId is! int || count is! int || count <= 0) continue;
      final category = BlockCategory.values.firstWhere(
        (c) => c.id == categoryId,
        orElse: () => BlockCategory.adult,
      );
      if (category.id != categoryId) continue;
      counts[category] = (counts[category] ?? 0) + count;
      rows.add(_DailyCategoryRow(date, category, count));
    }
    rows.sort((a, b) => b.dateYyyymmdd.compareTo(a.dateYyyymmdd));
    if (!mounted) return;
    setState(() {
      _counts = counts;
      _rows = rows;
      _loading = false;
    });
  }

  Future<void> _confirmAndClear() async {
    final strings = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.activitySummaryClearConfirmTitle),
        content: Text(strings.activitySummaryClearConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.activitySummaryCancelCta),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.activitySummaryClearConfirmCta),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _channel.clearActivitySummary();
    if (!mounted) return;
    setState(() {
      _counts = const <BlockCategory, int>{};
      _rows = const <_DailyCategoryRow>[];
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(strings.activitySummaryClearedSnack)),
      );
  }

  Future<void> _exportCsv() async {
    final strings = AppLocalizations.of(context);
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(strings.activitySummaryExportNothing)),
        );
      return;
    }
    setState(() => _busy = true);
    final csv = _buildCsv(_rows);
    final bytes = Uint8List.fromList(utf8.encode(csv));
    final fileName =
        'jamaat_time_activity_summary_${_today()}.csv';
    String? savedPath;
    try {
      savedPath = await FilePicker.platform.saveFile(
        dialogTitle: strings.activitySummaryExportCta,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: bytes,
      );
    } catch (_) {
      savedPath = null;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final ok = savedPath != null && savedPath.isNotEmpty;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? strings.activitySummaryExportSuccess
                : strings.activitySummaryExportFailed,
          ),
        ),
      );
  }

  String _buildCsv(List<_DailyCategoryRow> rows) {
    final buffer = StringBuffer('date_yyyymmdd,category_id,category,count\n');
    for (final row in rows) {
      buffer
        ..write(row.dateYyyymmdd)
        ..write(',')
        ..write(row.category.id)
        ..write(',')
        ..write(row.category.name)
        ..write(',')
        ..write(row.count)
        ..write('\n');
    }
    return buffer.toString();
  }

  String _today() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  String _categoryLabel(BlockCategory category, AppLocalizations strings) {
    switch (category) {
      case BlockCategory.adult:
        return strings.activitySummaryCategoryAdult;
      case BlockCategory.gambling:
        return strings.activitySummaryCategoryGambling;
      case BlockCategory.proxyBypass:
        return strings.activitySummaryCategoryProxyBypass;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final hasData = _counts.values.any((c) => c > 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.activitySummaryTitle),
        centerTitle: true,
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Icon(Icons.insights_outlined, size: 44),
                const SizedBox(height: 16),
                Text(
                  strings.activitySummarySubtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.activitySummaryRangeLabel(_rangeDays),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 20),
                if (!hasData)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      strings.activitySummaryEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[700], height: 1.4),
                    ),
                  )
                else
                  ...BlockCategory.values.map((category) {
                    final count = _counts[category] ?? 0;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.shield_outlined),
                        title: Text(_categoryLabel(category, strings)),
                        trailing: Text(
                          strings.activitySummaryBlockedCount(count),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 16),
                Text(
                  strings.activitySummaryRetentionNote(_rangeDays),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _busy || !hasData ? null : _exportCsv,
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.file_download_outlined),
                      label: Text(strings.activitySummaryExportCta),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: hasData ? _confirmAndClear : null,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(strings.activitySummaryClearCta),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _DailyCategoryRow {
  const _DailyCategoryRow(this.dateYyyymmdd, this.category, this.count);

  final String dateYyyymmdd;
  final BlockCategory category;
  final int count;
}
