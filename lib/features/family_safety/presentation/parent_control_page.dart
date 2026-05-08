import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../data/parent_control_storage.dart';

class ParentControlPage extends StatefulWidget {
  const ParentControlPage({super.key});

  @override
  State<ParentControlPage> createState() => _ParentControlPageState();
}

class _ParentControlPageState extends State<ParentControlPage> {
  static const Color _brandGreen = Color(0xFF388E3C);
  static const String _disableResetWord = 'DISABLE';

  final ParentControlStorage _storage = ParentControlStorage();

  ParentPinStatus? _status;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loading = true;
    });
    final status = await _storage.loadStatus();
    if (!mounted) {
      return;
    }
    setState(() {
      _status = status;
      _loading = false;
    });
  }

  Future<void> _setPin() async {
    final strings = AppLocalizations.of(context);
    final entry = await _showCreatePinDialog(strings);
    if (entry == null) {
      return;
    }

    await _runPinAction(
      action: () => _storage.setPin(entry.pin),
      successMessage: strings.parentControlPinSaved,
    );
  }

  Future<void> _changePin() async {
    final strings = AppLocalizations.of(context);
    final entry = await _showChangePinDialog(strings);
    if (entry == null) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final result = await _storage.verifyPin(entry.currentPin);
      if (!mounted) {
        return;
      }
      if (!result.verified) {
        _showVerificationFailure(strings, result);
        await _loadStatus();
        return;
      }

      await _storage.setPin(entry.newPin);
      if (!mounted) {
        return;
      }
      _showSnack(strings.parentControlPinChanged);
      await _loadStatus();
    } catch (_) {
      if (mounted) {
        _showSnack(strings.parentControlPinError);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _resetForgottenPin() async {
    final strings = AppLocalizations.of(context);
    final confirmed = await _showResetPinDialog(strings);
    if (!confirmed) {
      return;
    }

    await _runPinAction(
      action: _storage.resetPinAndDisableWebsiteProtection,
      successMessage: strings.parentControlPinReset,
    );
  }

  Future<void> _runPinAction({
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    final strings = AppLocalizations.of(context);
    setState(() {
      _busy = true;
    });

    try {
      await action();
      if (!mounted) {
        return;
      }
      _showSnack(successMessage);
      await _loadStatus();
    } catch (_) {
      if (mounted) {
        _showSnack(strings.parentControlPinError);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _showVerificationFailure(
    AppLocalizations strings,
    ParentPinVerificationResult result,
  ) {
    _showSnack(
      result.isLocked
          ? strings.parentControlPinLocked
          : strings.parentControlPinIncorrect,
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<_NewPinEntry?> _showCreatePinDialog(AppLocalizations strings) {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    return showDialog<_NewPinEntry>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(strings.parentControlCreatePinTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PinField(
                    controller: pinController,
                    label: strings.parentControlNewPin,
                    helperText: strings.parentControlPinHint,
                  ),
                  const SizedBox(height: 12),
                  _PinField(
                    controller: confirmController,
                    label: strings.parentControlConfirmPin,
                    helperText: strings.parentControlPinHint,
                    errorText: errorText,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(strings.parentControlCancel),
                ),
                FilledButton(
                  onPressed: () {
                    final pin = pinController.text;
                    final confirmPin = confirmController.text;
                    final error = _validateNewPin(strings, pin, confirmPin);
                    if (error != null) {
                      setDialogState(() {
                        errorText = error;
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(_NewPinEntry(pin));
                  },
                  child: Text(strings.parentControlSavePin),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      pinController.dispose();
      confirmController.dispose();
    });
  }

  Future<_PinChangeEntry?> _showChangePinDialog(AppLocalizations strings) {
    final currentController = TextEditingController();
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    return showDialog<_PinChangeEntry>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(strings.parentControlChangePinTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PinField(
                    controller: currentController,
                    label: strings.parentControlCurrentPin,
                    helperText: strings.parentControlPinHint,
                  ),
                  const SizedBox(height: 12),
                  _PinField(
                    controller: pinController,
                    label: strings.parentControlNewPin,
                    helperText: strings.parentControlPinHint,
                  ),
                  const SizedBox(height: 12),
                  _PinField(
                    controller: confirmController,
                    label: strings.parentControlConfirmPin,
                    helperText: strings.parentControlPinHint,
                    errorText: errorText,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(strings.parentControlCancel),
                ),
                FilledButton(
                  onPressed: () {
                    final currentPin = currentController.text;
                    final newPin = pinController.text;
                    final confirmPin = confirmController.text;
                    final error = _validateNewPin(strings, newPin, confirmPin);
                    if (error != null || !_isValidPin(currentPin)) {
                      setDialogState(() {
                        errorText = error ?? strings.parentControlPinInvalid;
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(
                      _PinChangeEntry(currentPin: currentPin, newPin: newPin),
                    );
                  },
                  child: Text(strings.parentControlUpdatePin),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      currentController.dispose();
      pinController.dispose();
      confirmController.dispose();
    });
  }

  Future<bool> _showResetPinDialog(AppLocalizations strings) async {
    final confirmController = TextEditingController();
    var canReset = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(strings.parentControlResetPinTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(strings.parentControlForgotPinWarning),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: strings.parentControlResetPinInputLabel,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        canReset = value == _disableResetWord;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(strings.parentControlCancel),
                ),
                FilledButton(
                  onPressed: canReset
                      ? () => Navigator.of(dialogContext).pop(true)
                      : null,
                  child: Text(strings.parentControlResetPinCta),
                ),
              ],
            );
          },
        );
      },
    );

    confirmController.dispose();
    return confirmed == true;
  }

  String? _validateNewPin(
    AppLocalizations strings,
    String pin,
    String confirmPin,
  ) {
    if (!_isValidPin(pin)) {
      return strings.parentControlPinInvalid;
    }
    if (pin != confirmPin) {
      return strings.parentControlPinMismatch;
    }
    return null;
  }

  bool _isValidPin(String pin) {
    return RegExp(r'^\d{4,8}$').hasMatch(pin);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final status = _status;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.parentControlTitle),
        centerTitle: true,
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
      ),
      body: _loading || status == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                const Icon(Icons.lock_outline, size: 44),
                const SizedBox(height: 16),
                Text(
                  strings.parentControlSubtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  strings.parentControlPinScope,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700], height: 1.4),
                ),
                const SizedBox(height: 20),
                _PinStatusPanel(status: status, brandGreen: _brandGreen),
                if (status.isLocked) ...[
                  const SizedBox(height: 12),
                  _LockoutPanel(message: strings.parentControlPinLocked),
                ],
                const SizedBox(height: 20),
                if (status.hasPin) ...[
                  FilledButton.icon(
                    onPressed: _busy || status.isLocked ? null : _changePin,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(strings.parentControlChangePin),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _resetForgottenPin,
                    icon: const Icon(Icons.lock_reset_outlined),
                    label: Text(strings.parentControlForgotPin),
                  ),
                ] else
                  FilledButton.icon(
                    onPressed: _busy ? null : _setPin,
                    icon: const Icon(Icons.pin_outlined),
                    label: Text(strings.parentControlSetPin),
                  ),
              ],
            ),
    );
  }
}

