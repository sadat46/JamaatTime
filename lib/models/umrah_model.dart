class UmrahDuaModel {
  final int id;
  final String titleBangla;
  final String arabicText;
  final String banglaTransliteration;
  final String banglaMeaning;
  final String occasion;

  const UmrahDuaModel({
    required this.id,
    required this.titleBangla,
    required this.arabicText,
    required this.banglaTransliteration,
    required this.banglaMeaning,
    required this.occasion,
  });

  factory UmrahDuaModel.fromJson(Map<String, dynamic> json) {
    return UmrahDuaModel(
      id: json['id'] as int,
      titleBangla: json['titleBangla'] as String,
      arabicText: json['arabicText'] as String,
      banglaTransliteration: json['banglaTransliteration'] as String,
      banglaMeaning: json['banglaMeaning'] as String,
      occasion: json['occasion'] as String,
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

  const UmrahSectionModel({
    required this.id,
    required this.titleBangla,
    required this.titleArabic,
    required this.description,
    required this.stepNumber,
    required this.rules,
    required this.relatedDuas,
  });

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
