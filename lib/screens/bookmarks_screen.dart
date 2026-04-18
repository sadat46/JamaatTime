import 'package:flutter/material.dart';
import '../core/locale_text.dart';
import '../services/bookmark_service.dart';
import '../services/ebadat_data_service.dart';
import '../models/ayat_model.dart';
import '../models/dua_model.dart';
import '../widgets/ebadat/loading_card.dart';
import 'ebadat/ayat_detail_screen.dart';
import 'ebadat/dua_detail_screen.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final BookmarkService _bookmarkService = BookmarkService();
  final EbadatDataService _ebadatService = EbadatDataService();

  bool _isLoading = true;
  String? _errorMessage;

  List<AyatModel> _bookmarkedAyats = [];
  List<DuaModel> _bookmarkedDuas = [];

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (!_bookmarkService.canBookmark) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final ayatIds = _bookmarkService.getBookmarkIds('ayat');
      final duaIds = _bookmarkService.getBookmarkIds('dua');

      final allAyats = await _ebadatService.loadAyats();
      final allDuas = await _ebadatService.loadDuas();

      _bookmarkedAyats =
          allAyats.where((ayat) => ayatIds.contains(ayat.id)).toList();
      _bookmarkedDuas =
          allDuas.where((dua) => duaIds.contains(dua.id)).toList();

      setState(() {
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'failed';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(bn: 'আমার বুকমার্ক', en: 'My Bookmarks'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF388E3C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 8,
        itemBuilder: (context, index) => const SimpleLoadingCard(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              context.tr(
                bn: 'বুকমার্ক লোড করতে ব্যর্থ হয়েছে',
                en: 'Failed to load bookmarks',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadBookmarks,
              icon: const Icon(Icons.refresh),
              label: Text(context.tr(bn: 'পুনরায় চেষ্টা করুন', en: 'Try Again')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF388E3C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!_bookmarkService.canBookmark) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.login,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              context.tr(
                bn: 'বুকমার্ক দেখতে লগইন করুন',
                en: 'Sign in to view bookmarks',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                bn: 'আপনার সংরক্ষিত আয়াত ও দোয়া দেখতে লগইন প্রয়োজন',
                en: 'Sign in to access your saved ayat and dua',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (_bookmarkedAyats.isEmpty && _bookmarkedDuas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              context.tr(bn: 'কোনো বুকমার্ক নেই', en: 'No bookmarks yet'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                bn: 'আয়াত বা দোয়া বুকমার্ক করুন',
                en: 'Bookmark ayat or dua to see them here',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookmarks,
      color: const Color(0xFF388E3C),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_bookmarkedAyats.isNotEmpty) ...[
              _buildSectionHeader(
                context.tr(bn: 'আয়াত', en: 'Ayat'),
                _bookmarkedAyats.length,
                Icons.menu_book,
                const Color(0xFF1565C0),
              ),
              const SizedBox(height: 12),
              ..._bookmarkedAyats.map((ayat) => _buildAyatCard(ayat)),
              const SizedBox(height: 24),
            ],
            if (_bookmarkedDuas.isNotEmpty) ...[
              _buildSectionHeader(
                context.tr(bn: 'দোয়া', en: 'Dua'),
                _bookmarkedDuas.length,
                Icons.pan_tool,
                const Color(0xFF6A1B9A),
              ),
              const SizedBox(height: 12),
              ..._bookmarkedDuas.map((dua) => _buildDuaCard(dua)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, IconData icon, Color color) {
    return Row(
      children: [
        Icon(
          icon,
          size: 24,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAyatCard(AyatModel ayat) {
    final locale = Localizations.localeOf(context);
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: const Color(0xFF1565C0).withValues(alpha: 0.2),
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AyatDetailScreen(ayat: ayat),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.menu_book,
                  color: Color(0xFF1565C0),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ayat.getTitle(locale),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ayat.getSurahName(locale)} (${ayat.ayatNumber})',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDuaCard(DuaModel dua) {
    final locale = Localizations.localeOf(context);
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: const Color(0xFF6A1B9A).withValues(alpha: 0.2),
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DuaDetailScreen(dua: dua),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.pan_tool,
                  color: Color(0xFF6A1B9A),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dua.getTitle(locale),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6A1B9A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dua.getCategory(locale),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
