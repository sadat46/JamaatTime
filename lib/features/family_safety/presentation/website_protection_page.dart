import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../platform/family_safety_channel.dart';
import 'widgets/disclosure_dialog.dart';

class WebsiteProtectionPage extends StatefulWidget {
  const WebsiteProtectionPage({super.key});

  @override
  State<WebsiteProtectionPage> createState() => _WebsiteProtectionPageState();
}

class _WebsiteProtectionPageState extends State<WebsiteProtectionPage> {
  static const Color _brandGreen = Color(0xFF388E3C);

  final FamilySafetyChannel _channel = FamilySafetyChannel();

  VpnStatus? _status;
  bool _loading = true;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await _channel.getVpnStatus();
    if (!mounted) {
      return;
    }
    setState(() {
      _status = status;
      _loading = false;
    });
  }

  Future<void> _requestVpnPermission() async {
    final strings = AppLocalizations.of(context);
    final accepted = await FamilySafetyDisclosureDialog.showWebsiteProtection(
      context,
    );
    if (!accepted || !mounted) {
      return;
    }

    setState(() {
      _requesting = true;
    });

    final granted = await _channel.requestVpnPermission();
    if (!mounted) {
      return;
    }

    setState(() {
      _requesting = false;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? strings.websiteProtectionVpnPermissionGranted
                : strings.websiteProtectionVpnPermissionDenied,
          ),
        ),
      );
    await _loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final status = _status;
    final permissionReady = status?.prepared == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.websiteProtectionTitle),
        centerTitle: true,
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                Icon(Icons.public_off_outlined, color: _brandGreen, size: 44),
                const SizedBox(height: 16),
                Text(
                  strings.websiteProtectionSubtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  strings.websiteProtectionPlaceholder,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700], height: 1.4),
                ),
                const SizedBox(height: 20),
                _VpnPermissionStatusPanel(
                  permissionReady: permissionReady,
                  brandGreen: _brandGreen,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _requesting ? null : _requestVpnPermission,
                  icon: _requesting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.shield_outlined),
                  label: Text(strings.websiteProtectionEnableCta),
                ),
              ],
            ),
    );
  }
}

class _VpnPermissionStatusPanel extends StatelessWidget {
  const _VpnPermissionStatusPanel({
    required this.permissionReady,
    required this.brandGreen,
  });

  final bool permissionReady;
  final Color brandGreen;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final color = permissionReady ? brandGreen : Colors.orange.shade800;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.08),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              permissionReady
                  ? Icons.verified_user_outlined
                  : Icons.info_outline,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    permissionReady
                        ? strings.websiteProtectionVpnPermissionReadyTitle
                        : strings.websiteProtectionVpnPermissionNeededTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    permissionReady
                        ? strings.websiteProtectionVpnPermissionReadyBody
                        : strings.websiteProtectionVpnPermissionNeededBody,
                    style: TextStyle(color: Colors.grey[800], height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
