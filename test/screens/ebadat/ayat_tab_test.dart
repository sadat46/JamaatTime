import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/models/ayat_model.dart';
import 'package:jamaat_time/screens/ebadat/tabs/ayat_tab.dart';

import '../../helpers/fake_ebadat_data_service.dart';
import '../../helpers/localized_test_wrapper.dart';

const AyatModel _sampleAyat = AyatModel(
  id: 1,
  titleBangla: 'রহমতের আয়াত',
  surahName: 'যুমার',
  surahNameArabic: 'الزمر',
  surahNumber: 39,
  ayatNumber: '53',
  arabicText: 'قل يا عبادي',
  banglaTransliteration: 'কুল ইয়া ইবাদি',
  banglaMeaning: 'আল্লাহর রহমত থেকে নিরাশ হয়ো না।',
  reference: 'সূরা যুমার ৫৩',
  category: 'তাওবা',
  displayOrder: 1,
  titleEnglish: 'Ayat of Mercy',
  surahNameEnglish: 'Az-Zumar',
  englishTransliteration: 'Qul ya ibadi',
  englishMeaning: 'Do not despair of Allah\'s mercy.',
  categoryEnglish: 'Repentance',
);

void main() {
  Future<void> pumpAyatTab(
    WidgetTester tester, {
    required Locale locale,
    required FakeEbadatDataService service,
  }) async {
    await tester.pumpWidget(
      wrapWithLocale(
        locale: locale,
        child: Scaffold(
          body: AyatTab.withBuilder(
            ebadatService: service,
            cardBuilder: (context, ayat, onTap) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final exception = tester.takeException();
    if (exception != null) {
      throw exception;
    }
  }

  testWidgets('shows localized filter chips in English locale', (tester) async {
    await pumpAyatTab(
      tester,
      locale: const Locale('en'),
      service: FakeEbadatDataService(ayats: const [_sampleAyat]),
    );

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Repentance'), findsOneWidget);
  });

  testWidgets('shows localized filter chips in Bengali locale', (tester) async {
    await pumpAyatTab(
      tester,
      locale: const Locale('bn'),
      service: FakeEbadatDataService(ayats: const [_sampleAyat]),
    );

    expect(find.text('সব'), findsOneWidget);
    expect(find.text('তাওবা'), findsOneWidget);
  });

  testWidgets('shows localized empty-state text in English locale', (
    tester,
  ) async {
    await pumpAyatTab(
      tester,
      locale: const Locale('en'),
      service: FakeEbadatDataService(ayats: const []),
    );

    expect(find.text('No ayat found'), findsOneWidget);
  });

  testWidgets('shows localized empty-state text in Bengali locale', (
    tester,
  ) async {
    await pumpAyatTab(
      tester,
      locale: const Locale('bn'),
      service: FakeEbadatDataService(ayats: const []),
    );

    expect(find.text('কোনো আয়াত পাওয়া যায়নি'), findsOneWidget);
  });

  testWidgets('shows localized error text in English locale', (tester) async {
    await pumpAyatTab(
      tester,
      locale: const Locale('en'),
      service: FakeEbadatDataService(throwOnAyatLoad: true),
    );

    expect(find.text('Failed to load data. Please try again.'), findsOneWidget);
  });

  testWidgets('shows localized error text in Bengali locale', (tester) async {
    await pumpAyatTab(
      tester,
      locale: const Locale('bn'),
      service: FakeEbadatDataService(throwOnAyatLoad: true),
    );

    expect(
      find.text('ডেটা লোড করতে ব্যর্থ হয়েছে। পুনরায় চেষ্টা করুন।'),
      findsOneWidget,
    );
  });
}
