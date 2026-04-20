import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/models/umrah_model.dart';
import 'package:jamaat_time/screens/ebadat/tabs/umrah_tab.dart';

import '../../helpers/fake_ebadat_data_service.dart';
import '../../helpers/localized_test_wrapper.dart';

const UmrahSectionModel _sampleSection = UmrahSectionModel(
  id: 1,
  titleBangla: 'ইহরাম',
  titleArabic: 'الإحرام',
  description: 'ইহরামের বর্ণনা',
  stepNumber: 1,
  rules: ['নিয়ম ১'],
  relatedDuas: [
    UmrahDuaModel(
      id: 1,
      titleBangla: 'ইহরামের নিয়ত',
      arabicText: 'لبيك',
      banglaTransliteration: 'লাব্বাইক',
      banglaMeaning: 'আমি ওমরাহর নিয়ত করছি',
      occasion: 'ইহরাম',
      titleEnglish: 'Ihram intention',
      englishTransliteration: 'Labbaik',
      englishMeaning: 'I intend Umrah',
      occasionEnglish: 'Ihram',
    ),
  ],
  titleEnglish: 'Ihram',
  descriptionEnglish: 'Ihram description',
  rulesEnglish: ['Rule 1'],
);

void main() {
  Future<void> pumpUmrahTab(
    WidgetTester tester, {
    required Locale locale,
    required FakeEbadatDataService service,
  }) async {
    await tester.pumpWidget(
      wrapWithLocale(
        locale: locale,
        child: Scaffold(body: UmrahTab(ebadatService: service)),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('shows localized list labels in English locale', (tester) async {
    await pumpUmrahTab(
      tester,
      locale: const Locale('en'),
      service: FakeEbadatDataService(umrahSections: const [_sampleSection]),
    );

    expect(find.text('Ihram'), findsOneWidget);
    expect(find.text('1 Rules'), findsOneWidget);
    expect(find.text('1 Dua'), findsOneWidget);
  });

  testWidgets('shows localized list labels in Bengali locale', (tester) async {
    await pumpUmrahTab(
      tester,
      locale: const Locale('bn'),
      service: FakeEbadatDataService(umrahSections: const [_sampleSection]),
    );

    expect(find.text('ইহরাম'), findsOneWidget);
    expect(find.text('1 নিয়ম'), findsOneWidget);
    expect(find.text('1 দোয়া'), findsOneWidget);
  });

  testWidgets('shows localized empty-state text in English locale', (
    tester,
  ) async {
    await pumpUmrahTab(
      tester,
      locale: const Locale('en'),
      service: FakeEbadatDataService(umrahSections: const []),
    );

    expect(find.text('No Umrah guide found'), findsOneWidget);
  });

  testWidgets('shows localized empty-state text in Bengali locale', (
    tester,
  ) async {
    await pumpUmrahTab(
      tester,
      locale: const Locale('bn'),
      service: FakeEbadatDataService(umrahSections: const []),
    );

    expect(find.text('কোনো ওমরাহ গাইড পাওয়া যায়নি'), findsOneWidget);
  });

  testWidgets('shows localized error text in English locale', (tester) async {
    await pumpUmrahTab(
      tester,
      locale: const Locale('en'),
      service: FakeEbadatDataService(throwOnUmrahLoad: true),
    );

    expect(find.text('Failed to load data. Please try again.'), findsOneWidget);
  });

  testWidgets('shows localized error text in Bengali locale', (tester) async {
    await pumpUmrahTab(
      tester,
      locale: const Locale('bn'),
      service: FakeEbadatDataService(throwOnUmrahLoad: true),
    );

    expect(
      find.text('ডেটা লোড করতে ব্যর্থ হয়েছে। পুনরায় চেষ্টা করুন।'),
      findsOneWidget,
    );
  });
}
