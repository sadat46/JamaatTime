import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/focus_guard_service.dart';
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
  static const String _familyDnsHost = 'family-filter-dns.cleanbrowsing.org';

  final FamilySafetyChannel _channel = FamilySafetyChannel();
  final FocusGuardService _focusGuardService = FocusGuardService();
  Map<BlockCategory, int> _counts = const <BlockCategory, int>{};
  List<_DailyCategoryRow> _rows = const <_DailyCategoryRow>[];
  bool _basicProtectionOn = false;
  bool _advancedProtectionOn = false;
  bool _digitalWellbeingOn = false;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await _channel.getActivitySummary(rangeDays: _rangeDays);
    final dns = await _channel.getPrivateDnsState();
    final vpn = await _channel.getVpnStatus();
    final focusGuard = await _focusGuardService.loadSettings();
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
      _basicProtectionOn =
          dns.isHostnameMode &&
          dns.host?.trim().toLowerCase() == _familyDnsHost;
      _advancedProtectionOn = vpn.running;
      _digitalWellbeingOn = focusGuard.enabled;
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
    setState(() => _busy = true);
    await _channel.clearActivitySummary();
    if (!mounted) return;
    setState(() {
      _counts = const <BlockCategory, int>{};
      _rows = const <_DailyCategoryRow>[];
      _busy = false;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(strings.activitySummaryClearedSnack)),
      );
  }

  String _today() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  int get _websiteBlocksToday {
    final today = _today();
    return _rows
        .where((row) => row.dateYyyymmdd == today)
        .fold<int>(0, (total, row) => total + row.count);
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
                _SummaryCountCard(
                  icon: Icons.today_outlined,
                  title: strings.activitySummaryWebsiteBlocksToday,
                  count: _websiteBlocksToday,
                ),
                const SizedBox(height: 10),
                _SummaryCountCard(
                  icon: Icons.no_adult_content_outlined,
                  title: strings.activitySummaryCategoryAdult,
                  count: _counts[BlockCategory.adult] ?? 0,
                ),
                const SizedBox(height: 10),
                _SummaryCountCard(
                  icon: Icons.casino_outlined,
                  title: strings.activitySummaryCategoryGambling,
                  count: _counts[BlockCategory.gambling] ?? 0,
                ),
                const SizedBox(height: 10),
                _SummaryCountCard(
                  icon: Icons.vpn_lock_outlined,
                  title: strings.activitySummaryCategoryProxyBypass,
                  count: _counts[BlockCategory.proxyBypass] ?? 0,
                ),
                const SizedBox(height: 18),
                _ProtectionStatusCard(
                  title: strings.basicWebsiteProtectionTitle,
                  enabled: _basicProtectionOn,
                ),
                const SizedBox(height: 10),
                _ProtectionStatusCard(
                  title: strings.websiteProtectionTitle,
                  enabled: _advancedProtectionOn,
                ),
                const SizedBox(height: 10),
                _ProtectionStatusCard(
                  title: strings.digitalWellbeingTitle,
                  enabled: _digitalWellbeingOn,
                ),
                const SizedBox(height: 16),
                Text(
                  strings.activitySummaryPrivacyNote,
                  style: TextStyle(
                    color: Colors.grey[700],
                    height: 1.4,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.activitySummaryRetentionNote(_rangeDays),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  overflowAlignment: OverflowBarAlignment.end,
                  spacing: 8,
                  overflowSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: _busy || !hasData ? null : _confirmAndClear,
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

class _SummaryCountCard extends StatelessWidget {
  const _SummaryCountCard({
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(icon, color: _ActivitySummaryPageState._brandGreen),
        title: Text(title),
        trailing: Text(
          '$count',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ProtectionStatusCard extends StatelessWidget {
  const _ProtectionStatusCard({required this.title, required this.enabled});

  final String title;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? const Color(0xFF2E7D32) : Colors.grey.shade700;
    return Card(
      elevation: 1.2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(
          enabled ? Icons.check_circle_outline : Icons.radio_button_unchecked,
          color: color,
        ),
        title: Text(title),
        trailing: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withAlpha(24),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withAlpha(80)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              enabled ? 'ON' : 'OFF',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
