import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/models/ayat_model.dart';

void main() {
  const v1Json = <String, dynamic>{
    'id': 1,
    'titleBangla': 'আয়াতুল কুরসী',
    'surahName': 'আল বাকারা',
    'surahNameArabic': 'البقرة',
    'surahNumber': 2,
    'ayatNumber': '255',
    'arabicText': 'اللَّهُ',
    'banglaTransliteration': 'আল্লাহু',
    'banglaMeaning': 'আল্লাহ',
    'reference': 'সূরা আল বাকারা ২:২৫৫',
    'category': 'আয়াতুল কুরসী',
    'displayOrder': 1,
  };

  test('fromJson handles v1 (no English fields) without crashing', () {
    final ayat = AyatModel.fromJson(v1Json);
    expect(ayat.titleEnglish, isNull);
    expect(ayat.surahNameEnglish, isNull);
    expect(ayat.englishTransliteration, isNull);
    expect(ayat.englishMeaning, isNull);
    expect(ayat.categoryEnglish, isNull);
  });

  test('v1 getters fall back to Bengali for en locale', () {
    final ayat = AyatModel.fromJson(v1Json);
    expect(ayat.getTitle(const Locale('en')), 'আয়াতুল কুরসী');
    expect(ayat.getSurahName(const Locale('en')), 'আল বাকারা');
    expect(ayat.getTransliteration(const Locale('en')), 'আল্লাহু');
    expect(ayat.getMeaning(const Locale('en')), 'আল্লাহ');
    expect(ayat.getCategory(const Locale('en')), 'আয়াতুল কুরসী');
  });

  test('bilingual getters prefer English for en locale', () {
    final ayat = AyatModel.fromJson({
      ...v1Json,
      'titleEnglish': 'Ayat al-Kursi',
      'surahNameEnglish': 'Al-Baqarah',
      'englishTransliteration': 'Allahu',
      'englishMeaning': 'Allah',
      'categoryEnglish': 'Ayat al-Kursi',
    });
    expect(ayat.getTitle(const Locale('en')), 'Ayat al-Kursi');
    expect(ayat.getSurahName(const Locale('en')), 'Al-Baqarah');
    expect(ayat.getTransliteration(const Locale('en')), 'Allahu');
    expect(ayat.getMeaning(const Locale('en')), 'Allah');
    expect(ayat.getCategory(const Locale('en')), 'Ayat al-Kursi');
    expect(ayat.getTitle(const Locale('bn')), 'আয়াতুল কুরসী');
  });

  test('categoryBangla aliases category', () {
    final ayat = AyatModel.fromJson(v1Json);
    expect(ayat.categoryBangla, ayat.category);
  });

  test('toJson omits null English fields and round-trips', () {
    final ayat = AyatModel.fromJson(v1Json);
    final json = ayat.toJson();
    expect(json.containsKey('titleEnglish'), isFalse);
    expect(json.containsKey('categoryEnglish'), isFalse);

    final round = AyatModel.fromJson(Map<String, dynamic>.from(json));
    expect(round, ayat);
  });

  test('equality remains keyed on id', () {
    final a = AyatModel.fromJson(v1Json);
    final b = AyatModel.fromJson({...v1Json, 'titleEnglish': 'Different'});
    expect(a == b, isTrue);
    expect(a.hashCode, b.hashCode);
  });
}
