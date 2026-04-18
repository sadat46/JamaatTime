import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/screens/admin_jamaat_panel.dart';

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
    expect(lines.first, isNot('• Import CSV: Upload CSV file with jamaat times'));
  });
}
