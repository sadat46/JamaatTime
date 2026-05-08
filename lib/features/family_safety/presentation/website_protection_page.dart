import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../platform/family_safety_channel.dart';
import 'widgets/disclosure_dialog.dart';
import 'widgets/parent_pin_prompt_dialog.dart';

class WebsiteProtectionPage extends StatefulWidget {
  const WebsiteProtectionPage({super.key});

  @override
  State<WebsiteProtectionPage> createState() => _WebsiteProtectionPageState();
}

class _WebsiteProtectionPageState extends State<WebsiteProtectionPage> {
  static const Color _brandGreen = Color(0xFF388E3C);
  static const Duration _pollInterval = Duration(milliseconds: 350);
  static const Duration _pollTimeout = Duration(seconds: 4);

  final FamilySafetyChannel _channel = FamilySafetyChannel();

  VpnStatus? _status;
  PrivateDnsState? _dns;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final status = await _channel.getVpnStatus();
    final dns = await _channel.getPrivateDnsState();
    if (!mounted) return;
    setState(() {
      _status = status;
      _dns = dns;
      _loading = false;
    });
  }

  Future<void> _grantPermission() async {
    final strings = AppLocalizations.of(context);
    final accepted = await FamilySafetyDisclosureDialog.showWebsiteProtection(
      context,
    );
    if (!accepted || !mounted) return;
    setState(() => _busy = true);
    final granted = await _channel.requestVpnPermission();
    if (!mounted) return;
    setState(() => _busy = false);
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
    await _refresh();
  }

  Future<void> _toggleProtection({required bool turnOn}) async {
    final strings = AppLocalizations.of(context);
    final allowed = await requireParentPin(context);
    if (!allowed || !mounted) return;
    setState(() => _busy = true);
    final ok = turnOn
        ? await _channel.startWebsiteProtection()
        : await _channel.stopWebsiteProtection();
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(strings.websiteProtectionStartFailed)),
        );
      await _refresh();
      return;
    }
    final reached = await _waitForRunning(running: turnOn);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            !reached && turnOn
                ? strings.websiteProtectionStartFailed
                : turnOn
                    ? strings.websiteProtectionStarted
                    : strings.websiteProtectionStopped,
          ),
        ),
      );
    await _refresh();
  }

  Future<bool> _waitForRunning({required bool running}) async {
    final deadline = DateTime.now().add(_pollTimeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(_pollInterval);
      final status = await _channel.getVpnStatus();
      if (!mounted) return false;
      if (status.running == running && status.lastError == null) {
        setState(() => _status = status);
        return true;
      }
      setState(() => _status = status);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final status = _status;
    final permissionReady = status?.prepared == true;
    final running = status?.running == true;
    final lastError = status?.lastError;

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
                Icon(
                  running ? Icons.shield : Icons.public_off_outlined,
                  color: _brandGreen,
                  size: 44,
                ),
                const SizedBox(height: 16),
                Text(
                  running
                      ? strings.websiteProtectionRunningTitle
                      : strings.websiteProtectionSubtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  running
                      ? strings.websiteProtectionRunningBody
                      : strings.websiteProtectionPlaceholder,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700], height: 1.4),
                ),
                const SizedBox(height: 20),
                _VpnPermissionStatusPanel(
                  permissionReady: permissionReady,
                  running: running,
                  lastError: lastError,
                  brandGreen: _brandGreen,
                ),
                if (_dns?.usesKnownDohProvider == true) ...[
                  const SizedBox(height: 16),
                  _DohBanner(
                    onOpenSettings: _channel.openNetworkSettings,
                  ),
                ],
                const SizedBox(height: 20),
                if (!permissionReady)
                  FilledButton.icon(
                    onPressed: _busy ? null : _grantPermission,
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.shield_outlined),
                    label: Text(strings.websiteProtectionEnableCta),
                  )
                else if (running)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _toggleProtection(turnOn: false),
                    icon: const Icon(Icons.power_settings_new),
                    label: Text(strings.websiteProtectionTurnOffCta),
                  )
                else
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _toggleProtection(turnOn: true),
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(strings.websiteProtectionTurnOnCta),
                  ),
              ],
            ),
    );
  }
}

class _VpnPermissionStatusPanel extends StatelessWidget {
  const _VpnPermissionStatusPanel({
    required this.permissionReady,
    required this.running,
    required this.lastError,
    required this.brandGreen,
  });

  final bool permissionReady;
  final bool running;
  final String? lastError;
  final Color brandGreen;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final hasError = lastError != null;
    final color = hasError
        ? Colors.red.shade700
        : running
            ? brandGreen
            : permissionReady
                ? brandGreen
                : Colors.orange.shade800;

    final title = hasError
        ? strings.websiteProtectionStartFailed
        : running
            ? strings.websiteProtectionRunningTitle
            : permissionReady
                ? strings.websiteProtectionVpnPermissionReadyTitle
                : strings.websiteProtectionVpnPermissionNeededTitle;

    final body = hasError
        ? lastError!
        : running
            ? strings.websiteProtectionRunningBody
            : permissionReady
                ? strings.websiteProtectionVpnPermissionReadyBody
                : strings.websiteProtectionVpnPermissionNeededBody;

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
              hasError
                  ? Icons.error_outline
                  : running
                      ? Icons.shield_outlined
                      : permissionReady
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
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
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

class _DohBanner extends StatelessWidget {
  const _DohBanner({required this.onOpenSettings});

  final Future<bool> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final color = Colors.orange.shade800;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.08),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dns_outlined, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    strings.websiteProtectionDohBannerTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              strings.websiteProtectionDohBannerBody,
              style: TextStyle(color: Colors.grey[800], height: 1.35),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  onOpenSettings();
                },
                icon: const Icon(Icons.settings_ethernet),
                label: Text(strings.websiteProtectionOpenNetworkSettings),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
