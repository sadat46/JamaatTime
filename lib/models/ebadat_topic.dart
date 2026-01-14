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

/// List of all 15 Ebadat topics for the dashboard grid
const List<EbadatTopic> ebadatTopics = [
  EbadatTopic(
    id: 1,
    titleBangla: 'ওমরাহ',
    titleEnglish: 'Umrah',
    icon: Icons.flight_takeoff,
  ),
  EbadatTopic(
    id: 2,
    titleBangla: 'আয়াত',
    titleEnglish: 'Ayat',
    icon: Icons.menu_book,
  ),
  EbadatTopic(
    id: 3,
    titleBangla: 'দোয়া',
    titleEnglish: 'Dua',
    icon: Icons.pan_tool,
  ),
  EbadatTopic(
    id: 4,
    titleBangla: 'তাহাজ্জুদ নামাজ',
    titleEnglish: 'Tahajjut Prayer',
    icon: Icons.nightlight_round,
  ),
  EbadatTopic(
    id: 5,
    titleBangla: 'ফরজ গোসল',
    titleEnglish: 'Fard Gosol',
    icon: Icons.water_drop,
  ),
  EbadatTopic(
    id: 6,
    titleBangla: 'হজ্জ',
    titleEnglish: 'Hajj',
    icon: Icons.location_city,
  ),
  EbadatTopic(
    id: 7,
    titleBangla: 'তায়াম্মুম',
    titleEnglish: 'Tayammum',
    icon: Icons.landscape,
  ),
  EbadatTopic(
    id: 8,
    titleBangla: 'যাকাত',
    titleEnglish: 'Jakat',
    icon: Icons.volunteer_activism,
  ),
  EbadatTopic(
    id: 9,
    titleBangla: 'কসর নামাজ',
    titleEnglish: 'Qasr Prayer',
    icon: Icons.airplanemode_active,
  ),
  EbadatTopic(
    id: 10,
    titleBangla: 'অজু',
    titleEnglish: 'Oju',
    icon: Icons.wash,
  ),
  EbadatTopic(
    id: 11,
    titleBangla: 'জানাজার নামাজ',
    titleEnglish: 'Janaja Prayer',
    icon: Icons.group,
  ),
  EbadatTopic(
    id: 12,
    titleBangla: 'বিতর নামাজ',
    titleEnglish: 'Wetr Prayer',
    icon: Icons.dark_mode,
  ),
  EbadatTopic(
    id: 13,
    titleBangla: 'কাজা নামাজ',
    titleEnglish: 'Kaj Prayer',
    icon: Icons.update,
  ),
  EbadatTopic(
    id: 14,
    titleBangla: 'সালাতুল আত্তাহিয়্যাতু',
    titleEnglish: 'Salatul Attahiyatu',
    icon: Icons.record_voice_over,
  ),
  EbadatTopic(
    id: 15,
    titleBangla: 'মসজিদে বসার নিয়ম',
    titleEnglish: 'Sitting Inside Mosque',
    icon: Icons.mosque,
  ),
];
