import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/models/dua_model.dart';
import 'package:jamaat_time/screens/ebadat/tabs/dua_tab.dart';

import '../../helpers/fake_ebadat_data_service.dart';
import '../../helpers/localized_test_wrapper.dart';

const DuaModel _sampleDua = DuaModel(
  id: 1,
  titleBangla: 'ঘুম থেকে ওঠার দোয়া',
  arabicText: 'الحمد لله',
  banglaTransliteration: 'আলহামদুলিল্লাহ',
  banglaMeaning: 'সকল প্রশংসা আল্লাহর।',
  reference: 'সহিহ বুখারি',
  category: 'দৈনন্দিন',
  displayOrder: 1,
  titleEnglish: 'Dua after waking up',
  englishTransliteration: 'Alhamdulillah',
  englishMeaning: 'All praise is for Allah.',
  categoryEnglish: 'Daily',
);

void main() {
  Future<void> pumpDuaTab(
    WidgetTester tester, {
    required Locale locale,
    required FakeEbadatDataService service,
  }) async {
    await tester.pumpWidget(
      wrapWithLocale(
        locale: locale,
        child: Scaffold(
          body: DuaTab.withBuilder(
            ebadatService: service,
            cardBuilder: (context, dua, onTap) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('shows localized filter chips in English locale', (tester) async {
    await pumpDuaTab(
      tester,
      locale: const Locale('en'),
      service: FakeEbadatDataService(duas: const [_sampleDua]),
    );

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Daily'), findsOneWidget);
  });

  testWidgets('shows localized filter chips in Bengali locale', (tester) async {
    await pumpDuaTab(
      tester,
      locale: const Locale('bn'),
      service: FakeEbadatDataService(duas: const [_sampleDua]),
    );

    expect(find.text('সব'), findsOneWidget);
    expect(find.text('দৈনন্দিন'), findsOneWidget);
  });

  testWidgets('shows localized empty-state text in English locale', (
    tester,
  ) async {
    await pumpDuaTab(
      tester,
      locale: const Locale('en'),
      service: FakeEbadatDataService(duas: const []),
    );

    expect(find.text('No dua found'), findsOneWidget);
  });

  testWidgets('shows localized empty-state text in Bengali locale', (
    tester,
  ) async {
    await pumpDuaTab(
      tester,
      locale: const Locale('bn'),
      service: FakeEbadatDataService(duas: const []),
    );

    expect(find.text('কোনো দোয়া পাওয়া যায়নি'), findsOneWidget);
  });

  testWidgets('shows localized error text in English locale', (tester) async {
    await pumpDuaTab(
      tester,
      locale: const Locale('en'),
      service: FakeEbadatDataService(throwOnDuaLoad: true),
    );

    expect(find.text('Failed to load data. Please try again.'), findsOneWidget);
  });

  testWidgets('shows localized error text in Bengali locale', (tester) async {
    await pumpDuaTab(
      tester,
      locale: const Locale('bn'),
      service: FakeEbadatDataService(throwOnDuaLoad: true),
    );

    expect(
      find.text('ডেটা লোড করতে ব্যর্থ হয়েছে। পুনরায় চেষ্টা করুন।'),
      findsOneWidget,
    );
  });
}
