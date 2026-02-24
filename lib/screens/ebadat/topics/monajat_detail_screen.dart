import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/monajat_model.dart';

/// Detail screen displaying a single Monajat with exceptional visual comfort
///
/// This screen is optimized for reading and prayer with:
/// - Large, centered Arabic text in a distinct container
/// - Clear typography hierarchy with generous spacing
/// - Soft color palette (Teal theme) for reduced eye strain
/// - Context section styled differently to aid comprehension
class MonajatDetailScreen extends StatelessWidget {
  final MonajatModel monajat;

  const MonajatDetailScreen({
    super.key,
    required this.monajat,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          monajat.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF00695C) : Colors.teal,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all),
            onPressed: () => _copyToClipboard(context),
            tooltip: 'কপি করুন',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title Badge
                  _buildTitleBadge(context),
                  const SizedBox(height: 32),

                  // Arabic Text - The Star of the Show
                  _buildArabicTextSection(context),
                  const SizedBox(height: 28),

                  // Pronunciation Section
                  _buildSectionHeader(
                    context,
                    'উচ্চারণ',
                    Icons.record_voice_over,
                  ),
                  const SizedBox(height: 12),
                  _buildPronunciationSection(context),
                  const SizedBox(height: 28),

                  // Meaning Section
                  _buildSectionHeader(
                    context,
                    'অর্থ',
                    Icons.translate,
                  ),
                  const SizedBox(height: 12),
                  _buildMeaningSection(context),
                  const SizedBox(height: 28),

                  // Context/Fadilat Section
                  _buildContextSection(context),
                  const SizedBox(height: 32),

                  // Copy Button
                  _buildCopyButton(context),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the title badge at the top
  Widget _buildTitleBadge(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.teal.withValues(alpha: 0.2)
            : Colors.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.teal.withValues(alpha: 0.5)
              : Colors.teal.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Text(
        monajat.title,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.teal[200] : Colors.teal[800],
          height: 1.5,
        ),
      ),
    );
  }

  /// Builds the Arabic text section with maximum visual prominence
  Widget _buildArabicTextSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        // Soft teal/green background for respectful presentation
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF004D40).withValues(alpha: 0.3),
                  const Color(0xFF00695C).withValues(alpha: 0.2),
                ]
              : [
                  const Color(0xFFE0F2F1),
                  const Color(0xFFB2DFDB),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.teal.withValues(alpha: 0.4)
              : Colors.teal.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        monajat.arabic,
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: GoogleFonts.amiri(
          fontSize: 32, // Large font for readability
          fontWeight: FontWeight.w600,
          height: 2.2, // Generous line spacing
          color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF004D40),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Builds the pronunciation section
  Widget _buildPronunciationSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.teal.withValues(alpha: 0.15)
            : Colors.teal.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.teal.withValues(alpha: 0.3)
              : Colors.teal.withValues(alpha: 0.15),
        ),
      ),
      child: Text(
        monajat.pronunciation,
        style: TextStyle(
          fontSize: 18,
          fontStyle: FontStyle.italic,
          height: 1.8,
          color: isDark ? Colors.grey[300] : Colors.grey[800],
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  /// Builds the meaning section
  Widget _buildMeaningSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.teal.withValues(alpha: 0.18)
            : Colors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.teal.withValues(alpha: 0.35)
              : Colors.teal.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Text(
        monajat.meaning,
        style: TextStyle(
          fontSize: 18,
          height: 1.9,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  /// Builds the context/fadilat section with distinct styling
  Widget _buildContextSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.grey[700]!
              : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: isDark ? Colors.amber[300] : Colors.amber[800],
              ),
              const SizedBox(width: 10),
              Text(
                'প্রসঙ্গ ও ফযিলত',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.amber[300] : Colors.amber[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            monajat.context,
            style: TextStyle(
              fontSize: 16,
              height: 1.8,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds section headers with icons
  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Icon(
          icon,
          size: 22,
          color: isDark ? Colors.teal[200] : Colors.teal[700],
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.teal[200] : Colors.teal[800],
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  /// Builds the copy button
  Widget _buildCopyButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ElevatedButton.icon(
      onPressed: () => _copyToClipboard(context),
      icon: const Icon(Icons.copy_all, size: 20),
      label: const Text(
        'সম্পূর্ণ দোয়া কপি করুন',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? const Color(0xFF00695C) : Colors.teal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 2,
      ),
    );
  }

  /// Copies the complete Monajat text to clipboard
  void _copyToClipboard(BuildContext context) async {
    try {
      final copyText = '''
${monajat.title}

${monajat.arabic}

উচ্চারণ: ${monajat.pronunciation}

অর্থ: ${monajat.meaning}

প্রসঙ্গ: ${monajat.context}
''';

      await Clipboard.setData(ClipboardData(text: copyText));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'ক্লিপবোর্ডে কপি হয়েছে',
                  style: TextStyle(fontSize: 15),
                ),
              ],
            ),
            backgroundColor: Colors.teal,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('কপি করতে সমস্যা হয়েছে'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
