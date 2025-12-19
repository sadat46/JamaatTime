import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import '../models/ayat_model.dart';
import '../models/dua_model.dart';
import '../models/umrah_model.dart';

class EbadatDataService {
  // Singleton pattern
  static final EbadatDataService _instance = EbadatDataService._internal();
  factory EbadatDataService() => _instance;
  EbadatDataService._internal();

  // Cached data
  List<AyatModel>? _cachedAyats;
  List<DuaModel>? _cachedDuas;
  List<UmrahSectionModel>? _cachedUmrahSections;

  // Load methods
  Future<List<AyatModel>> loadAyats() async {
    if (_cachedAyats != null) return _cachedAyats!;

    try {
      final jsonString = await rootBundle.loadString('assets/data/ayats.json');
      final jsonData = json.decode(jsonString);
      _cachedAyats = (jsonData['ayats'] as List)
          .map((item) => AyatModel.fromJson(item as Map<String, dynamic>))
          .toList();

      // Sort by displayOrder
      _cachedAyats!.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

      return _cachedAyats!;
    } catch (e, stackTrace) {
      developer.log(
        'Error loading ayats',
        error: e,
        stackTrace: stackTrace,
        name: 'EbadatDataService',
      );
      _cachedAyats = []; // Cache empty list to avoid repeated failures
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

      // Sort by displayOrder
      _cachedDuas!.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

      return _cachedDuas!;
    } catch (e, stackTrace) {
      developer.log(
        'Error loading duas',
        error: e,
        stackTrace: stackTrace,
        name: 'EbadatDataService',
      );
      _cachedDuas = []; // Cache empty list to avoid repeated failures
      return [];
    }
  }

  Future<List<UmrahSectionModel>> loadUmrahSections() async {
    if (_cachedUmrahSections != null) return _cachedUmrahSections!;

    try {
      final jsonString = await rootBundle.loadString('assets/data/umrah.json');
      final jsonData = json.decode(jsonString);
      _cachedUmrahSections = (jsonData['sections'] as List)
          .map((item) => UmrahSectionModel.fromJson(item as Map<String, dynamic>))
          .toList();

      // Sort by stepNumber
      _cachedUmrahSections!.sort((a, b) => a.stepNumber.compareTo(b.stepNumber));

      return _cachedUmrahSections!;
    } catch (e, stackTrace) {
      developer.log(
        'Error loading umrah sections',
        error: e,
        stackTrace: stackTrace,
        name: 'EbadatDataService',
      );
      _cachedUmrahSections = []; // Cache empty list to avoid repeated failures
      return [];
    }
  }

  // Filter methods
  Future<List<AyatModel>> getAyatsByCategory(String category) async {
    final ayats = await loadAyats();
    return ayats.where((ayat) => ayat.category == category).toList();
  }

  Future<List<DuaModel>> getDuasByCategory(String category) async {
    final duas = await loadDuas();
    return duas.where((dua) => dua.category == category).toList();
  }

  Future<List<String>> getAyatCategories() async {
    final ayats = await loadAyats();
    final categories = ayats.map((ayat) => ayat.category).toSet().toList();
    categories.sort();
    return categories;
  }

  Future<List<String>> getDuaCategories() async {
    final duas = await loadDuas();
    final categories = duas.map((dua) => dua.category).toSet().toList();
    categories.sort();
    return categories;
  }

  // Search methods
  Future<List<AyatModel>> searchAyats(String query) async {
    if (query.isEmpty) return [];

    final ayats = await loadAyats();
    final lowerQuery = query.toLowerCase();

    return ayats.where((ayat) {
      return ayat.titleBangla.toLowerCase().contains(lowerQuery) ||
          ayat.surahName.toLowerCase().contains(lowerQuery) ||
          ayat.arabicText.contains(query) ||
          ayat.banglaTransliteration.toLowerCase().contains(lowerQuery) ||
          ayat.banglaMeaning.toLowerCase().contains(lowerQuery) ||
          ayat.category.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  Future<List<DuaModel>> searchDuas(String query) async {
    if (query.isEmpty) return [];

    final duas = await loadDuas();
    final lowerQuery = query.toLowerCase();

    return duas.where((dua) {
      return dua.titleBangla.toLowerCase().contains(lowerQuery) ||
          dua.arabicText.contains(query) ||
          dua.banglaTransliteration.toLowerCase().contains(lowerQuery) ||
          dua.banglaMeaning.toLowerCase().contains(lowerQuery) ||
          dua.category.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  // Get specific ayat by ID
  Future<AyatModel?> getAyatById(int id) async {
    final ayats = await loadAyats();
    try {
      return ayats.firstWhere((ayat) => ayat.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get specific dua by ID
  Future<DuaModel?> getDuaById(int id) async {
    final duas = await loadDuas();
    try {
      return duas.firstWhere((dua) => dua.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get specific umrah section by ID
  Future<UmrahSectionModel?> getUmrahSectionById(int id) async {
    final sections = await loadUmrahSections();
    try {
      return sections.firstWhere((section) => section.id == id);
    } catch (e) {
      return null;
    }
  }

  // Clear cache (useful for testing or if data needs to be reloaded)
  void clearCache() {
    _cachedAyats = null;
    _cachedDuas = null;
    _cachedUmrahSections = null;
  }

  // Get total counts
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
