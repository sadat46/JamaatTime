import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class ParentControlPage extends StatelessWidget {
  const ParentControlPage({super.key});

  static const Color _brandGreen = Color(0xFF388E3C);

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.parentControlTitle),
        centerTitle: true,
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          const Icon(Icons.lock_outline, size: 44),
          const SizedBox(height: 16),
          Text(
            strings.parentControlSubtitle,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            strings.parentControlPlaceholder,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[700], height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.pin_outlined),
            label: Text(strings.parentControlSetPin),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.edit_outlined),
            label: Text(strings.parentControlChangePin),
          ),
        ],
      ),
    );
  }
}
