import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class ActivitySummaryPage extends StatelessWidget {
  const ActivitySummaryPage({super.key});

  static const Color _brandGreen = Color(0xFF388E3C);

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.activitySummaryTitle),
        centerTitle: true,
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.insights_outlined, size: 44),
            const SizedBox(height: 16),
            Text(
              strings.activitySummarySubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              strings.activitySummaryPlaceholder,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
