import 'package:flutter/material.dart';
import '../../../models/ebadat_topic.dart';

/// A placeholder screen for topics that are not yet implemented
class TopicPlaceholderScreen extends StatelessWidget {
  final EbadatTopic topic;

  const TopicPlaceholderScreen({
    super.key,
    required this.topic,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = topic.accentColor ?? colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          topic.titleBangla,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  topic.icon,
                  size: 64,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                topic.titleBangla,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'শীঘ্রই আসছে...',
                style: TextStyle(
                  fontSize: 18,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'এই বিভাগের বিষয়বস্তু প্রস্তুত হচ্ছে।',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
