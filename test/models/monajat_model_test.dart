import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/models/monajat_model.dart';

void main() {
  const bnOnly = MonajatModel(
    id: 1,
    title: 'শিরোনাম',
    arabic: 'عربى',
    pronunciation: 'pron',
    meaning: 'অর্থ',
    context: 'প্রসঙ্গ',
  );

  const bilingual = MonajatModel(
    id: 2,
    title: 'শিরোনাম',
    arabic: 'عربى',
    pronunciation: 'pron',
    meaning: 'অর্থ',
    context: 'প্রসঙ্গ',
    titleEnglish: 'Title',
    meaningEnglish: 'Meaning',
    contextEnglish: 'Context',
  );

  test('falls back to Bengali when English is null', () {
    expect(bnOnly.getTitle(const Locale('en')), 'শিরোনাম');
    expect(bnOnly.getMeaning(const Locale('en')), 'অর্থ');
    expect(bnOnly.getContext(const Locale('en')), 'প্রসঙ্গ');
  });

  test('returns English when locale is en and English is present', () {
    expect(bilingual.getTitle(const Locale('en')), 'Title');
    expect(bilingual.getMeaning(const Locale('en')), 'Meaning');
    expect(bilingual.getContext(const Locale('en')), 'Context');
  });

  test('returns Bengali for bn locale even if English present', () {
    expect(bilingual.getTitle(const Locale('bn')), 'শিরোনাম');
    expect(bilingual.getMeaning(const Locale('bn')), 'অর্থ');
    expect(bilingual.getContext(const Locale('bn')), 'প্রসঙ্গ');
  });
}
