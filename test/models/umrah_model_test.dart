import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/models/umrah_model.dart';

void main() {
  group('UmrahDuaModel', () {
    const v1Json = <String, dynamic>{
      'id': 1,
      'titleBangla': 'ইহরামের দোয়া',
      'arabicText': 'لبيك',
      'banglaTransliteration': 'লাব্বাইক',
      'banglaMeaning': 'আমি হাজির',
      'occasion': 'ইহরাম',
    };

    test('v1 JSON loads with null English fields', () {
      final dua = UmrahDuaModel.fromJson(v1Json);
      expect(dua.titleEnglish, isNull);
      expect(dua.occasionEnglish, isNull);
    });

    test('getters fall back to Bengali when English missing', () {
      final dua = UmrahDuaModel.fromJson(v1Json);
      expect(dua.getTitle(const Locale('en')), 'ইহরামের দোয়া');
      expect(dua.getOccasion(const Locale('en')), 'ইহরাম');
    });

    test('bilingual getters prefer English for en locale', () {
      final dua = UmrahDuaModel.fromJson({
        ...v1Json,
        'titleEnglish': 'Ihram dua',
        'occasionEnglish': 'Ihram',
      });
      expect(dua.getTitle(const Locale('en')), 'Ihram dua');
      expect(dua.getOccasion(const Locale('en')), 'Ihram');
      expect(dua.getTitle(const Locale('bn')), 'ইহরামের দোয়া');
    });

    test('toJson round-trips', () {
      final dua = UmrahDuaModel.fromJson(v1Json);
      final round =
          UmrahDuaModel.fromJson(Map<String, dynamic>.from(dua.toJson()));
      expect(round, dua);
    });
  });

  group('UmrahSectionModel', () {
    const v1Json = <String, dynamic>{
      'id': 1,
      'titleBangla': 'তাওয়াফ',
      'titleArabic': 'الطواف',
      'description': 'কাবার চারপাশে',
      'stepNumber': 1,
      'rules': ['নিয়্যত করুন', 'বাম কাঁধ উন্মুক্ত'],
      'relatedDuas': <dynamic>[],
    };

    test('v1 JSON loads with null English fields', () {
      final section = UmrahSectionModel.fromJson(v1Json);
      expect(section.titleEnglish, isNull);
      expect(section.rulesEnglish, isNull);
    });

    test('getRules falls back to Bengali list', () {
      final section = UmrahSectionModel.fromJson(v1Json);
      expect(section.getRules(const Locale('en')), section.rules);
    });

    test('bilingual getters prefer English', () {
      final section = UmrahSectionModel.fromJson({
        ...v1Json,
        'titleEnglish': 'Tawaf',
        'descriptionEnglish': 'Around the Kaaba',
        'rulesEnglish': ['Make intention', 'Expose left shoulder'],
      });
      expect(section.getTitle(const Locale('en')), 'Tawaf');
      expect(section.getDescription(const Locale('en')), 'Around the Kaaba');
      expect(
        section.getRules(const Locale('en')),
        ['Make intention', 'Expose left shoulder'],
      );
    });
  });
}
