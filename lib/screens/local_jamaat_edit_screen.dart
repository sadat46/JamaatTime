import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/locale_text.dart';
import '../services/local_jamaat_service.dart';

/// Settings page for editing per-date Local Mosque Jamaat times.
///
/// Pre-fills each date with the effective times (user override first, bundled
/// CSV default second). Save writes a new override; Reset deletes one and the
/// date falls back to the CSV default. Maghrib is intentionally not editable —
/// it's always derived from prayer Maghrib + the cantonment offset table.
class LocalJamaatEditScreen extends StatefulWidget {
  const LocalJamaatEditScreen({super.key});

  @override
  State<LocalJamaatEditScreen> createState() => _LocalJamaatEditScreenState();
}

class _LocalJamaatEditScreenState extends State<LocalJamaatEditScreen> {
  final LocalJamaatService _service = LocalJamaatService();
  final TextEditingController _fajrCtrl = TextEditingController();
  final TextEditingController _dhuhrCtrl = TextEditingController();
  final TextEditingController _asrCtrl = TextEditingController();
  final TextEditingController _ishaCtrl = TextEditingController();

  DateTime _selectedDate = _today();
  bool _hasOverride = false;
  bool _loading = true;
  bool _saving = false;
  String? _statusMessage;
  bool _statusIsError = false;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _loadForSelectedDate();
  }

  @override
  void dispose() {
    _fajrCtrl.dispose();
    _dhuhrCtrl.dispose();
    _asrCtrl.dispose();
    _ishaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadForSelectedDate() async {
    setState(() {
      _loading = true;
      _statusMessage = null;
    });
    final override = await _service.getOverrideForDate(_selectedDate);
    final effective =
        override ?? await _service.getCsvDefaultForDate(_selectedDate);
    if (!mounted) return;
    setState(() {
      _hasOverride = override != null;
      _fajrCtrl.text = effective?.fajr ?? '';
      _dhuhrCtrl.text = effective?.dhuhr ?? '';
      _asrCtrl.text = effective?.asr ?? '';
      _ishaCtrl.text = effective?.isha ?? '';
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2030, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
    await _loadForSelectedDate();
  }

  Future<void> _save() async {
    if (_saving) return;
    final fajr = LocalJamaatService.parseTimeInput(_fajrCtrl.text);
    final dhuhr = LocalJamaatService.parseTimeInput(_dhuhrCtrl.text);
    final asr = LocalJamaatService.parseTimeInput(_asrCtrl.text);
    final isha = LocalJamaatService.parseTimeInput(_ishaCtrl.text);

    if (fajr == null || dhuhr == null || asr == null || isha == null) {
      setState(() {
        _statusIsError = true;
        _statusMessage = context.tr(
          bn:
              'সবগুলো সময় ২৪-ঘন্টা (HH:mm) বা ১২-ঘন্টা (hh:mm AM/PM) ফরম্যাটে দিন।',
          en: 'Enter all four times as HH:mm or hh:mm AM/PM.',
        );
      });
      return;
    }

    setState(() {
      _saving = true;
    });
    await _service.setOverrideForDate(
      _selectedDate,
      LocalJamaatTimes(fajr: fajr, dhuhr: dhuhr, asr: asr, isha: isha),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _hasOverride = true;
      _fajrCtrl.text = fajr;
      _dhuhrCtrl.text = dhuhr;
      _asrCtrl.text = asr;
      _ishaCtrl.text = isha;
      _statusIsError = false;
      _statusMessage = context.tr(
        bn: 'এই তারিখের সময় সংরক্ষণ হয়েছে।',
        en: 'Saved override for this date.',
      );
    });
  }

  Future<void> _reset() async {
    if (_saving) return;
    setState(() {
      _saving = true;
    });
    await _service.clearOverrideForDate(_selectedDate);
    if (!mounted) return;
    final fallback = await _service.getCsvDefaultForDate(_selectedDate);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _hasOverride = false;
      _fajrCtrl.text = fallback?.fajr ?? '';
      _dhuhrCtrl.text = fallback?.dhuhr ?? '';
      _asrCtrl.text = fallback?.asr ?? '';
      _ishaCtrl.text = fallback?.isha ?? '';
      _statusIsError = false;
      _statusMessage = context.tr(
        bn: 'ডিফল্টে ফিরে এসেছে।',
        en: 'Reverted to bundled default.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        DateFormat('EEE, d MMM yyyy').format(_selectedDate);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(bn: 'লোকাল জামাত সময়', en: 'Local Mosque Times'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text(dateLabel),
                    subtitle: Text(
                      _hasOverride
                          ? context.tr(
                              bn: 'এই তারিখের জন্য কাস্টম সময় সংরক্ষিত',
                              en: 'Custom override saved for this date',
                            )
                          : context.tr(
                              bn: 'বান্ডল করা ডিফল্ট ব্যবহার হচ্ছে',
                              en: 'Using bundled default',
                            ),
                    ),
                    trailing: TextButton(
                      onPressed: _pickDate,
                      child:
                          Text(context.tr(bn: 'পরিবর্তন', en: 'Change')),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    context.tr(
                      bn:
                          'সময় HH:mm অথবা hh:mm AM/PM ফরম্যাটে লিখুন। মাগরিব সবসময় গণনা করা হয়, এখানে সম্পাদনাযোগ্য নয়।',
                      en:
                          'Enter time as HH:mm or hh:mm AM/PM. Maghrib is always calculated and is not editable here.',
                    ),
                    style:
                        TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
                _timeField(
                  controller: _fajrCtrl,
                  label: context.tr(bn: 'ফজর', en: 'Fajr'),
                ),
                const SizedBox(height: 12),
                _timeField(
                  controller: _dhuhrCtrl,
                  label: context.tr(bn: 'যোহর', en: 'Dhuhr'),
                ),
                const SizedBox(height: 12),
                _timeField(
                  controller: _asrCtrl,
                  label: context.tr(bn: 'আসর', en: 'Asr'),
                ),
                const SizedBox(height: 12),
                _timeField(
                  controller: _ishaCtrl,
                  label: context.tr(bn: 'ইশা', en: 'Isha'),
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage!,
                    style: TextStyle(
                      color:
                          _statusIsError ? Colors.red : Colors.green.shade700,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(
                    context.tr(bn: 'সংরক্ষণ করুন', en: 'Save'),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed:
                      _saving || !_hasOverride ? null : _reset,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: Text(
                    context.tr(
                      bn: 'ডিফল্টে ফিরে যান',
                      en: 'Reset to default',
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _timeField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.datetime,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        hintText: '05:50',
      ),
    );
  }
}
