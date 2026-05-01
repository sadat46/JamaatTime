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
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          strings.familySafetyPrivacyExplanation,
          style: TextStyle(color: Colors.grey[800], height: 1.45),
        ),
      ),
    );
  }
}
