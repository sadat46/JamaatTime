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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await _channel.getActivitySummary(rangeDays: _rangeDays);
    final counts = <BlockCategory, int>{};
    for (final entry in raw) {
      if (entry is! Map) continue;
      final categoryId = entry['category_id'];
      final count = entry['count'];
      if (categoryId is! int || count is! int || count <= 0) continue;
      final category = BlockCategory.values.firstWhere(
        (c) => c.id == categoryId,
        orElse: () => BlockCategory.adult,
      );
      if (category.id != categoryId) continue;
      counts[category] = (counts[category] ?? 0) + count;
    }
    if (!mounted) return;
    setState(() {
      _counts = counts;
      _loading = false;
    });
  }

  Future<void> _clear() async {
    final strings = AppLocalizations.of(context);
    await _channel.clearActivitySummary();
    if (!mounted) return;
    setState(() {
      _counts = const <BlockCategory, int>{};
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(strings.activitySummaryClearedSnack)),
      );
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
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: hasData ? _clear : null,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(strings.activitySummaryClearCta),
                  ),
                ),
              ],
            ),
    );
  }
}
