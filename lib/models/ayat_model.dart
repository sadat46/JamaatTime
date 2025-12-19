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
  });

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
