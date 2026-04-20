import 'package:flutter/widgets.dart';
import 'package:jamaat_time/models/ayat_model.dart';
import 'package:jamaat_time/models/dua_model.dart';
import 'package:jamaat_time/models/umrah_model.dart';
import 'package:jamaat_time/services/ebadat_data_service.dart';

class FakeEbadatDataService implements EbadatDataService {
  FakeEbadatDataService({
    List<AyatModel>? ayats,
    List<DuaModel>? duas,
    List<UmrahSectionModel>? umrahSections,
    this.throwOnAyatLoad = false,
    this.throwOnDuaLoad = false,
    this.throwOnUmrahLoad = false,
  }) : _ayats = ayats ?? const [],
       _duas = duas ?? const [],
       _umrahSections = umrahSections ?? const [];

  final List<AyatModel> _ayats;
  final List<DuaModel> _duas;
  final List<UmrahSectionModel> _umrahSections;

  final bool throwOnAyatLoad;
  final bool throwOnDuaLoad;
  final bool throwOnUmrahLoad;

  @override
  Future<List<AyatModel>> loadAyats() async {
    if (throwOnAyatLoad) {
      throw Exception('Failed to load ayats');
    }
    return _ayats;
  }

  @override
  Future<List<DuaModel>> loadDuas() async {
    if (throwOnDuaLoad) {
      throw Exception('Failed to load duas');
    }
    return _duas;
  }

  @override
  Future<List<UmrahSectionModel>> loadUmrahSections() async {
    if (throwOnUmrahLoad) {
      throw Exception('Failed to load umrah sections');
    }
    return _umrahSections;
  }

  @override
  Future<List<AyatModel>> getAyatsByCategory(
    String category, {
    required Locale locale,
  }) async {
    final ayats = await loadAyats();
    return ayats.where((ayat) => ayat.getCategory(locale) == category).toList();
  }

  @override
  Future<List<DuaModel>> getDuasByCategory(
    String category, {
    required Locale locale,
  }) async {
    final duas = await loadDuas();
    return duas.where((dua) => dua.getCategory(locale) == category).toList();
  }

  @override
  Future<List<String>> getAyatCategories({required Locale locale}) async {
    final ayats = await loadAyats();
    final categories = ayats
        .map((ayat) => ayat.getCategory(locale))
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  @override
  Future<List<String>> getDuaCategories({required Locale locale}) async {
    final duas = await loadDuas();
    final categories = duas
        .map((dua) => dua.getCategory(locale))
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  @override
  Future<List<AyatModel>> searchAyats(
    String query, {
    required Locale locale,
  }) async {
    if (query.isEmpty) {
      return [];
    }
    final lower = query.toLowerCase();
    final ayats = await loadAyats();
    return ayats.where((ayat) {
      return ayat.getTitle(locale).toLowerCase().contains(lower) ||
          ayat.getMeaning(locale).toLowerCase().contains(lower) ||
          ayat.getCategory(locale).toLowerCase().contains(lower) ||
          ayat.arabicText.contains(query);
    }).toList();
  }

  @override
  Future<List<DuaModel>> searchDuas(
    String query, {
    required Locale locale,
  }) async {
    if (query.isEmpty) {
      return [];
    }
    final lower = query.toLowerCase();
    final duas = await loadDuas();
    return duas.where((dua) {
      return dua.getTitle(locale).toLowerCase().contains(lower) ||
          dua.getMeaning(locale).toLowerCase().contains(lower) ||
          dua.getCategory(locale).toLowerCase().contains(lower) ||
          dua.arabicText.contains(query);
    }).toList();
  }

  @override
  Future<AyatModel?> getAyatById(int id) async {
    final ayats = await loadAyats();
    for (final ayat in ayats) {
      if (ayat.id == id) {
        return ayat;
      }
    }
    return null;
  }

  @override
  Future<DuaModel?> getDuaById(int id) async {
    final duas = await loadDuas();
    for (final dua in duas) {
      if (dua.id == id) {
        return dua;
      }
    }
    return null;
  }

  @override
  Future<UmrahSectionModel?> getUmrahSectionById(int id) async {
    final sections = await loadUmrahSections();
    for (final section in sections) {
      if (section.id == id) {
        return section;
      }
    }
    return null;
  }

  @override
  void clearCache() {}

  @override
  Future<int> getAyatsCount() async => (await loadAyats()).length;

  @override
  Future<int> getDuasCount() async => (await loadDuas()).length;

  @override
  Future<int> getUmrahSectionsCount() async =>
      (await loadUmrahSections()).length;
}
