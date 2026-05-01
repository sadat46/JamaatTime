import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

class FamilySafetyDisclosureDialog {
  const FamilySafetyDisclosureDialog._();

  static Future<bool> showWebsiteProtection(BuildContext context) async {
    final strings = AppLocalizations.of(context);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(strings.websiteProtectionVpnDisclosureTitle),
          content: SingleChildScrollView(
            child: Text(strings.websiteProtectionVpnDisclosureBody),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(strings.familySafetyNotNowCta),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(strings.familySafetyContinueGrantPermissionCta),
            ),
          ],
        );
      },
    );
    return accepted ?? false;
  }
}
