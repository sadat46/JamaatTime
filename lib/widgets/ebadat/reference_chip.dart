import 'package:flutter/material.dart';
import '../../models/worship_guide_model.dart';

/// A chip widget that displays a reference (Quran or Hadith)
class ReferenceChip extends StatelessWidget {
  final Reference reference;
  final bool compact;

  const ReferenceChip({
    super.key,
    required this.reference,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isQuran = reference.isQuran;
    final isSahih = reference.isSahihHadith;

    // Determine colors based on reference type
    Color backgroundColor;
    Color textColor;
    IconData icon;

    if (isQuran) {
      backgroundColor = Colors.green.shade50;
      textColor = Colors.green.shade800;
      icon = Icons.menu_book;
    } else if (isSahih) {
      backgroundColor = Colors.amber.shade50;
      textColor = Colors.amber.shade800;
      icon = Icons.auto_stories;
    } else {
      backgroundColor = Colors.blue.shade50;
      textColor = Colors.blue.shade800;
      icon = Icons.description;
    }

    // Handle dark mode
    if (Theme.of(context).brightness == Brightness.dark) {
      backgroundColor = isQuran
          ? Colors.green.shade900.withValues(alpha: 0.3)
          : isSahih
              ? Colors.amber.shade900.withValues(alpha: 0.3)
              : Colors.blue.shade900.withValues(alpha: 0.3);
      textColor = isQuran
          ? Colors.green.shade300
          : isSahih
              ? Colors.amber.shade300
              : Colors.blue.shade300;
    }

    final displayText = compact
        ? reference.citation
        : '${reference.source} ${reference.citation}';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(compact ? 4 : 8),
        border: Border.all(
          color: textColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: compact ? 12 : 14,
            color: textColor,
          ),
          SizedBox(width: compact ? 2 : 4),
          Flexible(
            child: Text(
              displayText,
              style: TextStyle(
                fontSize: compact ? 10 : 12,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (reference.grading != null && !compact) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                reference.grading!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A row of reference chips
class ReferenceChipRow extends StatelessWidget {
  final List<Reference> references;
  final bool compact;

  const ReferenceChipRow({
    super.key,
    required this.references,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (references.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: references.map((ref) {
        return ReferenceChip(
          reference: ref,
          compact: compact,
        );
      }).toList(),
    );
  }
}

/// An expandable reference section
class ReferenceSection extends StatefulWidget {
  final List<Reference> references;
  final String title;

  const ReferenceSection({
    super.key,
    required this.references,
    this.title = 'সূত্রসমূহ',
  });

  @override
  State<ReferenceSection> createState() => _ReferenceSectionState();
}

class _ReferenceSectionState extends State<ReferenceSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.references.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.library_books,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.references.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState:
              _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.references.map((ref) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ReferenceDetailCard(reference: ref),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReferenceDetailCard extends StatelessWidget {
  final Reference reference;

  const _ReferenceDetailCard({required this.reference});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isQuran = reference.isQuran;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.grey.shade800.withValues(alpha: 0.5)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isQuran
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.amber.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ReferenceChip(reference: reference),
            ],
          ),
          if (reference.fullText != null && reference.fullText!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              reference.fullText!,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
