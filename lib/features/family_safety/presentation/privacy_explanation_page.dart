import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class PrivacyExplanationPage extends StatelessWidget {
  const PrivacyExplanationPage({super.key});

  static const Color _brandGreen = Color(0xFF388E3C);

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.privacyExplanationTitle),
        centerTitle: true,
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            strings.familySafetyPrivacyExplanation,
            style: TextStyle(color: Colors.grey[800], height: 1.45),
          ),
          const SizedBox(height: 24),
          Text(
            strings.websiteProtectionLimitsTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            strings.websiteProtectionLimitsBullets,
            style: TextStyle(color: Colors.grey[800], height: 1.5),
          ),
        ],
      ),
    );
  }
}
