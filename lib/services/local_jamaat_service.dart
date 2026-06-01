import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'settings_service.dart';

/// Fajr / Dhuhr / Asr / Isha — Maghrib is intentionally absent because it's
/// always derived from prayer Maghrib + the cantt-specific offset table in
/// [PrayerAuxCalculator], not edited locally.
class LocalJamaatTimes {
  const LocalJamaatTimes({
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.isha,
  });

  final String fajr;
  final String dhuhr;
  final String asr;
  final String isha;

  Map<String, dynamic> toJamaatMap() => <String, dynamic>{
        'fajr': fajr,
        'dhuhr': dhuhr,
        'asr': asr,
        'isha': isha,
      };

  Map<String, String> toJson() => <String, String>{
        'fajr': fajr,
        'dhuhr': dhuhr,
        'asr': asr,
        'isha': isha,
      };

  static LocalJamaatTimes? tryFromJson(Map<String, dynamic> json) {
    final fajr = json['fajr']?.toString();
    final dhuhr = json['dhuhr']?.toString();
    final asr = json['asr']?.toString();
    final isha = json['isha']?.toString();
    if (fajr == null || dhuhr == null || asr == null || isha == null) {
      return null;
    }
    return LocalJamaatTimes(fajr: fajr, dhuhr: dhuhr, asr: asr, isha: isha);
  }
}

/// Loads `assets/data/local.csv` once, caches it, and combines bundled
/// defaults with per-date user overrides stored locally.
///
/// Phase 4 of PRAYER_LOCATION_FIX_PLAN. Local Mosque mode never uploads
/// anywhere; overrides are device-local only.
class LocalJamaatService {
  LocalJamaatService._({
    Future<String> Function()? assetLoader,
    SettingsService? settingsService,
  })  : _assetLoader = assetLoader ??
            (() => rootBundle.loadString(_csvAssetPath)),
        _settingsService = settingsService ?? SettingsService();

  static const String _csvAssetPath = 'assets/data/local.csv';

  static final LocalJamaatService _instance = LocalJamaatService._();
  factory LocalJamaatService() => _instance;

  /// Testing-only constructor that injects a custom asset loader.
  factory LocalJamaatService.forTesting({
    required Future<String> Function() assetLoader,
    SettingsService? settingsService,
  }) =>
      LocalJamaatService._(
        assetLoader: assetLoader,
        settingsService: settingsService,
      );

  final Future<String> Function() _assetLoader;
  final SettingsService _settingsService;
  Map<String, LocalJamaatTimes>? _csvCache;
  Future<Map<String, LocalJamaatTimes>>? _csvLoadFuture;

  /// Effective Local Mosque Jamaat times for [date].
  ///
  /// Order: user override (if any) → bundled CSV default → null.
  Future<LocalJamaatTimes?> getEffectiveTimesForDate(DateTime date) async {
    final key = _dateKey(date);
    final overrides = await _readOverrides();
    final override = overrides[key];
    if (override != null) return override;
    final csv = await _loadCsv();
    return csv[key];
  }

  /// User override for [date], or null if none has been saved.
  Future<LocalJamaatTimes?> getOverrideForDate(DateTime date) async {
    final overrides = await _readOverrides();
    return overrides[_dateKey(date)];
  }

  /// Bundled CSV default for [date], or null if the asset has no entry.
  Future<LocalJamaatTimes?> getCsvDefaultForDate(DateTime date) async {
    final csv = await _loadCsv();
    return csv[_dateKey(date)];
  }

  /// Save a user-edited override for [date]. Never uploads anywhere.
  Future<void> setOverrideForDate(
    DateTime date,
    LocalJamaatTimes times,
  ) async {
    final overrides = await _readOverrides();
    overrides[_dateKey(date)] = times;
    await _writeOverrides(overrides);
  }

  /// Remove the override for [date], returning it to the bundled CSV default.
  Future<void> clearOverrideForDate(DateTime date) async {
    final overrides = await _readOverrides();
    if (overrides.remove(_dateKey(date)) == null) return;
    await _writeOverrides(overrides);
  }

