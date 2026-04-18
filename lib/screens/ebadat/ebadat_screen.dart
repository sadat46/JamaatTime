import 'package:flutter/material.dart';
import '../../core/locale_text.dart';
import '../../models/ebadat_topic.dart';
import '../../services/bookmark_service.dart';
import '../../widgets/ebadat/ebadat_topic_card.dart';
import 'topics/monajat_list_screen.dart';
import 'topics/umrah_list_screen.dart';
import 'topics/ayat_list_screen.dart';
import 'topics/dua_list_screen.dart';
import 'topics/topic_placeholder_screen.dart';
import 'topics/worship_guide_screen.dart';
import 'topics/zakat_calculator_screen.dart';
import '../../data/wudu_data.dart';
import '../../data/ghusl_data.dart';
import '../../data/tayammum_data.dart';
import '../../data/tahajjud_data.dart';
import '../../data/witr_data.dart';
import '../../data/janazah_data.dart';
import '../../data/qasr_data.dart';
import '../../data/attahiyatu_data.dart';
import '../../data/tahiyyatul_masjid_data.dart';
import '../../data/eman_data.dart';
import '../../data/namaz_data.dart';
import '../../data/ramadan_roja_data.dart';

class EbadatScreen extends StatefulWidget {
  const EbadatScreen({super.key});

  @override
  State<EbadatScreen> createState() => _EbadatScreenState();
}

class _EbadatScreenState extends State<EbadatScreen> {
  @override
  void initState() {
    super.initState();
    BookmarkService().initialize();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.tr(bn: 'ইবাদত', en: 'Ebadat')),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.0,
          ),
          itemCount: ebadatTopics.length,
          itemBuilder: (context, index) {
            final topic = ebadatTopics[index];
            return EbadatTopicCard(
              topic: topic,
              onTap: () => _navigateToTopic(topic),
            );
          },
        ),
      ),
    );
  }

  void _navigateToTopic(EbadatTopic topic) {
    Widget screen;

    switch (topic.id) {
      case 0:
        screen = const MonajatListScreen();
        break;
      case 1:
        screen = const UmrahListScreen();
        break;
      case 2:
        screen = const AyatListScreen();
        break;
      case 3:
        screen = const DuaListScreen();
        break;
      case 4:
        screen = const WorshipGuideScreen(guide: tahajjudGuide);
        break;
      case 5:
        screen = const WorshipGuideScreen(guide: ghuslGuide);
        break;
      case 7:
        screen = const WorshipGuideScreen(guide: tayammumGuide);
        break;
      case 8:
        screen = const ZakatCalculatorScreen();
        break;
      case 9:
        screen = const WorshipGuideScreen(guide: qasrGuide);
        break;
      case 10:
        screen = const WorshipGuideScreen(guide: wuduGuide);
        break;
      case 11:
        screen = const WorshipGuideScreen(guide: janazahGuide);
        break;
      case 12:
        screen = const WorshipGuideScreen(guide: witrGuide);
        break;
      case 14:
        screen = const WorshipGuideScreen(guide: tahiyyatulMasjidGuide);
        break;
      case 16:
        screen = const WorshipGuideScreen(guide: emanGuide);
        break;
      case 17:
        screen = const WorshipGuideScreen(guide: namazGuide);
        break;
      case 18:
        screen = const WorshipGuideScreen(guide: ramadanRojaGuide);
        break;
      default:
        screen = TopicPlaceholderScreen(topic: topic);
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }
}
