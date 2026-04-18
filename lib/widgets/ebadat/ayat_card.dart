import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/locale_text.dart';
import '../../models/ayat_model.dart';
import '../../services/bookmark_service.dart';

class AyatCard extends StatefulWidget {
  final AyatModel ayat;
  final VoidCallback? onTap;

  const AyatCard({
    super.key,
    required this.ayat,
    this.onTap,
  });

  @override
  State<AyatCard> createState() => _AyatCardState();
}

class _AyatCardState extends State<AyatCard> {
  final BookmarkService _bookmarkService = BookmarkService();

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final title = widget.ayat.getTitle(locale);
    final category = widget.ayat.getCategory(locale);
    final surah = widget.ayat.getSurahName(locale);
    final transliteration = widget.ayat.getTransliteration(locale);
    final meaning = widget.ayat.getMeaning(locale);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF388E3C),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _bookmarkService.isBookmarked('ayat', widget.ayat.id)
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color: _bookmarkService.isBookmarked('ayat', widget.ayat.id)
                          ? const Color(0xFF388E3C)
                          : Colors.grey,
                    ),
                    onPressed: () async {
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
                        'ayat',
                        widget.ayat.id,
                        title: widget.ayat.titleBangla,
                      );
                      setState(() {});

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isNowBookmarked
                                  ? context.tr(
                                      bn: 'বুকমার্কে যোগ করা হয়েছে',
                                      en: 'Added to bookmarks',
                                    )
                                  : context.tr(
                                      bn: 'বুকমার্ক থেকে সরানো হয়েছে',
                                      en: 'Removed from bookmarks',
                                    ),
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF388E3C).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF388E3C).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF388E3C),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    widget.ayat.surahNameArabic,
                    style: GoogleFonts.amiri(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '•',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    surah,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${widget.ayat.ayatNumber})',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: Colors.grey[300], thickness: 1),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.ayat.arabicText,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.amiri(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    height: 1.8,
                    color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  transliteration,
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[700],
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF388E3C).withValues(alpha: 0.15)
                      : const Color(0xFF388E3C).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  meaning,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.menu_book,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.ayat.reference,
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
