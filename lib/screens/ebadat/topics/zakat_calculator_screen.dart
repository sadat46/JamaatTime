import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/zakat_data.dart';
import '../../../widgets/ebadat/worship_step_card.dart';
import '../../../widgets/ebadat/reference_chip.dart';
import 'package:google_fonts/google_fonts.dart';

/// Zakat Calculator Screen with interactive calculator and guide
class ZakatCalculatorScreen extends StatefulWidget {
  const ZakatCalculatorScreen({super.key});

  @override
  State<ZakatCalculatorScreen> createState() => _ZakatCalculatorScreenState();
}

class _ZakatCalculatorScreenState extends State<ZakatCalculatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Calculator form controllers
  final _goldGramsController = TextEditingController();
  final _silverGramsController = TextEditingController();
  final _cashController = TextEditingController();
  final _businessController = TextEditingController();
  final _otherAssetsController = TextEditingController();
  final _debtsController = TextEditingController();

  // Current gold/silver prices (BDT per gram) - these can be updated
  double _goldPricePerGram = 9500; // Approximate
  double _silverPricePerGram = 120; // Approximate

  // Calculated values
  double _totalAssets = 0;
  double _zakatableAmount = 0;
  double _zakatDue = 0;
  bool _isNisabMet = false;
  double _nisabValue = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _calculateNisab();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _goldGramsController.dispose();
    _silverGramsController.dispose();
    _cashController.dispose();
    _businessController.dispose();
    _otherAssetsController.dispose();
    _debtsController.dispose();
    super.dispose();
  }

  void _calculateNisab() {
    // Using silver nisab as it's lower (benefits the poor more)
    _nisabValue = ZakatNisab.silverGrams * _silverPricePerGram;
  }

  void _calculateZakat() {
    final goldGrams = double.tryParse(_goldGramsController.text) ?? 0;
    final silverGrams = double.tryParse(_silverGramsController.text) ?? 0;
    final cash = double.tryParse(_cashController.text) ?? 0;
    final business = double.tryParse(_businessController.text) ?? 0;
    final otherAssets = double.tryParse(_otherAssetsController.text) ?? 0;
    final debts = double.tryParse(_debtsController.text) ?? 0;

    final goldValue = goldGrams * _goldPricePerGram;
    final silverValue = silverGrams * _silverPricePerGram;

    setState(() {
      _totalAssets = goldValue + silverValue + cash + business + otherAssets;
      _zakatableAmount = (_totalAssets - debts).clamp(0, double.infinity);
      _isNisabMet = _zakatableAmount >= _nisabValue;
      _zakatDue = _isNisabMet ? _zakatableAmount * ZakatNisab.zakatRate : 0;
    });
  }

  void _clearForm() {
    _goldGramsController.clear();
    _silverGramsController.clear();
    _cashController.clear();
    _businessController.clear();
    _otherAssetsController.clear();
    _debtsController.clear();
    setState(() {
      _totalAssets = 0;
      _zakatableAmount = 0;
      _zakatDue = 0;
      _isNisabMet = false;
    });
  }

  String _formatCurrency(double amount) {
    return '৳ ${amount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'যাকাত',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 2,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.appBarTheme.foregroundColor,
          unselectedLabelColor:
              theme.appBarTheme.foregroundColor?.withValues(alpha: 0.6),
          tabs: const [
            Tab(text: 'ক্যালকুলেটর', icon: Icon(Icons.calculate)),
            Tab(text: 'নিয়মাবলী', icon: Icon(Icons.menu_book)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCalculatorTab(theme),
          _buildGuideTab(theme),
        ],
      ),
    );
  }

  Widget _buildCalculatorTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nisab info card
          _buildNisabInfoCard(theme),
          const SizedBox(height: 20),

          // Price settings
          _buildPriceSettingsCard(theme),
          const SizedBox(height: 20),

          // Input form
          _buildInputForm(theme),
          const SizedBox(height: 24),

          // Calculate button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _calculateZakat,
              icon: const Icon(Icons.calculate),
              label: const Text(
                'যাকাত হিসাব করুন',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Results card
          _buildResultsCard(theme),
          const SizedBox(height: 16),

          // Clear button
          Center(
            child: TextButton.icon(
              onPressed: _clearForm,
              icon: const Icon(Icons.refresh),
              label: const Text('পুনরায় হিসাব করুন'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildNisabInfoCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: theme.brightness == Brightness.dark
              ? [Colors.amber.shade900, Colors.orange.shade900]
              : [Colors.amber.shade50, Colors.orange.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.amber.shade700
              : Colors.amber.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: theme.brightness == Brightness.dark
                    ? Colors.amber.shade300
                    : Colors.amber.shade800,
              ),
              const SizedBox(width: 8),
              Text(
                'নিসাব (ন্যূনতম সম্পদ)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.brightness == Brightness.dark
                      ? Colors.amber.shade200
                      : Colors.amber.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildNisabRow('স্বর্ণ:', '${ZakatNisab.goldGrams} গ্রাম (৭.৫ ভরি)'),
          _buildNisabRow(
              'রূপা:', '${ZakatNisab.silverGrams} গ্রাম (৫২.৫ ভরি)'),
          _buildNisabRow('বর্তমান নিসাব মূল্য:', _formatCurrency(_nisabValue)),
          const SizedBox(height: 8),
          Text(
            '* রূপার নিসাব অনুসরণ করা হয় কারণ এতে গরীবদের বেশি উপকার হয়',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: theme.brightness == Brightness.dark
                  ? Colors.amber.shade400
                  : Colors.amber.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNisabRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSettingsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'বর্তমান বাজার মূল্য (প্রতি গ্রাম)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _goldPricePerGram.toStringAsFixed(0),
                    decoration: const InputDecoration(
                      labelText: 'স্বর্ণ (৳)',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      _goldPricePerGram = double.tryParse(value) ?? 9500;
                      _calculateNisab();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: _silverPricePerGram.toStringAsFixed(0),
                    decoration: const InputDecoration(
                      labelText: 'রূপা (৳)',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      _silverPricePerGram = double.tryParse(value) ?? 120;
                      _calculateNisab();
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputForm(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'আপনার সম্পদ লিখুন',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInputField(
              controller: _goldGramsController,
              label: 'স্বর্ণ (গ্রামে)',
              icon: Icons.diamond,
              hint: 'যেমন: ২০',
            ),
            _buildInputField(
              controller: _silverGramsController,
              label: 'রূপা (গ্রামে)',
              icon: Icons.circle,
              hint: 'যেমন: ১০০',
            ),
            _buildInputField(
              controller: _cashController,
              label: 'নগদ টাকা ও ব্যাংক ব্যালেন্স (৳)',
              icon: Icons.account_balance_wallet,
              hint: 'যেমন: ৫০০০০০',
            ),
            _buildInputField(
              controller: _businessController,
              label: 'ব্যবসায়িক পণ্যের মূল্য (৳)',
              icon: Icons.store,
              hint: 'যেমন: ১০০০০০০',
            ),
            _buildInputField(
              controller: _otherAssetsController,
              label: 'অন্যান্য সম্পদ (শেয়ার, বন্ড ইত্যাদি) (৳)',
              icon: Icons.trending_up,
              hint: 'যেমন: ২০০০০০',
            ),
            const Divider(height: 32),
            _buildInputField(
              controller: _debtsController,
              label: 'ঋণ/দেনা বাদ দিন (৳)',
              icon: Icons.remove_circle_outline,
              hint: 'যেমন: ১০০০০০',
              isDeduction: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool isDeduction = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(
            icon,
            color: isDeduction ? Colors.red.shade400 : null,
          ),
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
        onChanged: (_) => _calculateZakat(),
      ),
    );
  }

  Widget _buildResultsCard(ThemeData theme) {
    final isZakatDue = _zakatDue > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isZakatDue
              ? (theme.brightness == Brightness.dark
                  ? [Colors.green.shade900, Colors.teal.shade900]
                  : [Colors.green.shade50, Colors.teal.shade50])
              : (theme.brightness == Brightness.dark
                  ? [Colors.grey.shade800, Colors.grey.shade900]
                  : [Colors.grey.shade100, Colors.grey.shade200]),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isZakatDue
              ? (theme.brightness == Brightness.dark
                  ? Colors.green.shade700
                  : Colors.green.shade300)
              : Colors.grey.shade400,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            isZakatDue ? Icons.volunteer_activism : Icons.info_outline,
            size: 48,
            color: isZakatDue
                ? (theme.brightness == Brightness.dark
                    ? Colors.green.shade300
                    : Colors.green.shade700)
                : Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            _isNisabMet ? 'আপনার উপর যাকাত ফরজ' : 'যাকাত ফরজ নয়',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isZakatDue
                  ? (theme.brightness == Brightness.dark
                      ? Colors.green.shade200
                      : Colors.green.shade800)
                  : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),
          _buildResultRow('মোট সম্পদ:', _formatCurrency(_totalAssets)),
          _buildResultRow('যাকাতযোগ্য সম্পদ:', _formatCurrency(_zakatableAmount)),
          _buildResultRow('নিসাব মূল্য:', _formatCurrency(_nisabValue)),
          const Divider(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isZakatDue
                  ? (theme.brightness == Brightness.dark
                      ? Colors.green.shade800
                      : Colors.green.shade100)
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  'প্রদেয় যাকাত (২.৫%)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatCurrency(_zakatDue),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isZakatDue
                        ? (theme.brightness == Brightness.dark
                            ? Colors.green.shade200
                            : Colors.green.shade800)
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Text(
                  'الزكاة',
                  style: GoogleFonts.amiri(
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                    color: theme.brightness == Brightness.dark
                        ? Colors.amber.shade200
                        : Colors.brown.shade800,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 4),
                Text(
                  'Zakat (Obligatory Charity)',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.textTheme.bodySmall?.color,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Key verse
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: theme.brightness == Brightness.dark
                    ? [Colors.green.shade900, Colors.teal.shade900]
                    : [Colors.green.shade50, Colors.teal.shade50],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.brightness == Brightness.dark
                    ? Colors.green.shade700
                    : Colors.green.shade200,
              ),
            ),
            child: Column(
              children: [
                Text(
                  zakatGuide.keyVerse!,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: GoogleFonts.amiri(
                    fontSize: 22,
                    height: 1.8,
                    color: theme.brightness == Brightness.dark
                        ? Colors.green.shade100
                        : Colors.green.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  zakatGuide.keyVerseReference!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.brightness == Brightness.dark
                        ? Colors.green.shade300
                        : Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Introduction
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              zakatGuide.introduction,
              style: TextStyle(
                fontSize: 15,
                height: 1.7,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 8 Recipients section
          _buildRecipientsSection(theme),
          const SizedBox(height: 16),

          // Conditions
          CollapsibleSection(
            title: 'শর্তসমূহ',
            icon: Icons.checklist,
            color: Colors.blue.shade700,
            children: zakatGuide.conditions.asMap().entries.map((entry) {
              return WorshipListItem(
                text: entry.value,
                number: entry.key + 1,
              );
            }).toList(),
          ),

          // Who cannot receive
          CollapsibleSection(
            title: 'যারা যাকাত পাবে না',
            icon: Icons.block,
            color: Colors.red.shade700,
            children: zakatIneligibleRecipients.map((item) {
              return WorshipListItem(
                text: item,
                icon: Icons.cancel_outlined,
                iconColor: Colors.red.shade600,
              );
            }).toList(),
          ),

          // Exempt assets
          CollapsibleSection(
            title: 'যে সম্পদে যাকাত নেই',
            icon: Icons.check_circle,
            color: Colors.green.shade700,
            children: zakatExemptAssets.map((item) {
              return WorshipListItem(
                text: item,
                icon: Icons.check_circle_outline,
                iconColor: Colors.green.shade600,
              );
            }).toList(),
          ),

          // Special rulings
          CollapsibleSection(
            title: 'বিশেষ মাসআলা',
            icon: Icons.lightbulb,
            color: Colors.purple.shade700,
            children: zakatGuide.specialRulings.map((item) {
              return WorshipListItem(
                text: item,
                icon: Icons.info_outline,
                iconColor: Colors.purple.shade600,
              );
            }).toList(),
          ),

          // References
          const Divider(height: 32),
          ReferenceSection(
            references: zakatGuide.references,
            title: 'সকল সূত্র',
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildRecipientsSection(ThemeData theme) {
    final recipients = [
      {'arabic': 'الفقراء', 'bangla': 'ফকির', 'desc': 'যাদের কিছুই নেই'},
      {'arabic': 'المساكين', 'bangla': 'মিসকিন', 'desc': 'যাদের আয় প্রয়োজনের তুলনায় কম'},
      {'arabic': 'العاملين عليها', 'bangla': 'আমিল', 'desc': 'যাকাত সংগ্রহকারী'},
      {'arabic': 'المؤلفة قلوبهم', 'bangla': 'মুআল্লাফাতুল কুলূব', 'desc': 'নওমুসলিম/ইসলামের প্রতি আকৃষ্ট'},
      {'arabic': 'في الرقاب', 'bangla': 'রিকাব', 'desc': 'দাসমুক্তির জন্য'},
      {'arabic': 'الغارمين', 'bangla': 'গারিমীন', 'desc': 'ঋণগ্রস্ত'},
      {'arabic': 'في سبيل الله', 'bangla': 'ফী সাবীলিল্লাহ', 'desc': 'আল্লাহর পথে'},
      {'arabic': 'ابن السبيل', 'bangla': 'ইবনুস সাবীল', 'desc': 'বিপদগ্রস্ত মুসাফির'},
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'যাকাত প্রাপ্য ৮ শ্রেণি (সূরা তাওবাহ ৯:৬০)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...recipients.asMap().entries.map((entry) {
              final index = entry.key;
              final recipient = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                recipient['bangla']!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '(${recipient['arabic']})',
                                style: GoogleFonts.amiri(
                                  fontSize: 14,
                                  color: theme.brightness == Brightness.dark
                                      ? Colors.amber.shade200
                                      : Colors.brown,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                            ],
                          ),
                          Text(
                            recipient['desc']!,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
