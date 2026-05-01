import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class DigitalWellbeingPage extends StatelessWidget {
  const DigitalWellbeingPage({super.key});

  static const Color _brandGreen = Color(0xFF388E3C);

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.digitalWellbeingTitle),
        centerTitle: true,
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.self_improvement_outlined, size: 44),
            const SizedBox(height: 16),
            Text(
              strings.digitalWellbeingSubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              strings.digitalWellbeingPlaceholder,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
