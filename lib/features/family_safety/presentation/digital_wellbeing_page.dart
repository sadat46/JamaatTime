import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/focus_guard_settings.dart';
import '../../../screens/focus_guard_screen.dart';
import '../../../services/focus_guard_service.dart';

class DigitalWellbeingPage extends StatefulWidget {
  const DigitalWellbeingPage({super.key});

  @override
  State<DigitalWellbeingPage> createState() => _DigitalWellbeingPageState();
}

class _DigitalWellbeingPageState extends State<DigitalWellbeingPage> {
  static const Color _brandGreen = Color(0xFF388E3C);

  final FocusGuardService _focusGuardService = FocusGuardService();

  FocusGuardSettings? _focusGuardSettings;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFocusGuardStatus();
  }

  Future<void> _loadFocusGuardStatus() async {
    final settings = await _focusGuardService.loadSettings();
    if (!mounted) return;
    setState(() {
      _focusGuardSettings = settings;
      _loading = false;
    });
  }

  Future<void> _openFocusGuard() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const FocusGuardScreen()));
    if (!mounted) return;
    await _loadFocusGuardStatus();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final focusGuardOn = _focusGuardSettings?.enabled == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.digitalWellbeingTitle),
        centerTitle: true,
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            strings.digitalWellbeingSubtitle,
            style: TextStyle(color: Colors.grey[700], height: 1.35),
          ),
          const SizedBox(height: 14),
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _brandGreen.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: _brandGreen,
                  size: 21,
                ),
              ),
              title: const Text(
                'Focus Guard',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Block Shorts/Reels and distracting short-video content.',
                style: TextStyle(fontSize: 12, height: 1.35),
              ),
              trailing: _loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _StatusPill(on: focusGuardOn),
              onTap: _openFocusGuard,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final color = on ? const Color(0xFF2E7D32) : Colors.grey.shade700;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: color.withAlpha(24),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withAlpha(80)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              on ? 'ON' : 'OFF',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right),
      ],
    );
  }
}
