import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/worship_guide_model.dart';
import '../../../widgets/ebadat/worship_step_card.dart';
import '../../../widgets/ebadat/reference_chip.dart';

/// A reusable screen for displaying worship guides
class WorshipGuideScreen extends StatefulWidget {
  final WorshipGuideModel guide;

  const WorshipGuideScreen({
    super.key,
    required this.guide,
  });

  @override
  State<WorshipGuideScreen> createState() => _WorshipGuideScreenState();
}

class _WorshipGuideScreenState extends State<WorshipGuideScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _shareGuide() async {
    try {
      final buffer = StringBuffer();
      buffer.writeln(widget.guide.titleBangla);
      buffer.writeln('=' * 30);
      buffer.writeln();
      buffer.writeln(widget.guide.introduction);
      buffer.writeln();

      if (widget.guide.steps.isNotEmpty) {
        buffer.writeln('ধাপসমূহ:');
        for (final step in widget.guide.steps) {
          buffer.writeln('${step.stepNumber}. ${step.titleBangla}');
          if (step.arabicText != null) {
            buffer.writeln('   ${step.arabicText}');
          }
          buffer.writeln('   ${step.instruction}');
          buffer.writeln();
        }
      }

      await Share.share(
        buffer.toString(),
        subject: widget.guide.titleBangla,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('শেয়ার করতে সমস্যা হয়েছে'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyToClipboard() async {
    try {
      final buffer = StringBuffer();
      buffer.writeln(widget.guide.titleBangla);

      if (widget.guide.keyVerse != null) {
        buffer.writeln();
        buffer.writeln(widget.guide.keyVerse);
      }

      await Clipboard.setData(ClipboardData(text: buffer.toString()));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ক্লিপবোর্ডে কপি হয়েছে'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('কপি করতে সমস্যা হয়েছে'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final guide = widget.guide;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          guide.titleBangla,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyToClipboard,
            tooltip: 'কপি',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareGuide,
            tooltip: 'শেয়ার',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with titles
              _buildHeader(theme),

              const SizedBox(height: 20),

              // Key verse (if available)
              if (guide.keyVerse != null) _buildKeyVerse(theme),

              const SizedBox(height: 20),

              // Introduction
              _buildIntroduction(theme),

              const SizedBox(height: 24),

              // Conditions section
              if (guide.conditions.isNotEmpty)
                _buildConditionsSection(theme),

              // Fard acts section
              if (guide.fardActs.isNotEmpty)
                _buildFardActsSection(theme),

              // Sunnah acts section
              if (guide.sunnahActs.isNotEmpty)
                _buildSunnahActsSection(theme),

              // Steps section
              if (guide.steps.isNotEmpty) _buildStepsSection(theme),

              // Invalidators section
              if (guide.invalidators.isNotEmpty)
                _buildInvalidatorsSection(theme),

              // Common mistakes section
              if (guide.commonMistakes.isNotEmpty)
                _buildCommonMistakesSection(theme),

              // Special rulings section
              if (guide.specialRulings.isNotEmpty)
                _buildSpecialRulingsSection(theme),

              // References section (aggregates from steps and guide)
              _buildReferencesSection(theme),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final guide = widget.guide;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Arabic title (if available)
        if (guide.titleArabic != null) ...[
          Text(
            guide.titleArabic!,
            style: GoogleFonts.amiri(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: theme.brightness == Brightness.dark
                  ? Colors.amber.shade200
                  : Colors.brown.shade800,
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 8),
        ],

        // English title
        Text(
          guide.titleEnglish,
          style: TextStyle(
            fontSize: 14,
            color: theme.textTheme.bodySmall?.color,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildKeyVerse(ThemeData theme) {
    final guide = widget.guide;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: theme.brightness == Brightness.dark
              ? [Colors.green.shade900, Colors.teal.shade900]
              : [Colors.green.shade50, Colors.teal.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.green.shade700
              : Colors.green.shade200,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.menu_book,
            size: 32,
            color: theme.brightness == Brightness.dark
                ? Colors.green.shade300
                : Colors.green.shade700,
          ),
          const SizedBox(height: 12),
          Text(
            guide.keyVerse!,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: GoogleFonts.amiri(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              height: 1.8,
              color: theme.brightness == Brightness.dark
                  ? Colors.green.shade100
                  : Colors.green.shade900,
            ),
          ),
          if (guide.keyVerseReference != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? Colors.green.shade800
                    : Colors.green.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                guide.keyVerseReference!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.brightness == Brightness.dark
                      ? Colors.green.shade200
                      : Colors.green.shade800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIntroduction(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        widget.guide.introduction,
        style: TextStyle(
          fontSize: 15,
          height: 1.7,
          color: theme.textTheme.bodyLarge?.color,
        ),
      ),
    );
  }

  Widget _buildConditionsSection(ThemeData theme) {
    return CollapsibleSection(
      title: 'শর্তসমূহ',
      icon: Icons.checklist,
      color: Colors.blue.shade700,
      initiallyExpanded: false,
      children: widget.guide.conditions.asMap().entries.map((entry) {
        return WorshipListItem(
          text: entry.value,
          number: entry.key + 1,
        );
      }).toList(),
    );
  }

  Widget _buildFardActsSection(ThemeData theme) {
    return CollapsibleSection(
      title: 'ফরজসমূহ',
      icon: Icons.priority_high,
      color: Colors.red.shade700,
      initiallyExpanded: false,
      children: widget.guide.fardActs.asMap().entries.map((entry) {
        return WorshipListItem(
          text: entry.value,
          number: entry.key + 1,
        );
      }).toList(),
    );
  }

  Widget _buildSunnahActsSection(ThemeData theme) {
    return CollapsibleSection(
      title: 'সুন্নাতসমূহ',
      icon: Icons.star,
      color: Colors.green.shade700,
      initiallyExpanded: false,
      children: widget.guide.sunnahActs.asMap().entries.map((entry) {
        return WorshipListItem(
          text: entry.value,
          number: entry.key + 1,
        );
      }).toList(),
    );
  }

  Widget _buildStepsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorshipSectionHeader(
          title: 'ধাপে ধাপে নিয়ম',
          icon: Icons.format_list_numbered,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 8),
        ...widget.guide.steps.map((step) {
          return WorshipStepCard(step: step);
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildInvalidatorsSection(ThemeData theme) {
    return CollapsibleSection(
      title: 'যা ভঙ্গ করে',
      icon: Icons.cancel,
      color: Colors.orange.shade700,
      initiallyExpanded: false,
      children: widget.guide.invalidators.asMap().entries.map((entry) {
        return WorshipListItem(
          text: entry.value,
          icon: Icons.cancel_outlined,
          iconColor: Colors.orange.shade600,
        );
      }).toList(),
    );
  }

  Widget _buildCommonMistakesSection(ThemeData theme) {
    return CollapsibleSection(
      title: 'সাধারণ ভুলসমূহ',
      icon: Icons.warning_amber,
      color: Colors.amber.shade700,
      initiallyExpanded: false,
      children: widget.guide.commonMistakes.asMap().entries.map((entry) {
        return WorshipListItem(
          text: entry.value,
          icon: Icons.error_outline,
          iconColor: Colors.amber.shade600,
        );
      }).toList(),
    );
  }

  Widget _buildSpecialRulingsSection(ThemeData theme) {
    return CollapsibleSection(
      title: 'বিশেষ মাসআলা',
      icon: Icons.lightbulb,
      color: Colors.purple.shade700,
      initiallyExpanded: false,
      children: widget.guide.specialRulings.asMap().entries.map((entry) {
        return WorshipListItem(
          text: entry.value,
          icon: Icons.info_outline,
          iconColor: Colors.purple.shade600,
        );
      }).toList(),
    );
  }

  Widget _buildReferencesSection(ThemeData theme) {
    // Collect all references from steps first (individual references)
    final allReferences = <Reference>[];

    // Add references from each step
    for (final step in widget.guide.steps) {
      allReferences.addAll(step.references);
    }

    // Add model-level references
    allReferences.addAll(widget.guide.references);

    // Deduplicate by source + citation, handling combined citations
    final uniqueReferences = <String, Reference>{};
    final addedNumbersBySource = <String, Set<String>>{};

    for (final ref in allReferences) {
      final exactKey = '${ref.source}_${ref.citation}';

      // Extract all numbers from the citation (both English 0-9 and Bengali ০-৯)
      final numbers = RegExp(r'[\d০১২৩৪৫৬৭৮৯]+').allMatches(ref.citation).map((m) => m.group(0)!).toSet();

      // Get already added numbers for this source
      final sourceNumbers = addedNumbersBySource.putIfAbsent(ref.source, () => <String>{});

      // Check if all numbers in this citation are already covered
      final isFullyDuplicate = numbers.isNotEmpty && numbers.every((n) => sourceNumbers.contains(n));

      if (!uniqueReferences.containsKey(exactKey) && !isFullyDuplicate) {
        uniqueReferences[exactKey] = ref;
        sourceNumbers.addAll(numbers);
      }
    }

    final finalReferences = uniqueReferences.values.toList();

    if (finalReferences.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        ReferenceSection(
          references: finalReferences,
          title: 'সকল সূত্র',
        ),
      ],
    );
  }
}
