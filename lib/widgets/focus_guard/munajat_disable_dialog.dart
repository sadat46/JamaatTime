import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/monajat_model.dart';

class MunajatDisableDialog extends StatefulWidget {
  final MonajatModel monajat;
  final VoidCallback onConfirmDisable;

  const MunajatDisableDialog({
    super.key,
    required this.monajat,
    required this.onConfirmDisable,
  });

  static Future<void> show(
    BuildContext context, {
    required MonajatModel monajat,
    required VoidCallback onConfirmDisable,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MunajatDisableDialog(
        monajat: monajat,
        onConfirmDisable: onConfirmDisable,
      ),
    );
  }

  @override
  State<MunajatDisableDialog> createState() => _MunajatDisableDialogState();
}

class _MunajatDisableDialogState extends State<MunajatDisableDialog> {
  static const int _countdownSeconds = 15;
  int _remainingSeconds = _countdownSeconds;
  Timer? _timer;

  bool get _canDisable => _remainingSeconds <= 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121212) : Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  widget.monajat.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.teal[200] : Colors.teal[800],
                  ),
                ),
                const SizedBox(height: 16),
                _buildArabic(isDark),
                const SizedBox(height: 12),
                _buildPronunciation(isDark),
                const SizedBox(height: 12),
                _buildMeaning(isDark),
                const SizedBox(height: 20),
                _buildCountdown(isDark),
                const SizedBox(height: 16),
                _buildActions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArabic(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF004D40).withValues(alpha: 0.3),
                  const Color(0xFF00695C).withValues(alpha: 0.2),
                ]
              : [
                  const Color(0xFFE0F2F1),
                  const Color(0xFFB2DFDB),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.teal.withValues(alpha: 0.4)
              : Colors.teal.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Text(
        widget.monajat.arabic,
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: GoogleFonts.amiri(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          height: 2.0,
          color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF004D40),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildPronunciation(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.teal.withValues(alpha: 0.12)
            : Colors.teal.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        widget.monajat.pronunciation,
        style: TextStyle(
          fontSize: 15,
          fontStyle: FontStyle.italic,
          height: 1.6,
          color: isDark ? Colors.grey[300] : Colors.grey[800],
        ),
      ),
    );
  }

  Widget _buildMeaning(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        widget.monajat.meaning,
        style: TextStyle(
          fontSize: 14.5,
          height: 1.5,
          color: isDark ? Colors.grey[200] : Colors.grey[900],
        ),
      ),
    );
  }

  Widget _buildCountdown(bool isDark) {
    final label = _canDisable
        ? 'You may now disable Focus Guard.'
        : 'Please reflect for 15 seconds... (${_remainingSeconds}s)';
    return Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: _canDisable
            ? Colors.redAccent
            : (isDark ? Colors.grey[400] : Colors.grey[700]),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _canDisable
                ? () {
                    widget.onConfirmDisable();
                    Navigator.of(context).pop();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade400,
              disabledForegroundColor: Colors.white70,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Disable Focus Guard',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