class _PinStatusPanel extends StatelessWidget {
  const _PinStatusPanel({required this.status, required this.brandGreen});

  final ParentPinStatus status;
  final Color brandGreen;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final hasPin = status.hasPin;
    final color = hasPin ? brandGreen : Colors.orange.shade800;

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
              hasPin ? Icons.verified_user_outlined : Icons.info_outline,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasPin
                        ? strings.parentControlPinActiveTitle
                        : strings.parentControlPinInactiveTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hasPin
                        ? strings.parentControlPinActiveBody
                        : strings.parentControlPinInactiveBody,
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

class _LockoutPanel extends StatelessWidget {
  const _LockoutPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
        color: Colors.red.shade50,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.timer_outlined, color: Colors.red.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.red.shade900, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinField extends StatelessWidget {
  const _PinField({
    required this.controller,
    required this.label,
    required this.helperText,
    this.errorText,
  });

  final TextEditingController controller;
  final String label;
  final String helperText;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 8,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        errorText: errorText,
        border: const OutlineInputBorder(),
        counterText: '',
      ),
    );
  }
}

class _NewPinEntry {
  const _NewPinEntry(this.pin);

  final String pin;
}

class _PinChangeEntry {
  const _PinChangeEntry({required this.currentPin, required this.newPin});

  final String currentPin;
  final String newPin;
}