  /// Normalize a user-typed time string. Accepts `HH:mm`, `H:mm`,
  /// `hh:mm AM/PM`, or `h:mm AM/PM`. Returns canonical `HH:mm` or null if
  /// the input is unparseable / out of range.
  static String? parseTimeInput(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // 24-hour: H:mm or HH:mm
    final h24 = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(trimmed);
    if (h24 != null) {
      final hour = int.parse(h24.group(1)!);
      final minute = int.parse(h24.group(2)!);
      if (hour > 23 || minute > 59) return null;
      return _format(hour, minute);
    }

    // 12-hour: h:mm AM/PM (case-insensitive)
    final h12 = RegExp(r'^(\d{1,2}):(\d{2})\s*([AaPp])[Mm]$').firstMatch(trimmed);
    if (h12 != null) {
      var hour = int.parse(h12.group(1)!);
      final minute = int.parse(h12.group(2)!);
      final marker = h12.group(3)!.toUpperCase();
      if (hour < 1 || hour > 12 || minute > 59) return null;
      if (marker == 'A') {
        if (hour == 12) hour = 0;
      } else {
        if (hour != 12) hour += 12;
      }
      return _format(hour, minute);
    }

    return null;
  }

  static String _format(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Convert any date to the canonical `YYYY-MM-DD` storage key.
  static String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  // ──────────────────────────────────────────────────────────────────────────
  // CSV loader
  // ──────────────────────────────────────────────────────────────────────────

  Future<Map<String, LocalJamaatTimes>> _loadCsv() async {
    if (_csvCache != null) return _csvCache!;
    _csvLoadFuture ??= _doLoadCsv();
    _csvCache = await _csvLoadFuture!;
    return _csvCache!;
  }

  Future<Map<String, LocalJamaatTimes>> _doLoadCsv() async {
    final raw = await _assetLoader();
    final rows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(raw);
    if (rows.isEmpty) return <String, LocalJamaatTimes>{};

    final result = <String, LocalJamaatTimes>{};
    // Skip header row.
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 5) continue;
      final dateRaw = row[0]?.toString().trim() ?? '';
      if (dateRaw.isEmpty) continue;
      final date = _parseCsvDate(dateRaw);
      if (date == null) continue;

      final fajr = parseTimeInput(row[1]?.toString() ?? '');
      final dhuhr = parseTimeInput(row[2]?.toString() ?? '');
      final asr = parseTimeInput(row[3]?.toString() ?? '');
      final isha = parseTimeInput(row[4]?.toString() ?? '');
      if (fajr == null || dhuhr == null || asr == null || isha == null) {
        continue;
      }

      result[_dateKey(date)] = LocalJamaatTimes(
        fajr: fajr,
        dhuhr: dhuhr,
        asr: asr,
        isha: isha,
      );
    }
    return result;
  }

  /// Accepts `D/M/YYYY`, `DD/MM/YYYY`, `D-M-YYYY`, `DD-MM-YYYY` (day-first).
  static DateTime? _parseCsvDate(String raw) {
    final parts = raw.split(RegExp(r'[\/\-]'));
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Override storage
  // ──────────────────────────────────────────────────────────────────────────

  Future<Map<String, LocalJamaatTimes>> _readOverrides() async {
    final raw = await _settingsService.getLocalJamaatOverridesRaw();
    if (raw == null || raw.isEmpty) return <String, LocalJamaatTimes>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, LocalJamaatTimes>{};
      final result = <String, LocalJamaatTimes>{};
      decoded.forEach((key, value) {
        if (key is! String || value is! Map) return;
        final times = LocalJamaatTimes.tryFromJson(
          Map<String, dynamic>.from(value),
        );
        if (times != null) {
          result[key] = times;
        }
      });
      return result;
    } catch (_) {
      return <String, LocalJamaatTimes>{};
    }
  }

  Future<void> _writeOverrides(
    Map<String, LocalJamaatTimes> overrides,
  ) async {
    if (overrides.isEmpty) {
      await _settingsService.setLocalJamaatOverridesRaw(null);
      return;
    }
    final encoded = jsonEncode(
      overrides.map((k, v) => MapEntry(k, v.toJson())),
    );
    await _settingsService.setLocalJamaatOverridesRaw(encoded);
  }
}
