import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/locale_text.dart';
import '../../../models/worship_guide_model.dart';
import '../../../widgets/ebadat/reference_chip.dart';
import '../../../widgets/ebadat/worship_step_card.dart';

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
    final locale = Localizations.localeOf(context);
    final guide = widget.guide;
    try {
      final buffer = StringBuffer();
      buffer.writeln(guide.getTitle(locale));
      buffer.writeln('=' * 30);
      buffer.writeln();
      buffer.writeln(guide.getIntroduction(locale));
      buffer.writeln();

      if (guide.steps.isNotEmpty) {
        buffer.writeln(context.tr(bn: 'ধাপসমূহ:', en: 'Steps:'));
        for (final step in guide.steps) {
          buffer.writeln('${step.stepNumber}. ${step.getTitle(locale)}');
          if (step.arabicText != null) {
            buffer.writeln('   ${step.arabicText}');
          }
          buffer.writeln('   ${step.getInstruction(locale)}');
          buffer.writeln();
        }
      }

      await Share.share(
        buffer.toString(),
        subject: guide.getTitle(locale),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              bn: 'শেয়ার করতে সমস্যা হয়েছে',
              en: 'Failed to share',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _copyToClipboard() async {
    final locale = Localizations.localeOf(context);
    final guide = widget.guide;
    try {
      final buffer = StringBuffer();
      buffer.writeln(guide.getTitle(locale));
      if (guide.keyVerse != null) {
        buffer.writeln();
        buffer.writeln(guide.keyVerse);
      }
      await Clipboard.setData(ClipboardData(text: buffer.toString()));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              bn: 'ক্লিপবোর্ডে কপি হয়েছে',
              en: 'Copied to clipboard',
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              bn: 'কপি করতে সমস্যা হয়েছে',
              en: 'Failed to copy',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final guide = widget.guide;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          guide.getTitle(locale),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyToClipboard,
            tooltip: context.tr(bn: 'কপি', en: 'Copy'),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareGuide,
            tooltip: context.tr(bn: 'শেয়ার', en: 'Share'),
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
              _buildHeader(theme, locale),
              const SizedBox(height: 20),
              if (guide.keyVerse != null) _buildKeyVerse(theme),
              const SizedBox(height: 20),
              _buildIntroduction(theme, locale),
              const SizedBox(height: 24),
              if (guide.getConditions(locale).isNotEmpty)
                _buildConditionsSection(theme, locale),
              if (guide.getFardActs(locale).isNotEmpty)
                _buildFardActsSection(theme, locale),
              if (guide.getSunnahActs(locale).isNotEmpty)
                _buildSunnahActsSection(theme, locale),
              if (guide.steps.isNotEmpty) _buildStepsSection(theme, locale),
              if (guide.getInvalidators(locale).isNotEmpty)
                _buildInvalidatorsSection(theme, locale),
              if (guide.getCommonMistakes(locale).isNotEmpty)
                _buildCommonMistakesSection(theme, locale),
              if (guide.getSpecialRulings(locale).isNotEmpty)
                _buildSpecialRulingsSection(theme, locale),
              _buildReferencesSection(theme),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Locale locale) {
    final guide = widget.guide;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
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
        Text(
          locale.languageCode == 'en' ? guide.titleEnglish : guide.titleBangla,
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

  Widget _buildIntroduction(ThemeData theme, Locale locale) {
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
        widget.guide.getIntroduction(locale),
        style: TextStyle(
          fontSize: 15,
          height: 1.7,
          color: theme.textTheme.bodyLarge?.color,
        ),
      ),
    );
  }

  Widget _buildConditionsSection(ThemeData theme, Locale locale) {
    final list = widget.guide.getConditions(locale);
    return CollapsibleSection(
      title: context.tr(bn: 'শর্তসমূহ', en: 'Conditions'),
      icon: Icons.checklist,
      color: Colors.blue.shade700,
      initiallyExpanded: false,
      children: list.asMap().entries.map((entry) {
        return WorshipListItem(text: entry.value, number: entry.key + 1);
      }).toList(),
    );
  }

  Widget _buildFardActsSection(ThemeData theme, Locale locale) {
    final list = widget.guide.getFardActs(locale);
    return CollapsibleSection(
      title: context.tr(bn: 'ফরজসমূহ', en: 'Fard Acts'),
      icon: Icons.priority_high,
      color: Colors.red.shade700,
      initiallyExpanded: false,
      children: list.asMap().entries.map((entry) {
        return WorshipListItem(text: entry.value, number: entry.key + 1);
      }).toList(),
    );
  }

  Widget _buildSunnahActsSection(ThemeData theme, Locale locale) {
    final list = widget.guide.getSunnahActs(locale);
    return CollapsibleSection(
      title: context.tr(bn: 'সুন্নাতসমূহ', en: 'Sunnah Acts'),
      icon: Icons.star,
      color: Colors.green.shade700,
      initiallyExpanded: false,
      children: list.asMap().entries.map((entry) {
        return WorshipListItem(text: entry.value, number: entry.key + 1);
      }).toList(),
    );
  }

  Widget _buildStepsSection(ThemeData theme, Locale locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorshipSectionHeader(
          title: context.tr(bn: 'ধাপে ধাপে নিয়ম', en: 'Step by Step'),
          icon: Icons.format_list_numbered,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 8),
        ...widget.guide.steps.map((step) => WorshipStepCard(step: step)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildInvalidatorsSection(ThemeData theme, Locale locale) {
    final list = widget.guide.getInvalidators(locale);
    return CollapsibleSection(
      title: context.tr(bn: 'যা ভঙ্গ করে', en: 'Invalidators'),
      icon: Icons.cancel,
      color: Colors.orange.shade700,
      initiallyExpanded: false,
      children: list.map((item) {
        return WorshipListItem(
          text: item,
          icon: Icons.cancel_outlined,
          iconColor: Colors.orange.shade600,
        );
      }).toList(),
    );
  }

  Widget _buildCommonMistakesSection(ThemeData theme, Locale locale) {
    final list = widget.guide.getCommonMistakes(locale);
    return CollapsibleSection(
      title: context.tr(bn: 'সাধারণ ভুলসমূহ', en: 'Common Mistakes'),
      icon: Icons.warning_amber,
      color: Colors.amber.shade700,
      initiallyExpanded: false,
      children: list.map((item) {
        return WorshipListItem(
          text: item,
          icon: Icons.error_outline,
          iconColor: Colors.amber.shade600,
        );
      }).toList(),
    );
  }

  Widget _buildSpecialRulingsSection(ThemeData theme, Locale locale) {
    final list = widget.guide.getSpecialRulings(locale);
    return CollapsibleSection(
      title: context.tr(bn: 'বিশেষ মাসআলা', en: 'Special Rulings'),
      icon: Icons.lightbulb,
      color: Colors.purple.shade700,
      initiallyExpanded: false,
      children: list.map((item) {
        return WorshipListItem(
          text: item,
          icon: Icons.info_outline,
          iconColor: Colors.purple.shade600,
        );
      }).toList(),
    );
  }

  Widget _buildReferencesSection(ThemeData theme) {
    final allReferences = <Reference>[];
    for (final step in widget.guide.steps) {
      allReferences.addAll(step.references);
    }
    allReferences.addAll(widget.guide.references);
    if (allReferences.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        ReferenceSection(
          references: allReferences,
          title: context.tr(bn: 'সকল সূত্র', en: 'All References'),
        ),
      ],
    );
  }
}
