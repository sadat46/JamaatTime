import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class SafeSearchSetupPage extends StatelessWidget {
  const SafeSearchSetupPage({super.key});

  static const Color _brandGreen = Color(0xFF388E3C);

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.safeSearchSetupTitle),
        centerTitle: true,
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.travel_explore_outlined, size: 44),
            const SizedBox(height: 16),
            Text(
              strings.safeSearchSetupSubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              strings.safeSearchSetupPlaceholder,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
