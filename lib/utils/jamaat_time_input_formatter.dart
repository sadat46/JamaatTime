import 'package:flutter/services.dart';

class JamaatTimeInputFormatter extends TextInputFormatter {
  const JamaatTimeInputFormatter();

  static final RegExp _nonDigits = RegExp(r'\D');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final rawText = newValue.text;
    final rawCursor = newValue.selection.extentOffset;
    final safeCursor = rawCursor < 0
        ? rawText.length
        : _clampInt(rawCursor, 0, rawText.length);
    final digitCursor = _countDigits(rawText.substring(0, safeCursor));
    final digits = rawText.replaceAll(_nonDigits, '');
    final limitedDigits = digits.length > 4 ? digits.substring(0, 4) : digits;
    final formatted = _formatDigits(limitedDigits);
    final selectionOffset = _cursorOffsetForDigits(
      _clampInt(digitCursor, 0, limitedDigits.length),
      formatted.length,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: selectionOffset),
    );
  }

  static String _formatDigits(String digits) {
    if (digits.length <= 2) {
      return digits;
    }
    return '${digits.substring(0, 2)}:${digits.substring(2)}';
  }

  static int _cursorOffsetForDigits(int digitCount, int textLength) {
    final offset = digitCount <= 2 ? digitCount : digitCount + 1;
    return _clampInt(offset, 0, textLength);
  }

  static int _countDigits(String value) {
    var count = 0;
    for (final codeUnit in value.codeUnits) {
      if (codeUnit >= 48 && codeUnit <= 57) {
        count++;
      }
    }
    return count;
  }

  static int _clampInt(int value, int min, int max) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }
}
