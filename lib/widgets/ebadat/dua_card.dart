import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/dua_model.dart';
import '../../services/bookmark_service.dart';

class DuaCard extends StatefulWidget {
  final DuaModel dua;
  final VoidCallback? onTap;

  const DuaCard({
    super.key,
    required this.dua,
    this.onTap,
  });

  @override
  State<DuaCard> createState() => _DuaCardState();
}

class _DuaCardState extends State<DuaCard> {
  final BookmarkService _bookmarkService = BookmarkService();

  @override
  Widget build(BuildContext context) {
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
              // Header: Title and Category
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.pan_tool,
                          color: Color(0xFF6A1B9A),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.dua.titleBangla,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6A1B9A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Bookmark Button
                  IconButton(
                    icon: Icon(
                      _bookmarkService.isBookmarked('dua', widget.dua.id)
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color: _bookmarkService.isBookmarked('dua', widget.dua.id)
                          ? const Color(0xFF6A1B9A)
                          : Colors.grey,
                    ),
                    onPressed: () async {
                      if (!_bookmarkService.canBookmark) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('বুকমার্ক করতে লগইন করুন'),
                            action: SnackBarAction(
                              label: 'লগইন',
                              onPressed: () {
                                // Navigate to profile tab (index 2)
                                // This will be implemented when integrating with main navigation
                              },
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
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isNowBookmarked
                                  ? 'বুকমার্কে যোগ করা হয়েছে'
                                  : 'বুকমার্ক থেকে সরানো হয়েছে',
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
                  // Category Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF6A1B9A).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      widget.dua.category,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6A1B9A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Divider
              Divider(color: Colors.grey[300], thickness: 1),
              const SizedBox(height: 12),

              // Arabic Text
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
                  widget.dua.arabicText,
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

              // Transliteration
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  widget.dua.banglaTransliteration,
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

              // Bangla Meaning
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF6A1B9A).withValues(alpha: 0.15)
                      : const Color(0xFF6A1B9A).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.dua.banglaMeaning,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Reference (Hadith Source)
              Row(
                children: [
                  Icon(
                    Icons.library_books,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.dua.reference,
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
