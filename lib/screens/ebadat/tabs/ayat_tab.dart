import 'package:flutter/material.dart';
import '../../../models/ayat_model.dart';
import '../../../services/ebadat_data_service.dart';
import '../../../widgets/ebadat/ayat_card.dart';
import '../../../widgets/ebadat/loading_card.dart';
import '../ayat_detail_screen.dart';

class AyatTab extends StatefulWidget {
  const AyatTab({super.key});

  @override
  State<AyatTab> createState() => _AyatTabState();
}

class _AyatTabState extends State<AyatTab> {
  final EbadatDataService _ebadatService = EbadatDataService();

  List<AyatModel> _ayats = [];
  List<AyatModel> _filteredAyats = [];
  List<String> _categories = [];
  String? _selectedCategory;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load ayats and categories in parallel
      final results = await Future.wait([
        _ebadatService.loadAyats(),
        _ebadatService.getAyatCategories(),
      ]);

      setState(() {
        _ayats = results[0] as List<AyatModel>;
        _categories = results[1] as List<String>;
        _filteredAyats = _ayats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'ডেটা লোড করতে ব্যর্থ হয়েছে। পুনরায় চেষ্টা করুন।';
        _isLoading = false;
      });
    }
  }

  void _filterByCategory(String? category) {
    setState(() {
      _selectedCategory = category;
      if (category == null) {
        _filteredAyats = _ayats;
      } else {
        _filteredAyats = _ayats.where((ayat) => ayat.category == category).toList();
      }
    });
  }

  void _navigateToDetail(AyatModel ayat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AyatDetailScreen(ayat: ayat),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Loading State
    if (_isLoading) {
      return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        itemBuilder: (context, index) => const LoadingCard(),
      );
    }

    // Error State
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
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('পুনরায় চেষ্টা করুন'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    // Empty State
    if (_filteredAyats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _selectedCategory != null
                  ? 'এই ক্যাটাগরিতে কোনো আয়াত নেই'
                  : 'কোনো আয়াত পাওয়া যায়নি',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            if (_selectedCategory != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => _filterByCategory(null),
                icon: const Icon(Icons.clear),
                label: const Text('ফিল্টার মুছে ফেলুন'),
              ),
            ],
          ],
        ),
      );
    }

    // Main Content
    return Column(
      children: [
        // Category Filter Chips
        if (_categories.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // "All" chip
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('সব'),
                    selected: _selectedCategory == null,
                    onSelected: (selected) {
                      if (selected) _filterByCategory(null);
                    },
                    selectedColor: const Color(0xFF1565C0).withValues(alpha: 0.2),
                    checkmarkColor: const Color(0xFF1565C0),
                    labelStyle: TextStyle(
                      color: _selectedCategory == null
                          ? const Color(0xFF1565C0)
                          : Colors.grey[700],
                      fontWeight: _selectedCategory == null
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                // Category chips
                ..._categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (selected) {
                        _filterByCategory(selected ? category : null);
                      },
                      selectedColor: const Color(0xFF1565C0).withValues(alpha: 0.2),
                      checkmarkColor: const Color(0xFF1565C0),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? const Color(0xFF1565C0)
                            : Colors.grey[700],
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

        // Ayat List
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            cacheExtent: 500, // Pre-render items for smoother scrolling
            itemCount: _filteredAyats.length,
            padding: const EdgeInsets.only(bottom: 16),
            itemBuilder: (context, index) {
              final ayat = _filteredAyats[index];
              return RepaintBoundary(
                child: AyatCard(
                  key: ValueKey(ayat.id),
                  ayat: ayat,
                  onTap: () => _navigateToDetail(ayat),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
