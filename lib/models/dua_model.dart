class DuaModel {
  final int id;
  final String titleBangla;
  final String arabicText;
  final String banglaTransliteration;
  final String banglaMeaning;
  final String reference;
  final String category;
  final int displayOrder;

  const DuaModel({
    required this.id,
    required this.titleBangla,
    required this.arabicText,
    required this.banglaTransliteration,
    required this.banglaMeaning,
    required this.reference,
    required this.category,
    required this.displayOrder,
  });

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
