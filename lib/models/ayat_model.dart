import 'package:flutter/widgets.dart';

class AyatModel {
  final int id;
  final String titleBangla;
  final String surahName;
  final String surahNameArabic;
  final int surahNumber;
  final String ayatNumber;
  final String arabicText;
  final String banglaTransliteration;
  final String banglaMeaning;
  final String reference;
  final String category;
  final int displayOrder;
  final String? titleEnglish;
  final String? surahNameEnglish;
  final String? englishTransliteration;
  final String? englishMeaning;
  final String? categoryEnglish;

  const AyatModel({
    required this.id,
    required this.titleBangla,
    required this.surahName,
    required this.surahNameArabic,
    required this.surahNumber,
    required this.ayatNumber,
    required this.arabicText,
    required this.banglaTransliteration,
    required this.banglaMeaning,
    required this.reference,
    required this.category,
    required this.displayOrder,
    this.titleEnglish,
    this.surahNameEnglish,
    this.englishTransliteration,
    this.englishMeaning,
    this.categoryEnglish,
  });

  /// Alias for [category] to express that the stored value is the Bangla label.
  String get categoryBangla => category;

  String getTitle(Locale locale) =>
      locale.languageCode == 'en' && titleEnglish != null
          ? titleEnglish!
          : titleBangla;

  String getSurahName(Locale locale) =>
      locale.languageCode == 'en' && surahNameEnglish != null
          ? surahNameEnglish!
          : surahName;

  String getTransliteration(Locale locale) =>
      locale.languageCode == 'en' && englishTransliteration != null
          ? englishTransliteration!
          : banglaTransliteration;

  String getMeaning(Locale locale) =>
      locale.languageCode == 'en' && englishMeaning != null
          ? englishMeaning!
          : banglaMeaning;

  String getCategory(Locale locale) =>
      locale.languageCode == 'en' && categoryEnglish != null
          ? categoryEnglish!
          : category;

  factory AyatModel.fromJson(Map<String, dynamic> json) {
    return AyatModel(
      id: json['id'] as int,
      titleBangla: json['titleBangla'] as String,
      surahName: json['surahName'] as String,
      surahNameArabic: json['surahNameArabic'] as String,
      surahNumber: json['surahNumber'] as int,
      ayatNumber: json['ayatNumber'] as String,
      arabicText: json['arabicText'] as String,
      banglaTransliteration: json['banglaTransliteration'] as String,
      banglaMeaning: json['banglaMeaning'] as String,
      reference: json['reference'] as String,
      category: json['category'] as String,
      displayOrder: json['displayOrder'] as int,
      titleEnglish: json['titleEnglish'] as String?,
      surahNameEnglish: json['surahNameEnglish'] as String?,
      englishTransliteration: json['englishTransliteration'] as String?,
      englishMeaning: json['englishMeaning'] as String?,
      categoryEnglish: json['categoryEnglish'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titleBangla': titleBangla,
      'surahName': surahName,
      'surahNameArabic': surahNameArabic,
      'surahNumber': surahNumber,
      'ayatNumber': ayatNumber,
      'arabicText': arabicText,
      'banglaTransliteration': banglaTransliteration,
      'banglaMeaning': banglaMeaning,
      'reference': reference,
      'category': category,
      'displayOrder': displayOrder,
      if (titleEnglish != null) 'titleEnglish': titleEnglish,
      if (surahNameEnglish != null) 'surahNameEnglish': surahNameEnglish,
      if (englishTransliteration != null)
        'englishTransliteration': englishTransliteration,
      if (englishMeaning != null) 'englishMeaning': englishMeaning,
      if (categoryEnglish != null) 'categoryEnglish': categoryEnglish,
    };
  }

  @override
  String toString() {
    return 'AyatModel(id: $id, titleBangla: $titleBangla, surahName: $surahName, ayatNumber: $ayatNumber)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AyatModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
