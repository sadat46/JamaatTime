import 'package:flutter/material.dart';
import '../../models/ebadat_topic.dart';

/// A card widget for displaying an Ebadat topic in the grid dashboard
class EbadatTopicCard extends StatelessWidget {
  final EbadatTopic topic;
  final VoidCallback? onTap;
  final bool isLocked;

  const EbadatTopicCard({
    super.key,
    required this.topic,
    this.onTap,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = topic.accentColor ?? colorScheme.primary;
    final locale = Localizations.localeOf(context);

    return Card(
      elevation: 4,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: primaryColor.withValues(alpha: 0.2),
        highlightColor: primaryColor.withValues(alpha: 0.1),
        child: Stack(
          children: [
            Opacity(
              opacity: isLocked ? 0.4 : 1.0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        topic.icon,
                        size: 32,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      topic.getTitle(locale),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isLocked)
              Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: theme.disabledColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
