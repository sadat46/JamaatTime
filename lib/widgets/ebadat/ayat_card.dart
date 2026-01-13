import 'package:flutter/material.dart';
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
                    child: Text(
                      widget.ayat.titleBangla,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF388E3C),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Bookmark Button
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
                        'ayat',
                        widget.ayat.id,
                        title: widget.ayat.titleBangla,
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
                      color: const Color(0xFF388E3C).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF388E3C).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      widget.ayat.category,
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

              // Surah Info
              Row(
                children: [
                  // Surah Name (Arabic)
                  Text(
                    widget.ayat.surahNameArabic,
                    style: TextStyle(
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
                  // Surah Name (Bangla)
                  Text(
                    widget.ayat.surahName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Ayat Number
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

              // Divider
              Divider(color: Colors.grey[300], thickness: 1),
              const SizedBox(height: 12),

              // Arabic Text
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.ayat.arabicText,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    height: 1.8,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Transliteration
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  widget.ayat.banglaTransliteration,
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[700],
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
                  color: const Color(0xFF388E3C).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.ayat.banglaMeaning,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Reference
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
