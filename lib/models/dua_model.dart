import 'package:flutter/widgets.dart';

class DuaModel {
  final int id;
  final String titleBangla;
  final String arabicText;
  final String banglaTransliteration;
  final String banglaMeaning;
  final String reference;
  final String category;
  final int displayOrder;
  final String? titleEnglish;
  final String? englishTransliteration;
  final String? englishMeaning;
  final String? categoryEnglish;

  const DuaModel({
    required this.id,
    required this.titleBangla,
    required this.arabicText,
    required this.banglaTransliteration,
    required this.banglaMeaning,
    required this.reference,
    required this.category,
    required this.displayOrder,
    this.titleEnglish,
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

  factory DuaModel.fromJson(Map<String, dynamic> json) {
    return DuaModel(
      id: json['id'] as int,
      titleBangla: json['titleBangla'] as String,
      arabicText: json['arabicText'] as String,
      banglaTransliteration: json['banglaTransliteration'] as String,
      banglaMeaning: json['banglaMeaning'] as String,
      reference: json['reference'] as String,
      category: json['category'] as String,
      displayOrder: json['displayOrder'] as int,
      titleEnglish: json['titleEnglish'] as String?,
      englishTransliteration: json['englishTransliteration'] as String?,
      englishMeaning: json['englishMeaning'] as String?,
      categoryEnglish: json['categoryEnglish'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titleBangla': titleBangla,
      'arabicText': arabicText,
      'banglaTransliteration': banglaTransliteration,
      'banglaMeaning': banglaMeaning,
      'reference': reference,
      'category': category,
      'displayOrder': displayOrder,
      if (titleEnglish != null) 'titleEnglish': titleEnglish,
      if (englishTransliteration != null)
        'englishTransliteration': englishTransliteration,
      if (englishMeaning != null) 'englishMeaning': englishMeaning,
      if (categoryEnglish != null) 'categoryEnglish': categoryEnglish,
    };
  }

  @override
  String toString() {
    return 'DuaModel(id: $id, titleBangla: $titleBangla, category: $category)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DuaModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
