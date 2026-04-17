import 'package:flutter/widgets.dart';

/// Reference model for Quran/Hadith citations
class Reference {
  final String source; // "Quran", "Bukhari", "Muslim", etc.
  final String citation; // "2:238", "Hadith 1934", etc.
  final String? fullText; // Optional full reference text
  final String? grading; // "Sahih", "Hasan", etc.

  const Reference({
    required this.source,
    required this.citation,
    this.fullText,
    this.grading,
  });

  /// Get icon based on source type
  bool get isQuran => source.toLowerCase() == 'quran' || source.contains('সূরা');
  bool get isSahihHadith =>
      source.toLowerCase().contains('bukhari') ||
      source.toLowerCase().contains('muslim') ||
      source.contains('বুখারী') ||
      source.contains('মুসলিম');
}

/// Individual step in a worship guide
class WorshipStep {
  final int stepNumber;
  final String titleBangla;
  final String? arabicText; // Arabic dua/recitation if applicable
  final String? transliteration;
  final String? meaning;
  final String instruction;
  final List<Reference> references;
  final bool isFard; // Is this step obligatory?
  final bool isSunnah; // Is this step sunnah?
  final bool isMustahab; // Is this step recommended?
  final String? titleEnglish;
  final String? instructionEnglish;
  final String? meaningEnglish;

  const WorshipStep({
    required this.stepNumber,
    required this.titleBangla,
    this.arabicText,
    this.transliteration,
    this.meaning,
    required this.instruction,
    this.references = const [],
    this.isFard = false,
    this.isSunnah = false,
    this.isMustahab = false,
    this.titleEnglish,
    this.instructionEnglish,
    this.meaningEnglish,
  });

  /// Bengali status label. Kept for pre-Phase-5 callers; new code should use
  /// [getStatusLabel] with a [Locale].
  String get statusLabel {
    if (isFard) return 'ফরজ';
    if (isSunnah) return 'সুন্নাত';
    if (isMustahab) return 'মুস্তাহাব';
    return '';
  }

  String getStatusLabel(Locale locale) {
    final isEnglish = locale.languageCode == 'en';
    if (isFard) return isEnglish ? 'Fard' : 'ফরজ';
    if (isSunnah) return isEnglish ? 'Sunnah' : 'সুন্নাত';
    if (isMustahab) return isEnglish ? 'Mustahab' : 'মুস্তাহাব';
    return '';
  }

  String getTitle(Locale locale) =>
      locale.languageCode == 'en' && titleEnglish != null
          ? titleEnglish!
          : titleBangla;

  String getInstruction(Locale locale) =>
      locale.languageCode == 'en' && instructionEnglish != null
          ? instructionEnglish!
          : instruction;

  String? getMeaning(Locale locale) =>
      locale.languageCode == 'en' && meaningEnglish != null
          ? meaningEnglish
          : meaning;
}

/// Main worship guide model
class WorshipGuideModel {
  final int id;
  final String titleBangla;
  final String? titleArabic;
  final String titleEnglish;
  final String introduction;
  final String? keyVerse; // Key Quranic verse for the topic
  final String? keyVerseReference;
  final List<WorshipStep> steps;
  final List<String> conditions; // Prerequisites/conditions
  final List<String> fardActs; // Obligatory acts
  final List<String> sunnahActs; // Sunnah acts
  final List<String> commonMistakes;
  final List<String> specialRulings;
  final List<String> invalidators; // What breaks/invalidates this worship
  final List<Reference> references;
  final String? introductionEnglish;
  final List<String>? conditionsEnglish;
  final List<String>? fardActsEnglish;
  final List<String>? sunnahActsEnglish;
  final List<String>? commonMistakesEnglish;
  final List<String>? specialRulingsEnglish;
  final List<String>? invalidatorsEnglish;

