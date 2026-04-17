import 'package:flutter/widgets.dart';

/// Model class representing an Islamic Supplication (Monajat)
///
/// This immutable class contains all the essential information for displaying
/// a single monajat/dua from the Quran, including Arabic text, pronunciation,
/// meaning, and contextual information.
class MonajatModel {
  final int id;
  final String title;
  final String arabic;
  final String pronunciation;
  final String meaning;
  final String context;
  final String? titleEnglish;
  final String? meaningEnglish;
  final String? contextEnglish;

  const MonajatModel({
    required this.id,
    required this.title,
    required this.arabic,
    required this.pronunciation,
    required this.meaning,
    required this.context,
    this.titleEnglish,
    this.meaningEnglish,
    this.contextEnglish,
  });

  String getTitle(Locale locale) =>
      locale.languageCode == 'en' && titleEnglish != null
          ? titleEnglish!
          : title;

  String getMeaning(Locale locale) =>
      locale.languageCode == 'en' && meaningEnglish != null
          ? meaningEnglish!
          : meaning;

  String getContext(Locale locale) =>
      locale.languageCode == 'en' && contextEnglish != null
          ? contextEnglish!
          : context;
}
