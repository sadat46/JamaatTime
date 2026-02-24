import 'package:flutter/material.dart';

/// Model class representing an Ebadat topic for the grid dashboard
class EbadatTopic {
  final int id;
  final String titleBangla;
  final String titleEnglish;
  final IconData icon;
  final Color? accentColor;

  const EbadatTopic({
    required this.id,
    required this.titleBangla,
    required this.titleEnglish,
    required this.icon,
    this.accentColor,
  });
}

/// List of all Ebadat topics for the dashboard grid
const List<EbadatTopic> ebadatTopics = [
  // New Primary Islamic Knowledge Cards
  EbadatTopic(
    id: 16,
    titleBangla: 'ঈমান',
    titleEnglish: 'Eman (Faith)',
    icon: Icons.favorite,
    accentColor: Color(0xFFE91E63), // Pink - Heart/Faith
  ),
  EbadatTopic(
    id: 17,
    titleBangla: 'নামাজ',
    titleEnglish: 'Salah (Prayer)',
    icon: Icons.mosque,
    accentColor: Color(0xFF1565C0), // Deep Blue - Mosque/Prayer
  ),
  EbadatTopic(
    id: 18,
    titleBangla: 'রমজানের রোজা',
    titleEnglish: 'Ramadan Fasting',
    icon: Icons.nightlight_round,
    accentColor: Color(0xFFFF8F00), // Amber - Moon/Ramadan
  ),
  // Existing topics
  EbadatTopic(
    id: 0,
    titleBangla: 'মোনাজাত',
    titleEnglish: 'Monajat',
    icon: Icons.volunteer_activism,
    accentColor: Color(0xFF00897B), // Teal - Supplication
  ),
  EbadatTopic(
    id: 1,
    titleBangla: 'ওমরাহ',
    titleEnglish: 'Umrah',
    icon: Icons.flight_takeoff,
    accentColor: Color(0xFF7B1FA2), // Purple - Travel/Pilgrimage
  ),
  EbadatTopic(
    id: 2,
    titleBangla: 'আয়াত',
    titleEnglish: 'Ayat',
    icon: Icons.menu_book,
    accentColor: Color(0xFF2E7D32), // Green - Quran
  ),
  EbadatTopic(
    id: 3,
    titleBangla: 'দোয়া',
    titleEnglish: 'Dua',
    icon: Icons.pan_tool,
    accentColor: Color(0xFF0288D1), // Light Blue - Hands raised
  ),
  EbadatTopic(
    id: 4,
    titleBangla: 'তাহাজ্জুদ নামাজ',
    titleEnglish: 'Tahajjut Prayer',
    icon: Icons.bedtime,
    accentColor: Color(0xFF3949AB), // Indigo - Night prayer
  ),
  EbadatTopic(
    id: 5,
    titleBangla: 'ফরজ গোসল',
    titleEnglish: 'Fard Gosol',
    icon: Icons.water_drop,
    accentColor: Color(0xFF00ACC1), // Cyan - Water/Purity
  ),
  EbadatTopic(
    id: 6,
    titleBangla: 'হজ্জ',
    titleEnglish: 'Hajj',
    icon: Icons.account_balance,
    accentColor: Color(0xFFD84315), // Deep Orange - Kaaba
  ),
  EbadatTopic(
    id: 7,
    titleBangla: 'তায়াম্মুম',
    titleEnglish: 'Tayammum',
    icon: Icons.landscape,
    accentColor: Color(0xFF8D6E63), // Brown - Earth/Sand
  ),
  EbadatTopic(
    id: 8,
    titleBangla: 'যাকাত',
    titleEnglish: 'Jakat',
    icon: Icons.currency_exchange,
    accentColor: Color(0xFFFBC02D), // Yellow - Gold/Charity
  ),
  EbadatTopic(
    id: 9,
    titleBangla: 'কসর নামাজ',
    titleEnglish: 'Qasr Prayer',
    icon: Icons.airplanemode_active,
    accentColor: Color(0xFF5C6BC0), // Indigo Light - Travel
  ),
  EbadatTopic(
    id: 10,
    titleBangla: 'অজু',
    titleEnglish: 'Oju',
    icon: Icons.wash,
    accentColor: Color(0xFF26A69A), // Teal Light - Ablution
  ),
  EbadatTopic(
    id: 11,
    titleBangla: 'জানাজার নামাজ',
    titleEnglish: 'Janaja Prayer',
    icon: Icons.people_outline,
    accentColor: Color(0xFF546E7A), // Blue Grey - Funeral
  ),
  EbadatTopic(
    id: 12,
    titleBangla: 'বিতর নামাজ',
    titleEnglish: 'Wetr Prayer',
    icon: Icons.nights_stay,
    accentColor: Color(0xFF5E35B1), // Deep Purple - Night
  ),
  EbadatTopic(
    id: 13,
    titleBangla: 'কাজা নামাজ',
    titleEnglish: 'Kaj Prayer',
    icon: Icons.history,
    accentColor: Color(0xFFFF7043), // Deep Orange Light - Makeup prayer
  ),
  EbadatTopic(
    id: 14,
    titleBangla: 'সালাতুল আত্তাহিয়্যাতু',
    titleEnglish: 'Salatul Attahiyatu',
    icon: Icons.record_voice_over,
    accentColor: Color(0xFF43A047), // Green - Recitation
  ),
  EbadatTopic(
    id: 15,
    titleBangla: 'মসজিদে বসার নিয়ম',
    titleEnglish: 'Sitting Inside Mosque',
    icon: Icons.chair,
    accentColor: Color(0xFF039BE5), // Light Blue - Mosque etiquette
  ),
];
