import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/locale_text.dart';
import '../../../data/zakat_data.dart';
import '../../../widgets/ebadat/reference_chip.dart';
import '../../../widgets/ebadat/worship_step_card.dart';

/// Zakat Calculator Screen with interactive calculator and guide.
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

  // Current gold/silver prices (BDT per gram)
  double _goldPricePerGram = 9500;
  double _silverPricePerGram = 120;

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
    // Using silver nisab as it's lower (benefits the poor more).
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

  String _formatCurrency(BuildContext context, double amount) {
    final prefix = context.isEnglish ? 'BDT ' : '৳ ';
    return '$prefix${amount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  List<String> _localizedIneligibleRecipients(BuildContext context) {
    if (!context.isEnglish) {
      return zakatIneligibleRecipients;
    }
    return const [
      'Descendants of the Prophet (SAW) (Banu Hashim) - Muslim 1072',
      'A wealthy person with nisab-level assets',
      'Own spouse, children, parents, grandparents (whose support is obligatory)',
      'Non-Muslims (for Zakat specifically; general charity is allowed)',
      'Directly to mosque construction/institutions (except eligible poor students)',
    ];
  }

  List<String> _localizedExemptAssets(BuildContext context) {
    if (!context.isEnglish) {
      return zakatExemptAssets;
    }
    return const [
      'Primary residence/home',
      'Personal-use vehicle',
      'Personal clothing',
      'Household furniture',
      'Professional tools/equipment',
      'Precious stones (if not held for business)',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(bn: 'যাকাত', en: 'Zakat'),
          style: const TextStyle(fontWeight: FontWeight.bold),
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
          tabs: [
            Tab(
              text: context.tr(bn: 'ক্যালকুলেটর', en: 'Calculator'),
              icon: const Icon(Icons.calculate),
            ),
            Tab(
              text: context.tr(bn: 'নিয়মাবলী', en: 'Guidelines'),
              icon: const Icon(Icons.menu_book),
            ),
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
          _buildNisabInfoCard(theme),
          const SizedBox(height: 20),
          _buildPriceSettingsCard(theme),
          const SizedBox(height: 20),
          _buildInputForm(theme),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _calculateZakat,
              icon: const Icon(Icons.calculate),
              label: Text(
                context.tr(bn: 'যাকাত হিসাব করুন', en: 'Calculate Zakat'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

          _buildResultsCard(theme),
          const SizedBox(height: 16),

          Center(
            child: TextButton.icon(
              onPressed: _clearForm,
              icon: const Icon(Icons.refresh),
              label: Text(
                context.tr(bn: 'পুনরায় হিসাব করুন', en: 'Reset Calculation'),
              ),
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
                context.tr(
                  bn: 'নিসাব (ন্যূনতম সম্পদ)',
                  en: 'Nisab (Minimum Wealth)',
                ),
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
          _buildNisabRow(
            context.tr(bn: 'স্বর্ণ:', en: 'Gold:'),
            '${ZakatNisab.goldGrams} ${context.tr(bn: 'গ্রাম', en: 'grams')}',
          ),
          _buildNisabRow(
            context.tr(bn: 'রূপা:', en: 'Silver:'),
            '${ZakatNisab.silverGrams} ${context.tr(bn: 'গ্রাম', en: 'grams')}',
          ),
          _buildNisabRow(
            context.tr(bn: 'বর্তমান নিসাব মূল্য:', en: 'Current Nisab Value:'),
            _formatCurrency(context, _nisabValue),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              bn: '* রূপার নিসাব অনুসরণ করা হয় কারণ এতে গরীবদের বেশি উপকার হয়',
              en: '* Silver nisab is often used as it generally benefits more people in need',
            ),
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
          Text(label, style: const TextStyle(fontSize: 13)),
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
                Text(
                  context.tr(
                    bn: 'বর্তমান বাজার মূল্য (প্রতি গ্রাম)',
                    en: 'Current Market Price (per gram)',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _goldPricePerGram.toStringAsFixed(0),
                    decoration: InputDecoration(
                      labelText: context.tr(bn: 'স্বর্ণ (৳)', en: 'Gold (BDT)'),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
                    decoration: InputDecoration(
                      labelText: context.tr(bn: 'রূপা (৳)', en: 'Silver (BDT)'),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
            Text(
              context.tr(bn: 'আপনার সম্পদ লিখুন', en: 'Enter Your Assets'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInputField(
              controller: _goldGramsController,
              label: context.tr(bn: 'স্বর্ণ (গ্রামে)', en: 'Gold (grams)'),
              icon: Icons.diamond,
              hint: context.tr(bn: 'যেমন: ২০', en: 'e.g. 20'),
            ),
            _buildInputField(
              controller: _silverGramsController,
              label: context.tr(bn: 'রূপা (গ্রামে)', en: 'Silver (grams)'),
              icon: Icons.circle,
              hint: context.tr(bn: 'যেমন: ১০০', en: 'e.g. 100'),
            ),
            _buildInputField(
              controller: _cashController,
              label: context.tr(
                bn: 'নগদ টাকা ও ব্যাংক ব্যালেন্স (৳)',
                en: 'Cash & Bank Balance (BDT)',
              ),
              icon: Icons.account_balance_wallet,
              hint: context.tr(bn: 'যেমন: ৫০০০০০', en: 'e.g. 500000'),
            ),
            _buildInputField(
              controller: _businessController,
              label: context.tr(
                bn: 'ব্যবসায়িক পণ্যের মূল্য (৳)',
                en: 'Business Inventory Value (BDT)',
              ),
              icon: Icons.store,
              hint: context.tr(bn: 'যেমন: ১০০০০০০', en: 'e.g. 1000000'),
            ),
            _buildInputField(
              controller: _otherAssetsController,
              label: context.tr(
                bn: 'অন্যান্য সম্পদ (শেয়ার, বন্ড ইত্যাদি) (৳)',
                en: 'Other Assets (shares, bonds, etc.) (BDT)',
              ),
              icon: Icons.trending_up,
              hint: context.tr(bn: 'যেমন: ২০০০০০', en: 'e.g. 200000'),
            ),
            const Divider(height: 32),
            _buildInputField(
              controller: _debtsController,
              label: context.tr(bn: 'ঋণ/দেনা বাদ দিন (৳)', en: 'Deduct Debts (BDT)'),
              icon: Icons.remove_circle_outline,
              hint: context.tr(bn: 'যেমন: ১০০০০০', en: 'e.g. 100000'),
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
          prefixIcon: Icon(icon, color: isDeduction ? Colors.red.shade400 : null),
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
            _isNisabMet
                ? context.tr(bn: 'আপনার উপর যাকাত ফরজ', en: 'Zakat is Due on You')
                : context.tr(bn: 'যাকাত ফরজ নয়', en: 'Zakat is Not Due'),
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
          _buildResultRow(
            context.tr(bn: 'মোট সম্পদ:', en: 'Total Assets:'),
            _formatCurrency(context, _totalAssets),
          ),
          _buildResultRow(
            context.tr(bn: 'যাকাতযোগ্য সম্পদ:', en: 'Zakatable Assets:'),
            _formatCurrency(context, _zakatableAmount),
          ),
          _buildResultRow(
            context.tr(bn: 'নিসাব মূল্য:', en: 'Nisab Value:'),
            _formatCurrency(context, _nisabValue),
          ),
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
                Text(
                  context.tr(bn: 'প্রদেয় যাকাত (২.৫%)', en: 'Zakat Due (2.5%)'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatCurrency(context, _zakatDue),
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
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideTab(ThemeData theme) {
    final locale = Localizations.localeOf(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  context.tr(
                    bn: 'যাকাত (ফরজ দান)',
                    en: 'Zakat (Obligatory Charity)',
                  ),
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

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              zakatGuide.getIntroduction(locale),
              style: TextStyle(
                fontSize: 15,
                height: 1.7,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ),
          const SizedBox(height: 24),

          _buildRecipientsSection(theme),
          const SizedBox(height: 16),

          CollapsibleSection(
            title: context.tr(bn: 'শর্তসমূহ', en: 'Conditions'),
            icon: Icons.checklist,
            color: Colors.blue.shade700,
            children: zakatGuide.getConditions(locale).asMap().entries.map((entry) {
              return WorshipListItem(text: entry.value, number: entry.key + 1);
            }).toList(),
          ),

          CollapsibleSection(
            title: context.tr(bn: 'যারা যাকাত পাবে না', en: 'Who Cannot Receive Zakat'),
            icon: Icons.block,
            color: Colors.red.shade700,
            children: _localizedIneligibleRecipients(context).map((item) {
              return WorshipListItem(
                text: item,
                icon: Icons.cancel_outlined,
                iconColor: Colors.red.shade600,
              );
            }).toList(),
          ),

          CollapsibleSection(
            title: context.tr(bn: 'যে সম্পদে যাকাত নেই', en: 'Exempt Assets'),
            icon: Icons.check_circle,
            color: Colors.green.shade700,
            children: _localizedExemptAssets(context).map((item) {
              return WorshipListItem(
                text: item,
                icon: Icons.check_circle_outline,
                iconColor: Colors.green.shade600,
              );
            }).toList(),
          ),

          CollapsibleSection(
            title: context.tr(bn: 'বিশেষ মাসআলা', en: 'Special Rulings'),
            icon: Icons.lightbulb,
            color: Colors.purple.shade700,
            children: zakatGuide.getSpecialRulings(locale).map((item) {
              return WorshipListItem(
                text: item,
                icon: Icons.info_outline,
                iconColor: Colors.purple.shade600,
              );
            }).toList(),
          ),

          const Divider(height: 32),
          ReferenceSection(
            references: zakatGuide.references,
            title: context.tr(bn: 'সকল সূত্র', en: 'All References'),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildRecipientsSection(ThemeData theme) {
    final recipients = [
      {
        'arabic': 'الفقراء',
        'bn': 'ফকির',
        'en': 'Fuqara',
        'descBn': 'যাদের কিছুই নেই',
        'descEn': 'Those with almost nothing',
      },
      {
        'arabic': 'المساكين',
        'bn': 'মিসকিন',
        'en': 'Masakin',
        'descBn': 'যাদের আয় প্রয়োজনের তুলনায় কম',
        'descEn': 'Those whose income is insufficient',
      },
      {
        'arabic': 'العاملين عليها',
        'bn': 'আমিল',
        'en': 'Amil',
        'descBn': 'যাকাত সংগ্রহকারী',
        'descEn': 'Zakat collectors/administrators',
      },
      {
        'arabic': 'المؤلفة قلوبهم',
        'bn': 'মুয়াল্লাফাতুল কুলুব',
        'en': 'Muallafat al-Qulub',
        'descBn': 'ইসলামের প্রতি আকৃষ্ট ব্যক্তি',
        'descEn': 'Those whose hearts are to be reconciled',
      },
      {
        'arabic': 'في الرقاب',
        'bn': 'রিকাব',
        'en': 'Fi al-Riqab',
        'descBn': 'দাসমুক্তির জন্য',
        'descEn': 'For freeing captives/slaves',
      },
      {
        'arabic': 'الغارمين',
        'bn': 'গারিমীন',
        'en': 'Gharimin',
        'descBn': 'ঋণগ্রস্ত',
        'descEn': 'Those burdened by debt',
      },
      {
        'arabic': 'في سبيل الله',
        'bn': 'ফি সাবীলিল্লাহ',
        'en': 'Fi Sabilillah',
        'descBn': 'আল্লাহর পথে',
        'descEn': 'In the cause of Allah',
      },
      {
        'arabic': 'ابن السبيل',
        'bn': 'ইবনুস সাবীল',
        'en': 'Ibn al-Sabil',
        'descBn': 'বিপদগ্রস্ত মুসাফির',
        'descEn': 'A stranded traveler',
      },
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
                Expanded(
                  child: Text(
                    context.tr(
                      bn: 'যাকাত প্রাপ্য ৮ শ্রেণি (সূরা তাওবাহ ৯:৬০)',
                      en: '8 Eligible Zakat Categories (Surah Tawbah 9:60)',
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
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
                                context.isEnglish
                                    ? recipient['en']!
                                    : recipient['bn']!,
                                style:
                                    const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '(${recipient['arabic']})',
                                  style: GoogleFonts.amiri(
                                    fontSize: 14,
                                    color: theme.brightness == Brightness.dark
                                        ? Colors.amber.shade200
                                        : Colors.brown,
                                  ),
                                  textDirection: TextDirection.rtl,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            context.isEnglish
                                ? recipient['descEn']!
                                : recipient['descBn']!,
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
