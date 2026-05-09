import 'package:intl/intl.dart';

/// Small memoized cache for [DateFormat] instances.
///
/// Constructing a `DateFormat(pattern, localeCode)` parses the pattern, looks
/// up locale data, and allocates internal buffers. Tick-driven build paths use
/// the same handful of patterns repeatedly, so one cached formatter per
/// `(pattern, localeCode)` pair is enough.
class DateFormatCache {
  DateFormatCache._();

  static final Map<String, DateFormat> _cache = <String, DateFormat>{};

  /// Returns a cached [DateFormat] for [pattern] in [localeCode].
  ///
  /// Pass `null` for [localeCode] to use the default system locale.
  static DateFormat get(String pattern, [String? localeCode]) {
    final key = localeCode == null ? pattern : '$pattern::$localeCode';
    return _cache.putIfAbsent(
      key,
      () => localeCode == null
          ? DateFormat(pattern)
          : DateFormat(pattern, localeCode),
    );
  }

  /// Visible for tests. Clears the cache between runs.
  static void debugClear() => _cache.clear();
}
