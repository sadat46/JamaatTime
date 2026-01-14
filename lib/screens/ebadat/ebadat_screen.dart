import 'package:flutter/material.dart';
import '../../models/ebadat_topic.dart';
import '../../services/bookmark_service.dart';
import '../../widgets/ebadat/ebadat_topic_card.dart';
import 'topics/umrah_list_screen.dart';
import 'topics/ayat_list_screen.dart';
import 'topics/dua_list_screen.dart';
import 'topics/topic_placeholder_screen.dart';

class EbadatScreen extends StatefulWidget {
  const EbadatScreen({super.key});

  @override
  State<EbadatScreen> createState() => _EbadatScreenState();
}

class _EbadatScreenState extends State<EbadatScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize BookmarkService to load user's bookmarks
    BookmarkService().initialize();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('ইবাদত'),
        centerTitle: true,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
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
      case 1: // Umrah
        screen = const UmrahListScreen();
        break;
      case 2: // Ayat
        screen = const AyatListScreen();
        break;
      case 3: // Dua
        screen = const DuaListScreen();
        break;
      default: // Placeholder screens for new topics
        screen = TopicPlaceholderScreen(topic: topic);
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }
}
