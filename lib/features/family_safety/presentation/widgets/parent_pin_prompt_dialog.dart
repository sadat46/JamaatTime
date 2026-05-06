import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/parent_control_storage.dart';
import '../parent_pin_session.dart';

/// Returns `true` when the caller is authorized to proceed:
///   - no PIN has been set (nothing to gate), or
///   - the in-memory session is still unlocked, or
///   - the user successfully verifies the PIN in the prompt dialog.
///
/// Returns `false` when the user cancels, the PIN store is locked out, or
/// verification fails.
Future<bool> requireParentPin(BuildContext context) async {
  final storage = ParentControlStorage();
  final status = await storage.loadStatus();
  if (!status.hasPin) {
    return true;
  }
  if (ParentPinSession.isUnlocked()) {
    return true;
  }
  if (!context.mounted) {
    return false;
  }
  if (status.isLocked) {
    final strings = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(strings.parentControlPinLocked)));
    return false;
  }

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ParentPinPromptDialog(storage: storage),
  );
  if (ok == true) {
    ParentPinSession.markUnlocked();
    return true;
  }
  return false;
}

class _ParentPinPromptDialog extends StatefulWidget {
  const _ParentPinPromptDialog({required this.storage});

  final ParentControlStorage storage;

  @override
  State<_ParentPinPromptDialog> createState() => _ParentPinPromptDialogState();
}

class _ParentPinPromptDialogState extends State<_ParentPinPromptDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _busy = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final strings = AppLocalizations.of(context);
    final pin = _controller.text;
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      setState(() => _errorText = strings.parentControlPinInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _errorText = null;
    });
    final result = await widget.storage.verifyPin(pin);
    if (!mounted) return;
    if (result.verified) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _errorText = result.isLocked
          ? strings.parentControlPinLocked
          : strings.parentControlPinIncorrect;
    });
    if (result.isLocked) {
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(strings.parentControlVerifyPinTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.parentControlVerifyPinBody,
            style: TextStyle(color: Colors.grey[700], height: 1.35),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            obscureText: true,
            autofocus: true,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            maxLength: 8,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              labelText: strings.parentControlCurrentPin,
              helperText: strings.parentControlPinHint,
              errorText: _errorText,
              border: const OutlineInputBorder(),
              counterText: '',
            ),
            onSubmitted: (_) => _busy ? null : _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(strings.parentControlCancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(strings.parentControlVerifyCta),
        ),
      ],
    );
  }
}
