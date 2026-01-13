import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNowBookmarked
                ? 'বুকমার্কে যুক্ত হয়েছে'
                : 'বুকমার্ক থেকে সরানো হয়েছে',
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _shareDua() async {
    try {
      final shareText = '''
${widget.dua.titleBangla}

${widget.dua.arabicText}

উচ্চারণ: ${widget.dua.banglaTransliteration}

অর্থ: ${widget.dua.banglaMeaning}

সূত্র: ${widget.dua.reference}
''';

      await Share.share(
        shareText,
        subject: widget.dua.titleBangla,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('শেয়ার করতে সমস্যা হয়েছে'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _copyToClipboard() async {
    try {
      final copyText = '''
${widget.dua.arabicText}

${widget.dua.banglaMeaning}
''';

      await Clipboard.setData(ClipboardData(text: copyText));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ক্লিপবোর্ডে কপি হয়েছে'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.dua.titleBangla,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF6A1B9A),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _bookmarkService.isBookmarked('dua', widget.dua.id)
                  ? Icons.bookmark
                  : Icons.bookmark_border,
            ),
            onPressed: _toggleBookmark,
            tooltip: 'বুকমার্ক',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareDua,
            tooltip: 'শেয়ার',
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
                  // Category Badge
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF6A1B9A).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        widget.dua.category,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6A1B9A),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Arabic Text
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF4A148C).withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      widget.dua.arabicText,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        height: 2.0,
                        color: Color(0xFF4A148C),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Reference (Hadith) Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.menu_book,
                        size: 18,
                        color: Color(0xFF6A1B9A),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.dua.reference,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6A1B9A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Divider
                  const Divider(thickness: 1.5),
                  const SizedBox(height: 24),

                  // Transliteration Section
                  _buildSectionHeader('বাংলা উচ্চারণ', Icons.record_voice_over),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6A1B9A).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.dua.banglaTransliteration,
                      style: TextStyle(
                        fontSize: 19,
                        fontStyle: FontStyle.italic,
                        height: 1.7,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Divider
                  const Divider(thickness: 1.5),
                  const SizedBox(height: 24),

                  // Meaning Section
                  _buildSectionHeader('বাংলা অর্থ', Icons.translate),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6A1B9A).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF6A1B9A).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      widget.dua.banglaMeaning,
                      style: const TextStyle(
                        fontSize: 19,
                        height: 1.8,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Divider
                  const Divider(thickness: 1.5),
                  const SizedBox(height: 24),

                  // Reference Section
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

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _copyToClipboard,
                          icon: const Icon(Icons.copy),
                          label: const Text('কপি'),
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
                          label: const Text('শেয়ার'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A1B9A),
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
          color: const Color(0xFF6A1B9A),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6A1B9A),
          ),
        ),
      ],
    );
  }
}
