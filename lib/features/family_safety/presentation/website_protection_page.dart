import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class WebsiteProtectionPage extends StatelessWidget {
  const WebsiteProtectionPage({super.key});

  static const Color _brandGreen = Color(0xFF388E3C);

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.websiteProtectionTitle),
        centerTitle: true,
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Icon(Icons.public_off_outlined, color: _brandGreen, size: 44),
          const SizedBox(height: 16),
          Text(
            strings.websiteProtectionSubtitle,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            strings.websiteProtectionPlaceholder,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[700], height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.shield_outlined),
            label: Text(strings.websiteProtectionEnableCta),
          ),
        ],
      ),
    );
  }
}
