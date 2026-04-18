import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/locale_text.dart';
import '../../models/dua_model.dart';
import '../../services/bookmark_service.dart';

class DuaDetailScreen extends StatefulWidget {
  final DuaModel dua;

  const DuaDetailScreen({
    super.key,
    required this.dua,
  });

  @override
  State<DuaDetailScreen> createState() => _DuaDetailScreenState();
}

class _DuaDetailScreenState extends State<DuaDetailScreen> {
  final BookmarkService _bookmarkService = BookmarkService();

  void _toggleBookmark() async {
    if (!_bookmarkService.canBookmark) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              bn: 'বুকমার্ক করতে লগইন করুন',
              en: 'Sign in to bookmark',
            ),
          ),
          action: SnackBarAction(
            label: context.tr(bn: 'লগইন', en: 'Sign In'),
            onPressed: () {},
          ),
        ),
      );
      return;
    }

    final isNowBookmarked = await _bookmarkService.toggleBookmark(
      'dua',
      widget.dua.id,
      title: widget.dua.titleBangla,
    );
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNowBookmarked
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
  }

  void _shareDua() async {
    final locale = Localizations.localeOf(context);
    try {
      final shareText = '''
${widget.dua.getTitle(locale)}

${widget.dua.arabicText}

${context.tr(bn: 'উচ্চারণ', en: 'Transliteration')}: ${widget.dua.getTransliteration(locale)}

${context.tr(bn: 'অর্থ', en: 'Meaning')}: ${widget.dua.getMeaning(locale)}

${context.tr(bn: 'সূত্র', en: 'Reference')}: ${widget.dua.reference}
''';

      await Share.share(
        shareText,
        subject: widget.dua.getTitle(locale),
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

  void _copyToClipboard() async {
    final locale = Localizations.localeOf(context);
    try {
      final copyText = '''
${widget.dua.arabicText}

${widget.dua.getMeaning(locale)}
''';

      await Clipboard.setData(ClipboardData(text: copyText));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                bn: 'ক্লিপবোর্ডে কপি হয়েছে',
                en: 'Copied to clipboard',
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

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final title = widget.dua.getTitle(locale);
    final category = widget.dua.getCategory(locale);
    final transliteration = widget.dua.getTransliteration(locale);
    final meaning = widget.dua.getMeaning(locale);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF4A148C)
            : const Color(0xFF6A1B9A),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _bookmarkService.isBookmarked('dua', widget.dua.id)
                  ? Icons.bookmark
                  : Icons.bookmark_border,
            ),
            onPressed: _toggleBookmark,
            tooltip: context.tr(bn: 'বুকমার্ক', en: 'Bookmark'),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareDua,
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
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF6A1B9A).withValues(alpha: 0.2)
                            : const Color(0xFF6A1B9A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF9C4DCC).withValues(alpha: 0.5)
                              : const Color(0xFF6A1B9A).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFCE93D8)
                              : const Color(0xFF6A1B9A),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[850]
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF9C4DCC).withValues(alpha: 0.3)
                            : const Color(0xFF4A148C).withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      widget.dua.arabicText,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: GoogleFonts.amiri(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        height: 2.0,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFCE93D8)
                            : const Color(0xFF4A148C),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.menu_book,
                        size: 18,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFCE93D8)
                            : const Color(0xFF6A1B9A),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.dua.reference,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFCE93D8)
                                : const Color(0xFF6A1B9A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(thickness: 1.5),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    context.tr(bn: 'উচ্চারণ', en: 'Transliteration'),
                    Icons.record_voice_over,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF6A1B9A).withValues(alpha: 0.15)
                          : const Color(0xFF6A1B9A).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      transliteration,
                      style: TextStyle(
                        fontSize: 19,
                        fontStyle: FontStyle.italic,
                        height: 1.7,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[300]
                            : Colors.grey[800],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(thickness: 1.5),
                  const SizedBox(height: 24),
                  _buildSectionHeader(context.tr(bn: 'অর্থ', en: 'Meaning'), Icons.translate),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF6A1B9A).withValues(alpha: 0.2)
                          : const Color(0xFF6A1B9A).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF9C4DCC).withValues(alpha: 0.4)
                            : const Color(0xFF6A1B9A).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      meaning,
                      style: TextStyle(
                        fontSize: 19,
                        height: 1.8,
                        color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(thickness: 1.5),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(
                        Icons.library_books,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.dua.reference,
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _copyToClipboard,
                          icon: const Icon(Icons.copy),
                          label: Text(context.tr(bn: 'কপি', en: 'Copy')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6A1B9A),
                            side: const BorderSide(
                              color: Color(0xFF6A1B9A),
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _shareDua,
                          icon: const Icon(Icons.share),
                          label: Text(context.tr(bn: 'শেয়ার', en: 'Share')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF4A148C)
                                : const Color(0xFF6A1B9A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFCE93D8)
              : const Color(0xFF6A1B9A),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFCE93D8)
                : const Color(0xFF6A1B9A),
          ),
        ),
      ],
    );
  }
}
