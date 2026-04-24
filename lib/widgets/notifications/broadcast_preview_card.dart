import 'package:flutter/material.dart';

// Mimics the expanded Android heads-up notification card that a user would
// see in the drawer. Kept purely presentational — no state, no I/O — so the
// admin screen can rebuild it every keystroke.
class BroadcastPreviewCard extends StatelessWidget {
  const BroadcastPreviewCard({
    super.key,
    required this.title,
    required this.body,
    required this.imageUrl,
    this.appLabel = 'Jamaat Time',
  });

  final String title;
  final String body;
  final String? imageUrl;
  final String appLabel;

  @override
  Widget build(BuildContext context) {
    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2A2A)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFF388E3C).withAlpha(40),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.mosque,
                    size: 14,
                    color: Color(0xFF388E3C),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$appLabel • now',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.expand_more, size: 16, color: Colors.grey[500]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trimmedTitle.isEmpty ? '—' : trimmedTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  trimmedBody.isEmpty ? '—' : trimmedBody,
                  style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (hasImage)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
              child: AspectRatio(
                aspectRatio: 2,
                child: Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[200],
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: Colors.grey[100],
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
