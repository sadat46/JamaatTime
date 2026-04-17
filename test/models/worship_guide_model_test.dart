import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/models/worship_guide_model.dart';

void main() {
  group('WorshipStep', () {
    const step = WorshipStep(
      stepNumber: 1,
      titleBangla: 'নিয়্যত',
      instruction: 'মনে মনে নিয়্যত করুন',
      isFard: true,
    );

    test('statusLabel Bengali unchanged', () {
      expect(step.statusLabel, 'ফরজ');
    });

    test('getStatusLabel returns locale-specific label', () {
      expect(step.getStatusLabel(const Locale('bn')), 'ফরজ');
      expect(step.getStatusLabel(const Locale('en')), 'Fard');
    });

    test('getStatusLabel handles sunnah and mustahab', () {
      const sunnah = WorshipStep(
        stepNumber: 2,
        titleBangla: '',
        instruction: '',
        isSunnah: true,
      );
      const mustahab = WorshipStep(
        stepNumber: 3,
        titleBangla: '',
        instruction: '',
        isMustahab: true,
      );
      expect(sunnah.getStatusLabel(const Locale('en')), 'Sunnah');
      expect(mustahab.getStatusLabel(const Locale('en')), 'Mustahab');
      expect(sunnah.getStatusLabel(const Locale('bn')), 'সুন্নাত');
      expect(mustahab.getStatusLabel(const Locale('bn')), 'মুস্তাহাব');
    });

    test('content getters fall back to Bengali when English missing', () {
      expect(step.getTitle(const Locale('en')), 'নিয়্যত');
      expect(step.getInstruction(const Locale('en')), 'মনে মনে নিয়্যত করুন');
      expect(step.getMeaning(const Locale('en')), isNull);
    });

    test('content getters prefer English when provided', () {
      const bilingual = WorshipStep(
        stepNumber: 1,
        titleBangla: 'নিয়্যত',
        instruction: 'মনে মনে নিয়্যত করুন',
        titleEnglish: 'Intention',
        instructionEnglish: 'Make intention in the heart',
      );
      expect(bilingual.getTitle(const Locale('en')), 'Intention');
      expect(
        bilingual.getInstruction(const Locale('en')),
        'Make intention in the heart',
      );
      expect(bilingual.getTitle(const Locale('bn')), 'নিয়্যত');
    });
  });

  group('WorshipGuideModel', () {
    const bnOnly = WorshipGuideModel(
      id: 1,
      titleBangla: 'নামাজ',
      titleEnglish: 'Salah',
      introduction: 'পরিচিতি',
      conditions: ['পাক হওয়া'],
      fardActs: ['কিবলামুখী'],
    );

    test('getTitle uses titleEnglish directly (non-null field)', () {
      expect(bnOnly.getTitle(const Locale('bn')), 'নামাজ');
      expect(bnOnly.getTitle(const Locale('en')), 'Salah');
    });

    test('introduction falls back to Bengali when English missing', () {
      expect(bnOnly.getIntroduction(const Locale('en')), 'পরিচিতি');
    });

    test('list getters fall back to Bengali when English missing', () {
      expect(bnOnly.getConditions(const Locale('en')), ['পাক হওয়া']);
      expect(bnOnly.getFardActs(const Locale('en')), ['কিবলামুখী']);
    });

    test('list getters prefer English when provided', () {
      const bilingual = WorshipGuideModel(
        id: 1,
        titleBangla: 'নামাজ',
        titleEnglish: 'Salah',
        introduction: 'পরিচিতি',
        introductionEnglish: 'Introduction',
        conditions: ['পাক হওয়া'],
        conditionsEnglish: ['Be pure'],
      );
      expect(bilingual.getIntroduction(const Locale('en')), 'Introduction');
      expect(bilingual.getConditions(const Locale('en')), ['Be pure']);
      expect(bilingual.getConditions(const Locale('bn')), ['পাক হওয়া']);
    });
  });

  group('WorshipSection', () {
    test('falls back to Bengali when English missing', () {
      const section = WorshipSection(
        titleBangla: 'মূল বিষয়',
        description: 'বিবরণ',
        items: ['এক', 'দুই'],
      );
      expect(section.getTitle(const Locale('en')), 'মূল বিষয়');
      expect(section.getDescription(const Locale('en')), 'বিবরণ');
      expect(section.getItems(const Locale('en')), ['এক', 'দুই']);
    });

    test('prefers English when provided', () {
      const section = WorshipSection(
        titleBangla: 'মূল বিষয়',
        titleEnglish: 'Main topic',
        description: 'বিবরণ',
        descriptionEnglish: 'Description',
        items: ['এক'],
        itemsEnglish: ['One'],
      );
      expect(section.getTitle(const Locale('en')), 'Main topic');
      expect(section.getDescription(const Locale('en')), 'Description');
      expect(section.getItems(const Locale('en')), ['One']);
    });
  });

  group('WorshipDua', () {
    test('falls back to Bengali when English missing', () {
      const dua = WorshipDua(
        titleBangla: 'রুকূর দোয়া',
        arabicText: 'سبحان',
        transliteration: 'সুবহানা',
        meaning: 'পবিত্র',
        when: 'রুকূতে',
      );
      expect(dua.getTitle(const Locale('en')), 'রুকূর দোয়া');
      expect(dua.getMeaning(const Locale('en')), 'পবিত্র');
      expect(dua.getWhen(const Locale('en')), 'রুকূতে');
    });

    test('prefers English when provided', () {
      const dua = WorshipDua(
        titleBangla: 'রুকূর দোয়া',
        arabicText: 'سبحان',
        transliteration: 'সুবহানা',
        meaning: 'পবিত্র',
        when: 'রুকূতে',
        titleEnglish: 'Ruku dua',
        meaningEnglish: 'Glorious',
        whenEnglish: 'In ruku',
      );
      expect(dua.getTitle(const Locale('en')), 'Ruku dua');
      expect(dua.getMeaning(const Locale('en')), 'Glorious');
      expect(dua.getWhen(const Locale('en')), 'In ruku');
    });
  });
}
