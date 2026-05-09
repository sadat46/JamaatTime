import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../models/ayat_model.dart';
import '../models/dua_model.dart';
import '../models/umrah_model.dart';

/// Loads Ebadat content (ayats, duas, umrah sections) from bundled JSON.
///
/// Lazy-loaded by design: the loaders are only called from the corresponding
/// tab's `initState` (see `screens/ebadat/tabs/`), so cold start doesn't pay
/// for any of this work. Once loaded, results are cached in memory for the
/// process lifetime via the singleton instance.
///
/// **Why no `compute()` wrap:** the three JSON assets total ~50 KB. At this
/// size, an isolate hop would add more overhead than the parse itself.
/// Wrapping these parses in `compute()` would *slow down* first-tab-open, not
/// speed it up. If a future asset grows past ~200 KB, reconsider.
class EbadatDataService {
  static final EbadatDataService _instance = EbadatDataService._internal();
  factory EbadatDataService() => _instance;
  EbadatDataService._internal();

  List<AyatModel>? _cachedAyats;
  List<DuaModel>? _cachedDuas;
  List<UmrahSectionModel>? _cachedUmrahSections;

  bool _isEnglish(Locale locale) => locale.languageCode == 'en';

  String _ayatCategoryForLocale(AyatModel ayat, Locale locale) =>
      _isEnglish(locale)
      ? ayat.categoryEnglish ?? ayat.categoryBangla
      : ayat.categoryBangla;

  String _duaCategoryForLocale(DuaModel dua, Locale locale) =>
      _isEnglish(locale)
      ? dua.categoryEnglish ?? dua.categoryBangla
      : dua.categoryBangla;

  Future<List<AyatModel>> loadAyats() async {
    if (_cachedAyats != null) return _cachedAyats!;

    try {
      final jsonString = await rootBundle.loadString('assets/data/ayats.json');
      final jsonData = json.decode(jsonString);
      _cachedAyats = (jsonData['ayats'] as List)
          .map((item) => AyatModel.fromJson(item as Map<String, dynamic>))
          .toList();

      _cachedAyats!.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      return _cachedAyats!;
    } catch (e, stackTrace) {
      developer.log(
        'Error loading ayats',
        error: e,
        stackTrace: stackTrace,
        name: 'EbadatDataService',
      );
      _cachedAyats = [];
      return [];
    }
  }

  Future<List<DuaModel>> loadDuas() async {
    if (_cachedDuas != null) return _cachedDuas!;

    try {
      final jsonString = await rootBundle.loadString('assets/data/duas.json');
      final jsonData = json.decode(jsonString);
      _cachedDuas = (jsonData['duas'] as List)
          .map((item) => DuaModel.fromJson(item as Map<String, dynamic>))
          .toList();

      _cachedDuas!.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      return _cachedDuas!;
    } catch (e, stackTrace) {
      developer.log(
        'Error loading duas',
        error: e,
        stackTrace: stackTrace,
        name: 'EbadatDataService',
      );
      _cachedDuas = [];
      return [];
    }
  }

  Future<List<UmrahSectionModel>> loadUmrahSections() async {
    if (_cachedUmrahSections != null) return _cachedUmrahSections!;

    try {
      final jsonString = await rootBundle.loadString('assets/data/umrah.json');
      final jsonData = json.decode(jsonString);
      _cachedUmrahSections = (jsonData['sections'] as List)
          .map(
            (item) => UmrahSectionModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();

      _cachedUmrahSections!.sort(
        (a, b) => a.stepNumber.compareTo(b.stepNumber),
      );
      return _cachedUmrahSections!;
    } catch (e, stackTrace) {
      developer.log(
        'Error loading umrah sections',
        error: e,
        stackTrace: stackTrace,
        name: 'EbadatDataService',
      );
      _cachedUmrahSections = [];
      return [];
    }
  }

  Future<List<AyatModel>> getAyatsByCategory(
    String category, {
    required Locale locale,
  }) async {
    final ayats = await loadAyats();
    return ayats
        .where((ayat) => _ayatCategoryForLocale(ayat, locale) == category)
        .toList();
  }

  Future<List<DuaModel>> getDuasByCategory(
    String category, {
    required Locale locale,
  }) async {
    final duas = await loadDuas();
    return duas
        .where((dua) => _duaCategoryForLocale(dua, locale) == category)
        .toList();
  }

  Future<List<String>> getAyatCategories({required Locale locale}) async {
    final ayats = await loadAyats();
    final categories = ayats
        .map((ayat) => _ayatCategoryForLocale(ayat, locale))
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  Future<List<String>> getDuaCategories({required Locale locale}) async {
    final duas = await loadDuas();
    final categories = duas
        .map((dua) => _duaCategoryForLocale(dua, locale))
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  Future<List<AyatModel>> searchAyats(
    String query, {
    required Locale locale,
  }) async {
    if (query.isEmpty) return [];

    final ayats = await loadAyats();
    final lowerQuery = query.toLowerCase();

    return ayats.where((ayat) {
      final title = ayat.getTitle(locale).toLowerCase();
      final surah = ayat.getSurahName(locale).toLowerCase();
      final transliteration = ayat.getTransliteration(locale).toLowerCase();
      final meaning = ayat.getMeaning(locale).toLowerCase();
      final category = _ayatCategoryForLocale(ayat, locale).toLowerCase();
      final arabic = ayat.arabicText;

      return title.contains(lowerQuery) ||
          surah.contains(lowerQuery) ||
          transliteration.contains(lowerQuery) ||
          meaning.contains(lowerQuery) ||
          category.contains(lowerQuery) ||
          arabic.contains(query);
    }).toList();
  }

  Future<List<DuaModel>> searchDuas(
    String query, {
    required Locale locale,
  }) async {
    if (query.isEmpty) return [];

    final duas = await loadDuas();
    final lowerQuery = query.toLowerCase();

    return duas.where((dua) {
      final title = dua.getTitle(locale).toLowerCase();
      final transliteration = dua.getTransliteration(locale).toLowerCase();
      final meaning = dua.getMeaning(locale).toLowerCase();
      final category = _duaCategoryForLocale(dua, locale).toLowerCase();
      final arabic = dua.arabicText;

      return title.contains(lowerQuery) ||
          transliteration.contains(lowerQuery) ||
          meaning.contains(lowerQuery) ||
          category.contains(lowerQuery) ||
          arabic.contains(query);
    }).toList();
  }

  Future<AyatModel?> getAyatById(int id) async {
    final ayats = await loadAyats();
    try {
      return ayats.firstWhere((ayat) => ayat.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<DuaModel?> getDuaById(int id) async {
    final duas = await loadDuas();
    try {
      return duas.firstWhere((dua) => dua.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<UmrahSectionModel?> getUmrahSectionById(int id) async {
    final sections = await loadUmrahSections();
    try {
      return sections.firstWhere((section) => section.id == id);
    } catch (_) {
      return null;
    }
  }

  void clearCache() {
    _cachedAyats = null;
    _cachedDuas = null;
    _cachedUmrahSections = null;
  }

  Future<int> getAyatsCount() async {
    final ayats = await loadAyats();
    return ayats.length;
  }

  Future<int> getDuasCount() async {
    final duas = await loadDuas();
    return duas.length;
  }

  Future<int> getUmrahSectionsCount() async {
    final sections = await loadUmrahSections();
    return sections.length;
  }
}
