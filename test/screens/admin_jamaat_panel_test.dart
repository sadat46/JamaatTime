import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/screens/admin_jamaat_panel.dart';
import 'package:jamaat_time/utils/jamaat_time_input_formatter.dart';

void main() {
  test('admin bulk instruction lines are localized for English', () {
    final lines = adminBulkInstructionLines(const Locale('en'));

    expect(lines, hasLength(8));
    expect(lines.first, '• Import CSV: Upload CSV file with jamaat times');
    expect(
      lines.last,
      '• Generate Savar Cantt Times: Create specific times for Savar Cantt',
    );
  });

  test('admin bulk instruction lines are localized for Bengali', () {
    final lines = adminBulkInstructionLines(const Locale('bn'));

    expect(lines, hasLength(8));
    expect(lines.first, contains('CSV'));
    expect(
      lines.first,
      isNot('• Import CSV: Upload CSV file with jamaat times'),
    );
  });

  group('JamaatTimeInputFormatter', () {
    const formatter = JamaatTimeInputFormatter();

    TextEditingValue format(String text, {int? cursor}) {
      return formatter.formatEditUpdate(
        const TextEditingValue(),
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: cursor ?? text.length),
        ),
      );
    }

    test('inserts colon after hour digits while typing', () {
      expect(format('1').text, '1');
      expect(format('12').text, '12');
      expect(format('123').text, '12:3');

      final result = format('1234');

      expect(result.text, '12:34');
      expect(result.selection.baseOffset, 5);
    });

    test('normalizes pasted time that already contains a colon', () {
      final result = format('12:34');

      expect(result.text, '12:34');
      expect(result.selection.baseOffset, 5);
    });

    test('strips non-digits and limits input to four digits', () {
      final result = format('1a2:3456');

      expect(result.text, '12:34');
      expect(result.selection.baseOffset, 5);
    });
  });
}
