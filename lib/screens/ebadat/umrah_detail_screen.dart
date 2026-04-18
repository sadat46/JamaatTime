import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/locale_text.dart';
import '../../models/umrah_model.dart';

class UmrahDetailScreen extends StatefulWidget {
  final UmrahSectionModel section;

  const UmrahDetailScreen({
    super.key,
    required this.section,
  });

  @override
  State<UmrahDetailScreen> createState() => _UmrahDetailScreenState();
}

class _UmrahDetailScreenState extends State<UmrahDetailScreen> {
  bool _isBookmarked = false;

  void _toggleBookmark() {
    setState(() {
      _isBookmarked = !_isBookmarked;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isBookmarked
              ? context.tr(bn: 'বুকমার্কে যুক্ত হয়েছে', en: 'Added to bookmarks')
              : context.tr(
                  bn: 'বুকমার্ক থেকে সরানো হয়েছে',
                  en: 'Removed from bookmarks',
                ),
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareSection() async {
    final locale = Localizations.localeOf(context);
    final rules = widget.section.getRules(locale);
    try {
      final duasText = widget.section.relatedDuas
          .map((dua) => '''
${dua.getTitle(locale)}
${dua.arabicText}
${context.tr(bn: 'উচ্চারণ', en: 'Transliteration')}: ${dua.getTransliteration(locale)}
${context.tr(bn: 'অর্থ', en: 'Meaning')}: ${dua.getMeaning(locale)}
''')
          .join('\n---------------------\n\n');

      final shareText = '''
${widget.section.getTitle(locale)}
${widget.section.titleArabic}

${context.tr(bn: 'বিবরণ', en: 'Description')}:
${widget.section.getDescription(locale)}

${rules.isNotEmpty ? '${context.tr(bn: 'নিয়মাবলী', en: 'Rules')}:\n${rules.map((rule) => '• $rule').join('\n')}\n\n' : ''}${widget.section.relatedDuas.isNotEmpty ? '${context.tr(bn: 'সংশ্লিষ্ট দোয়াসমূহ', en: 'Related Duas')}:\n$duasText' : ''}
''';

      await Share.share(
        shareText,
        subject: widget.section.getTitle(locale),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                bn: 'শেয়ার করতে সমস্যা হয়েছে',
                en: 'Failed to share',
              ),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final title = widget.section.getTitle(locale);
    final description = widget.section.getDescription(locale);
    final rules = widget.section.getRules(locale);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFE65100),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            ),
            onPressed: _toggleBookmark,
            tooltip: context.tr(bn: 'বুকমার্ক', en: 'Bookmark'),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareSection,
            tooltip: context.tr(bn: 'শেয়ার', en: 'Share'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFBF360C).withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      widget.section.titleArabic,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        height: 2.0,
                        color: Color(0xFFBF360C),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(thickness: 1.5),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    context.tr(bn: 'বিবরণ', en: 'Description'),
                    Icons.description,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE65100).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE65100).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      description,
                      style: const TextStyle(
                        fontSize: 19,
                        height: 1.8,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  if (rules.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Divider(thickness: 1.5),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      context.tr(bn: 'নিয়মাবলী', en: 'Rules'),
                      Icons.checklist,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE65100).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: rules.map((rule) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '• ',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFE65100),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    rule,
                                    style: const TextStyle(
                                      fontSize: 19,
                                      height: 1.7,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  if (widget.section.relatedDuas.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Divider(thickness: 1.5),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      context.tr(bn: 'সংশ্লিষ্ট দোয়াসমূহ', en: 'Related Duas'),
                      Icons.auto_stories,
                    ),
                    const SizedBox(height: 16),
                    ...widget.section.relatedDuas.map((dua) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildDuaCard(dua),
                      );
                    }),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFFE65100),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFE65100),
          ),
        ),
      ],
    );
  }

  Widget _buildDuaCard(UmrahDuaModel dua) {
    final locale = Localizations.localeOf(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: const Color(0xFFE65100).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          _showDuaDetails(dua);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.label,
                    size: 18,
                    color: Color(0xFFE65100),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dua.getTitle(locale),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.copy,
                      size: 18,
                      color: Color(0xFFE65100),
                    ),
                    onPressed: () => _copyDuaToClipboard(dua),
                    tooltip: context.tr(bn: 'কপি', en: 'Copy'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  dua.arabicText,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    height: 1.8,
                    color: Color(0xFFBF360C),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE65100).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  dua.getTransliteration(locale),
                  style: TextStyle(
                    fontSize: 17,
                    fontStyle: FontStyle.italic,
                    height: 1.6,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE65100).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFE65100).withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  dua.getMeaning(locale),
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.7,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDuaDetails(UmrahDuaModel dua) {
    final locale = Localizations.localeOf(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          dua.getTitle(locale),
          style: const TextStyle(
            color: Color(0xFFE65100),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  dua.arabicText,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    height: 1.8,
                    color: Color(0xFFBF360C),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${context.tr(bn: 'উচ্চারণ', en: 'Transliteration')}:',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE65100),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                dua.getTransliteration(locale),
                style: const TextStyle(
                  fontSize: 17,
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${context.tr(bn: 'অর্থ', en: 'Meaning')}:',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE65100),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                dua.getMeaning(locale),
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.7,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              context.tr(bn: 'বন্ধ করুন', en: 'Close'),
              style: const TextStyle(color: Color(0xFFE65100)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              _copyDuaToClipboard(dua);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.copy),
            label: Text(context.tr(bn: 'কপি', en: 'Copy')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _copyDuaToClipboard(UmrahDuaModel dua) async {
    final locale = Localizations.localeOf(context);
    try {
      final copyText = '''
${dua.getTitle(locale)}

${dua.arabicText}

${context.tr(bn: 'উচ্চারণ', en: 'Transliteration')}: ${dua.getTransliteration(locale)}

${context.tr(bn: 'অর্থ', en: 'Meaning')}: ${dua.getMeaning(locale)}
''';

      await Clipboard.setData(ClipboardData(text: copyText));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                bn: 'দোয়া ক্লিপবোর্ডে কপি হয়েছে',
                en: 'Dua copied to clipboard',
              ),
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                bn: 'কপি করতে সমস্যা হয়েছে',
                en: 'Failed to copy',
              ),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