  const WorshipGuideModel({
    required this.id,
    required this.titleBangla,
    this.titleArabic,
    required this.titleEnglish,
    required this.introduction,
    this.keyVerse,
    this.keyVerseReference,
    this.steps = const [],
    this.conditions = const [],
    this.fardActs = const [],
    this.sunnahActs = const [],
    this.commonMistakes = const [],
    this.specialRulings = const [],
    this.invalidators = const [],
    this.references = const [],
    this.introductionEnglish,
    this.conditionsEnglish,
    this.fardActsEnglish,
    this.sunnahActsEnglish,
    this.commonMistakesEnglish,
    this.specialRulingsEnglish,
    this.invalidatorsEnglish,
  });

  String getTitle(Locale locale) =>
      locale.languageCode == 'en' ? titleEnglish : titleBangla;

  String getIntroduction(Locale locale) =>
      locale.languageCode == 'en' && introductionEnglish != null
          ? introductionEnglish!
          : introduction;

  List<String> getConditions(Locale locale) =>
      locale.languageCode == 'en' && conditionsEnglish != null
          ? conditionsEnglish!
          : conditions;

  List<String> getFardActs(Locale locale) =>
      locale.languageCode == 'en' && fardActsEnglish != null
          ? fardActsEnglish!
          : fardActs;

  List<String> getSunnahActs(Locale locale) =>
      locale.languageCode == 'en' && sunnahActsEnglish != null
          ? sunnahActsEnglish!
          : sunnahActs;

  List<String> getCommonMistakes(Locale locale) =>
      locale.languageCode == 'en' && commonMistakesEnglish != null
          ? commonMistakesEnglish!
          : commonMistakes;

  List<String> getSpecialRulings(Locale locale) =>
      locale.languageCode == 'en' && specialRulingsEnglish != null
          ? specialRulingsEnglish!
          : specialRulings;

  List<String> getInvalidators(Locale locale) =>
      locale.languageCode == 'en' && invalidatorsEnglish != null
          ? invalidatorsEnglish!
          : invalidators;
}

/// Section model for organized content display
class WorshipSection {
  final String titleBangla;
  final String? titleArabic;
  final String? description;
  final List<String> items;
  final List<Reference> references;
  final String? titleEnglish;
  final String? descriptionEnglish;
  final List<String>? itemsEnglish;

  const WorshipSection({
    required this.titleBangla,
    this.titleArabic,
    this.description,
    this.items = const [],
    this.references = const [],
    this.titleEnglish,
    this.descriptionEnglish,
    this.itemsEnglish,
  });

  String getTitle(Locale locale) =>
      locale.languageCode == 'en' && titleEnglish != null
          ? titleEnglish!
          : titleBangla;

  String? getDescription(Locale locale) =>
      locale.languageCode == 'en' && descriptionEnglish != null
          ? descriptionEnglish
          : description;

  List<String> getItems(Locale locale) =>
      locale.languageCode == 'en' && itemsEnglish != null
          ? itemsEnglish!
          : items;
}

/// Prayer/Dua model within worship guides
class WorshipDua {
  final String titleBangla;
  final String arabicText;
  final String transliteration;
  final String meaning;
  final String? when; // When to recite
  final List<Reference> references;
  final String? titleEnglish;
  final String? meaningEnglish;
  final String? whenEnglish;

  const WorshipDua({
    required this.titleBangla,
    required this.arabicText,
    required this.transliteration,
    required this.meaning,
    this.when,
    this.references = const [],
    this.titleEnglish,
    this.meaningEnglish,
    this.whenEnglish,
  });

  String getTitle(Locale locale) =>
      locale.languageCode == 'en' && titleEnglish != null
          ? titleEnglish!
          : titleBangla;

  String getMeaning(Locale locale) =>
      locale.languageCode == 'en' && meaningEnglish != null
          ? meaningEnglish!
          : meaning;

  String? getWhen(Locale locale) =>
      locale.languageCode == 'en' && whenEnglish != null ? whenEnglish : when;
}
