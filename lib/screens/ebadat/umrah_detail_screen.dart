import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
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
          _isBookmarked ? 'বুকমার্কে যুক্ত হয়েছে' : 'বুকমার্ক থেকে সরানো হয়েছে',
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareSection() async {
    try {
      final duasText = widget.section.relatedDuas
          .map((dua) => '''
${dua.titleBangla}
${dua.arabicText}
উচ্চারণ: ${dua.banglaTransliteration}
অর্থ: ${dua.banglaMeaning}
''')
          .join('\n━━━━━━━━━━━━━━━━━━━━━\n\n');

      final shareText = '''
${widget.section.titleBangla}
${widget.section.titleArabic}

বিবরণ:
${widget.section.description}

${widget.section.rules.isNotEmpty ? 'নিয়মাবলী:\n${widget.section.rules.map((rule) => '• $rule').join('\n')}\n\n' : ''}${widget.section.relatedDuas.isNotEmpty ? 'সংশ্লিষ্ট দোয়াসমূহ:\n$duasText' : ''}
''';

      await Share.share(
        shareText,
        subject: widget.section.titleBangla,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.section.titleBangla,
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
            tooltip: 'বুকমার্ক',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareSection,
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
                  // Arabic Title
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

                  // Divider
                  const Divider(thickness: 1.5),
                  const SizedBox(height: 24),

                  // Description Section
                  _buildSectionHeader('বিবরণ', Icons.description),
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
                      widget.section.description,
                      style: const TextStyle(
                        fontSize: 19,
                        height: 1.8,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  // Rules Section (if available)
                  if (widget.section.rules.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Divider(thickness: 1.5),
                    const SizedBox(height: 24),
                    _buildSectionHeader('নিয়মাবলী', Icons.checklist),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE65100).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.section.rules.map((rule) {
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

                  // Related Duas Section
                  if (widget.section.relatedDuas.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Divider(thickness: 1.5),
                    const SizedBox(height: 24),
                    _buildSectionHeader('সংশ্লিষ্ট দোয়াসমূহ', Icons.auto_stories),
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
              // Dua Title
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
                      dua.titleBangla,
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
                    tooltip: 'কপি',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Arabic Text
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

              // Transliteration
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE65100).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  dua.banglaTransliteration,
                  style: TextStyle(
                    fontSize: 17,
                    fontStyle: FontStyle.italic,
                    height: 1.6,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Meaning
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
                  dua.banglaMeaning,
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          dua.titleBangla,
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
              // Arabic Text
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
              const Text(
                'উচ্চারণ:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE65100),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                dua.banglaTransliteration,
                style: const TextStyle(
                  fontSize: 17,
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'অর্থ:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE65100),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                dua.banglaMeaning,
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
            child: const Text(
              'বন্ধ করুন',
              style: TextStyle(color: Color(0xFFE65100)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              _copyDuaToClipboard(dua);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.copy),
            label: const Text('কপি'),
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
    try {
      final copyText = '''
${dua.titleBangla}

${dua.arabicText}

উচ্চারণ: ${dua.banglaTransliteration}

অর্থ: ${dua.banglaMeaning}
''';

      await Clipboard.setData(ClipboardData(text: copyText));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('দোয়া ক্লিপবোর্ডে কপি হয়েছে'),
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
}
