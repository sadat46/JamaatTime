import 'package:flutter/widgets.dart';

class UmrahDuaModel {
  final int id;
  final String titleBangla;
  final String arabicText;
  final String banglaTransliteration;
  final String banglaMeaning;
  final String occasion;
  final String? titleEnglish;
  final String? englishTransliteration;
  final String? englishMeaning;
  final String? occasionEnglish;

  const UmrahDuaModel({
    required this.id,
    required this.titleBangla,
    required this.arabicText,
    required this.banglaTransliteration,
    required this.banglaMeaning,
    required this.occasion,
    this.titleEnglish,
    this.englishTransliteration,
    this.englishMeaning,
    this.occasionEnglish,
  });

  String getTitle(Locale locale) =>
      locale.languageCode == 'en' && titleEnglish != null
          ? titleEnglish!
          : titleBangla;

  String getTransliteration(Locale locale) =>
      locale.languageCode == 'en' && englishTransliteration != null
          ? englishTransliteration!
          : banglaTransliteration;

  String getMeaning(Locale locale) =>
      locale.languageCode == 'en' && englishMeaning != null
          ? englishMeaning!
          : banglaMeaning;

  String getOccasion(Locale locale) =>
      locale.languageCode == 'en' && occasionEnglish != null
          ? occasionEnglish!
          : occasion;

  factory UmrahDuaModel.fromJson(Map<String, dynamic> json) {
    return UmrahDuaModel(
      id: json['id'] as int,
      titleBangla: json['titleBangla'] as String,
      arabicText: json['arabicText'] as String,
      banglaTransliteration: json['banglaTransliteration'] as String,
      banglaMeaning: json['banglaMeaning'] as String,
      occasion: json['occasion'] as String,
      titleEnglish: json['titleEnglish'] as String?,
      englishTransliteration: json['englishTransliteration'] as String?,
      englishMeaning: json['englishMeaning'] as String?,
      occasionEnglish: json['occasionEnglish'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titleBangla': titleBangla,
      'arabicText': arabicText,
      'banglaTransliteration': banglaTransliteration,
      'banglaMeaning': banglaMeaning,
      'occasion': occasion,
      if (titleEnglish != null) 'titleEnglish': titleEnglish,
      if (englishTransliteration != null)
        'englishTransliteration': englishTransliteration,
      if (englishMeaning != null) 'englishMeaning': englishMeaning,
      if (occasionEnglish != null) 'occasionEnglish': occasionEnglish,
    };
  }

  @override
  String toString() {
    return 'UmrahDuaModel(id: $id, titleBangla: $titleBangla, occasion: $occasion)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UmrahDuaModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class UmrahSectionModel {
  final int id;
  final String titleBangla;
  final String titleArabic;
  final String description;
  final int stepNumber;
  final List<String> rules;
  final List<UmrahDuaModel> relatedDuas;
  final String? titleEnglish;
  final String? descriptionEnglish;
  final List<String>? rulesEnglish;

  const UmrahSectionModel({
    required this.id,
    required this.titleBangla,
    required this.titleArabic,
    required this.description,
    required this.stepNumber,
    required this.rules,
    required this.relatedDuas,
    this.titleEnglish,
    this.descriptionEnglish,
    this.rulesEnglish,
  });

  String getTitle(Locale locale) =>
      locale.languageCode == 'en' && titleEnglish != null
          ? titleEnglish!
          : titleBangla;

  String getDescription(Locale locale) =>
      locale.languageCode == 'en' && descriptionEnglish != null
          ? descriptionEnglish!
          : description;

  List<String> getRules(Locale locale) =>
      locale.languageCode == 'en' && rulesEnglish != null
          ? rulesEnglish!
          : rules;

  factory UmrahSectionModel.fromJson(Map<String, dynamic> json) {
    return UmrahSectionModel(
      id: json['id'] as int,
      titleBangla: json['titleBangla'] as String,
      titleArabic: json['titleArabic'] as String,
      description: json['description'] as String,
      stepNumber: json['stepNumber'] as int,
      rules: (json['rules'] as List<dynamic>?)
              ?.map((rule) => rule as String)
              .toList() ??
          [],
      relatedDuas: (json['relatedDuas'] as List<dynamic>?)
              ?.map((dua) => UmrahDuaModel.fromJson(dua as Map<String, dynamic>))
              .toList() ??
          [],
      titleEnglish: json['titleEnglish'] as String?,
      descriptionEnglish: json['descriptionEnglish'] as String?,
      rulesEnglish: (json['rulesEnglish'] as List<dynamic>?)
          ?.map((rule) => rule as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titleBangla': titleBangla,
      'titleArabic': titleArabic,
      'description': description,
      'stepNumber': stepNumber,
      'rules': rules,
      'relatedDuas': relatedDuas.map((dua) => dua.toJson()).toList(),
      if (titleEnglish != null) 'titleEnglish': titleEnglish,
      if (descriptionEnglish != null) 'descriptionEnglish': descriptionEnglish,
      if (rulesEnglish != null) 'rulesEnglish': rulesEnglish,
    };
  }

  @override
  String toString() {
    return 'UmrahSectionModel(id: $id, titleBangla: $titleBangla, stepNumber: $stepNumber, duaCount: ${relatedDuas.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UmrahSectionModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
