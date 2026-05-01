import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../platform/family_safety_channel.dart';

class SafeSearchSetupPage extends StatefulWidget {
  const SafeSearchSetupPage({super.key});

  @override
  State<SafeSearchSetupPage> createState() => _SafeSearchSetupPageState();
}

class _SafeSearchSetupPageState extends State<SafeSearchSetupPage> {
  static const Color _brandGreen = Color(0xFF388E3C);
  static const String _familyDnsHost = 'family-filter-dns.cleanbrowsing.org';

  final FamilySafetyChannel _channel = FamilySafetyChannel();
  late Future<PrivateDnsState> _privateDnsState;

  @override
  void initState() {
    super.initState();
    _privateDnsState = _channel.getPrivateDnsState();
  }

  void _refreshPrivateDnsState() {
    setState(() {
      _privateDnsState = _channel.getPrivateDnsState();
    });
  }

  Future<void> _copyFamilyDnsHost() async {
    final strings = AppLocalizations.of(context);
    await Clipboard.setData(const ClipboardData(text: _familyDnsHost));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.safeSearchCopiedDnsHostMessage),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openNetworkSettings() async {
    final strings = AppLocalizations.of(context);
    final opened = await _channel.openNetworkSettings();
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.safeSearchNetworkSettingsUnavailable),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _modeLabel(AppLocalizations strings, String mode) {
    switch (mode) {
      case 'off':
        return strings.privateDnsModeOff;
      case 'opportunistic':
        return strings.privateDnsModeAutomatic;
      case 'hostname':
        return strings.privateDnsModeHostname;
      case 'unsupported':
        return strings.privateDnsModeUnsupported;
      default:
        return strings.privateDnsModeUnknown;
    }
  }

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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            strings.safeSearchSetupIntro,
            style: TextStyle(color: Colors.grey[700], height: 1.35),
          ),
          const SizedBox(height: 14),
          _buildPrivateDnsCard(strings),
          const SizedBox(height: 12),
          _GuidanceTile(
            icon: Icons.search_outlined,
            title: strings.safeSearchGoogleTitle,
            body: strings.safeSearchGoogleBody,
          ),
          const SizedBox(height: 10),
          _GuidanceTile(
            icon: Icons.play_circle_outline,
            title: strings.safeSearchYoutubeTitle,
            body: strings.safeSearchYoutubeBody,
          ),
          const SizedBox(height: 10),
          _GuidanceTile(
            icon: Icons.dns_outlined,
            title: strings.safeSearchPrivateDnsTitle,
            body: strings.safeSearchPrivateDnsBody,
          ),
          const SizedBox(height: 10),
          _GuidanceTile(
            icon: Icons.language_outlined,
            title: strings.safeSearchBrowserTitle,
            body: strings.safeSearchBrowserBody,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivateDnsCard(AppLocalizations strings) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<PrivateDnsState>(
          future: _privateDnsState,
          builder: (context, snapshot) {
            final state = snapshot.data;
            final loading = snapshot.connectionState != ConnectionState.done;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _brandGreen.withAlpha(24),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.settings_ethernet_outlined,
                        color: _brandGreen,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        strings.privateDnsStatusTitle,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: strings.safeSearchRefreshStatusCta,
                      onPressed: _refreshPrivateDnsState,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (loading)
                  Text(
                    strings.privateDnsLoading,
                    style: TextStyle(color: Colors.grey[700], height: 1.35),
                  )
                else ...[
                  _StatusRow(
                    label: strings.privateDnsModeLabel,
                    value: _modeLabel(strings, state?.mode ?? 'unknown'),
                  ),
                  const SizedBox(height: 8),
                  _StatusRow(
                    label: strings.privateDnsHostLabel,
                    value: state?.host ?? strings.privateDnsHostNotSet,
                  ),
                  if (state?.usesKnownDohProvider ?? false) ...[
                    const SizedBox(height: 12),
                    _WarningBanner(text: strings.privateDnsDohProviderWarning),
                  ],
                  if (state?.supported == false && state?.error != null) ...[
                    const SizedBox(height: 12),
                    _WarningBanner(text: strings.privateDnsStatusUnavailable),
                  ],
                ],
                const SizedBox(height: 14),
                Text(
                  '${strings.privateDnsRecommendedHostLabel}: $_familyDnsHost',
                  style: TextStyle(color: Colors.grey[700], height: 1.35),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _copyFamilyDnsHost,
                      icon: const Icon(Icons.copy_outlined),
                      label: Text(strings.safeSearchCopyDnsHostCta),
                    ),
                    FilledButton.icon(
                      onPressed: _openNetworkSettings,
                      icon: const Icon(Icons.settings_outlined),
                      label: Text(strings.safeSearchOpenNetworkSettingsCta),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GuidanceTile extends StatelessWidget {
  const _GuidanceTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: const Color(0xFF388E3C)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: TextStyle(color: Colors.grey[700], height: 1.38),
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

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFECB3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 20, color: Color(0xFFF57C00)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[800], height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
