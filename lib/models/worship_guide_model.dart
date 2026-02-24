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
  });

  /// Get the status label
  String get statusLabel {
    if (isFard) return 'ফরজ';
    if (isSunnah) return 'সুন্নাত';
    if (isMustahab) return 'মুস্তাহাব';
    return '';
  }
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
  });
}

/// Section model for organized content display
class WorshipSection {
  final String titleBangla;
  final String? titleArabic;
  final String? description;
  final List<String> items;
  final List<Reference> references;

  const WorshipSection({
    required this.titleBangla,
    this.titleArabic,
    this.description,
    this.items = const [],
    this.references = const [],
  });
}

/// Prayer/Dua model within worship guides
class WorshipDua {
  final String titleBangla;
  final String arabicText;
  final String transliteration;
  final String meaning;
  final String? when; // When to recite
  final List<Reference> references;

  const WorshipDua({
    required this.titleBangla,
    required this.arabicText,
    required this.transliteration,
    required this.meaning,
    this.when,
    this.references = const [],
  });
}
