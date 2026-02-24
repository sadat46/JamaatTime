import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../data/monajat_data.dart';
import '../../../models/monajat_model.dart';

/// Screen displaying the list of Islamic Supplications (Monajat) with accordion expansion
///
/// This screen provides a visually comfortable reading experience with
/// expandable cards that show full details inline without navigation.
class MonajatListScreen extends StatefulWidget {
  const MonajatListScreen({super.key});

  @override
  State<MonajatListScreen> createState() => _MonajatListScreenState();
}

class _MonajatListScreenState extends State<MonajatListScreen> {
  int? _expandedIndex; // Track which card is currently expanded

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'মোনাজাত',
          style: TextStyle(fontWeight: FontWeight.bold),
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
          return _buildExpandableMonajatCard(context, monajat, index, isExpanded);
        },
      ),
    );
  }

  /// Builds an expandable card for each Monajat item
  Widget _buildExpandableMonajatCard(
    BuildContext context,
    MonajatModel monajat,
    int index,
    bool isExpanded,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: isExpanded ? 4 : 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header (always visible)
          InkWell(
            onTap: () {
              setState(() {
                // Toggle expansion: if already expanded, collapse it; otherwise expand it
                _expandedIndex = isExpanded ? null : index;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Leading index number container
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
                  // Title and preview
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          monajat.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        if (!isExpanded) ...[
                          const SizedBox(height: 4),
                          Text(
                            monajat.meaning,
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
                  // Animated arrow icon
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0, // 0.5 turns = 180 degrees (arrow up when expanded)
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 28,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded content (conditionally visible)
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedContent(context, monajat, isDark),
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

  /// Builds the expanded content section with full Monajat details
  Widget _buildExpandedContent(
    BuildContext context,
    MonajatModel monajat,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Divider
          Divider(
            thickness: 1,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),

          // Arabic Text Section
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

          // Pronunciation Section
          _buildSectionHeader('উচ্চারণ', Icons.record_voice_over, isDark),
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

          // Meaning Section
          _buildSectionHeader('অর্থ', Icons.translate, isDark),
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
              monajat.meaning,
              style: TextStyle(
                fontSize: 16,
                height: 1.8,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Context Section
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
                      'প্রসঙ্গ ও ফযিলত',
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
                  monajat.context,
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

          // Copy Button
          OutlinedButton.icon(
            onPressed: () => _copyToClipboard(context, monajat),
            icon: const Icon(Icons.copy_all, size: 18),
            label: const Text(
              'কপি করুন',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
    );
  }

  /// Builds section headers
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

  /// Copies the complete Monajat text to clipboard
  void _copyToClipboard(BuildContext context, MonajatModel monajat) async {
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
                Text('ক্লিপবোর্ডে কপি হয়েছে'),
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
