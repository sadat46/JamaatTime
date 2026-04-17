import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/models/dua_model.dart';

void main() {
  const v1Json = <String, dynamic>{
    'id': 7,
    'titleBangla': 'ঘুমের দোয়া',
    'arabicText': 'بسم',
    'banglaTransliteration': 'বিসমিল্লাহ',
    'banglaMeaning': 'আল্লাহর নামে',
    'reference': 'বুখারী ৬৩২০',
    'category': 'দৈনন্দিন',
    'displayOrder': 1,
  };

  test('fromJson handles v1 without crashing', () {
    final dua = DuaModel.fromJson(v1Json);
    expect(dua.titleEnglish, isNull);
    expect(dua.englishTransliteration, isNull);
    expect(dua.englishMeaning, isNull);
    expect(dua.categoryEnglish, isNull);
  });

  test('getters fall back to Bengali when English missing', () {
    final dua = DuaModel.fromJson(v1Json);
    expect(dua.getTitle(const Locale('en')), 'ঘুমের দোয়া');
    expect(dua.getTransliteration(const Locale('en')), 'বিসমিল্লাহ');
    expect(dua.getMeaning(const Locale('en')), 'আল্লাহর নামে');
    expect(dua.getCategory(const Locale('en')), 'দৈনন্দিন');
  });

  test('bilingual getters prefer English for en locale', () {
    final dua = DuaModel.fromJson({
      ...v1Json,
      'titleEnglish': 'Dua before sleep',
      'englishTransliteration': 'Bismillah',
      'englishMeaning': 'In the name of Allah',
      'categoryEnglish': 'Daily',
    });
    expect(dua.getTitle(const Locale('en')), 'Dua before sleep');
    expect(dua.getTransliteration(const Locale('en')), 'Bismillah');
    expect(dua.getMeaning(const Locale('en')), 'In the name of Allah');
    expect(dua.getCategory(const Locale('en')), 'Daily');
    expect(dua.getTitle(const Locale('bn')), 'ঘুমের দোয়া');
  });

  test('categoryBangla aliases category', () {
    final dua = DuaModel.fromJson(v1Json);
    expect(dua.categoryBangla, dua.category);
  });

  test('toJson omits null English fields and round-trips', () {
    final dua = DuaModel.fromJson(v1Json);
    final json = dua.toJson();
    expect(json.containsKey('titleEnglish'), isFalse);

    final round = DuaModel.fromJson(Map<String, dynamic>.from(json));
    expect(round, dua);
  });
}
