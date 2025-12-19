import 'package:flutter/material.dart';
import 'lib/services/ebadat_data_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final service = EbadatDataService();
  
  print('Testing EbadatDataService...\n');
  
  // Test loading ayats
  final ayats = await service.loadAyats();
  print('✓ Loaded ${ayats.length} ayats');
  
  // Test loading duas
  final duas = await service.loadDuas();
  print('✓ Loaded ${duas.length} duas');
  
  // Test loading umrah sections
  final sections = await service.loadUmrahSections();
  print('✓ Loaded ${sections.length} umrah sections');
  
  // Test categories
  final ayatCategories = await service.getAyatCategories();
  print('✓ Ayat categories: ${ayatCategories.join(", ")}');
  
  final duaCategories = await service.getDuaCategories();
  print('✓ Dua categories: ${duaCategories.join(", ")}');
  
  // Test search
  final searchResults = await service.searchAyats('আয়াতুল কুরসী');
  print('✓ Search found ${searchResults.length} results');
  
  print('\nAll tests passed! ✓');
}
