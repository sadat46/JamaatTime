import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/locale_text.dart';
import '../../../data/monajat_data.dart';
import '../../../models/monajat_model.dart';

class MonajatListScreen extends StatefulWidget {
  const MonajatListScreen({super.key});

  @override
  State<MonajatListScreen> createState() => _MonajatListScreenState();
}

class _MonajatListScreenState extends State<MonajatListScreen> {
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(bn: 'মোনাজাত', en: 'Monajat'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 2,
      ),
      body: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: allMonajatList.length,
        itemBuilder: (context, index) {
          final monajat = allMonajatList[index];
          final isExpanded = _expandedIndex == index;
          return _buildExpandableMonajatCard(
            context,
            monajat,
            index,
            isExpanded,
            locale,
          );
        },
      ),
    );
  }

  Widget _buildExpandableMonajatCard(
    BuildContext context,
    MonajatModel monajat,
    int index,
    bool isExpanded,
    Locale locale,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = monajat.getTitle(locale);
    final meaning = monajat.getMeaning(locale);
    final contextText = monajat.getContext(locale);

    return Card(
      elevation: isExpanded ? 4 : 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedIndex = isExpanded ? null : index;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        if (!isExpanded) ...[
                          const SizedBox(height: 4),
                          Text(
                            meaning,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 28,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Divider(
                    thickness: 1,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                    decoration: BoxDecoration(
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
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.teal.withValues(alpha: 0.4)
                            : Colors.teal.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      monajat.arabic,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: GoogleFonts.amiri(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        height: 2.0,
                        color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF004D40),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionHeader(
                    context.tr(bn: 'উচ্চারণ', en: 'Transliteration'),
                    Icons.record_voice_over,
                    isDark,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.teal.withValues(alpha: 0.15)
                          : Colors.teal.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.teal.withValues(alpha: 0.3)
                            : Colors.teal.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Text(
                      monajat.pronunciation,
                      style: TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        height: 1.7,
                        color: isDark ? Colors.grey[300] : Colors.grey[800],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionHeader(
                    context.tr(bn: 'অর্থ', en: 'Meaning'),
                    Icons.translate,
                    isDark,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.teal.withValues(alpha: 0.18)
                          : Colors.teal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.teal.withValues(alpha: 0.35)
                            : Colors.teal.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      meaning,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.8,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: isDark ? Colors.amber[300] : Colors.amber[800],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              context.tr(
                                bn: 'প্রসঙ্গ ও ফযিলত',
                                en: 'Context & Virtue',
                              ),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.amber[300] : Colors.amber[900],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          contextText,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.7,
                            color: isDark ? Colors.grey[300] : Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _copyToClipboard(context, monajat, locale),
                    icon: const Icon(Icons.copy_all, size: 18),
                    label: Text(
                      context.tr(bn: 'কপি করুন', en: 'Copy'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal,
                      side: const BorderSide(color: Colors.teal, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark ? Colors.teal[200] : Colors.teal[700],
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.teal[200] : Colors.teal[800],
          ),
        ),
      ],
    );
  }

  void _copyToClipboard(
    BuildContext context,
    MonajatModel monajat,
    Locale locale,
  ) async {
    try {
      final copyText = '''
${monajat.getTitle(locale)}

${monajat.arabic}

${context.tr(bn: 'উচ্চারণ', en: 'Transliteration')}: ${monajat.pronunciation}

${context.tr(bn: 'অর্থ', en: 'Meaning')}: ${monajat.getMeaning(locale)}

${context.tr(bn: 'প্রসঙ্গ', en: 'Context')}: ${monajat.getContext(locale)}
''';

      await Clipboard.setData(ClipboardData(text: copyText));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(context.tr(bn: 'ক্লিপবোর্ডে কপি হয়েছে', en: 'Copied to clipboard')),
              ],
            ),
            backgroundColor: Colors.teal,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr(bn: 'কপি করতে সমস্যা হয়েছে', en: 'Failed to copy')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
