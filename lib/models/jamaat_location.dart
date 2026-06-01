import 'package:shared_preferences/shared_preferences.dart';

/// Source of Jamaat (congregation) times shown by the app.
///
/// Independent from prayer-time location. A user can have prayer times from
/// GPS while Jamaat comes from a chosen server mosque, or local CSV, or none.
enum JamaatSource { serverMosque, local, none }

/// User's Jamaat / mosque selection, persisted independently from prayer state.
///
/// GPS never writes this; server/admin Jamaat writes never affect Local Mosque
/// overrides; Local Mosque overrides never upload.
class JamaatLocation {
  const JamaatLocation({
    required this.source,
    this.city,
    this.mosqueId,
    this.locationName,
  });

  final JamaatSource source;
  final String? city;
  final String? mosqueId;
  final String? locationName;

  static const String _prefSource = 'jamaat_source';
  static const String _prefCity = 'jamaat_city';
  static const String _prefMosqueId = 'jamaat_mosque_id';
  static const String _prefLocationName = 'jamaat_location_name';

  /// Returned when no Jamaat selection exists yet (fresh install).
  static const JamaatLocation empty = JamaatLocation(source: JamaatSource.none);

  bool get hasServerMosque => source == JamaatSource.serverMosque && city != null;

  /// Cache-namespace for the persistent Jamaat schedule cache. `null` means
  /// "no Jamaat source — nothing to cache". Otherwise `"sourceName:city"`
  /// with city empty for sources that don't carry one (local).
  String? get scopeKey {
    switch (source) {
      case JamaatSource.serverMosque:
        if (city == null || city!.isEmpty) return null;
        return 'serverMosque:$city';
      case JamaatSource.local:
        return 'local:';
      case JamaatSource.none:
        return null;
    }
  }

  JamaatLocation copyWith({
    JamaatSource? source,
    String? city,
    String? mosqueId,
    String? locationName,
  }) {
    return JamaatLocation(
      source: source ?? this.source,
      city: city ?? this.city,
      mosqueId: mosqueId ?? this.mosqueId,
      locationName: locationName ?? this.locationName,
    );
  }

  static JamaatLocation? readFromPrefs(SharedPreferences prefs) {
    final raw = prefs.getString(_prefSource);
    if (raw == null) return null;
    final source = _parseSource(raw);
    return JamaatLocation(
      source: source,
      city: prefs.getString(_prefCity),
      mosqueId: prefs.getString(_prefMosqueId),
      locationName: prefs.getString(_prefLocationName),
    );
  }

  Future<void> writeToPrefs(SharedPreferences prefs) async {
    await prefs.setString(_prefSource, _encodeSource(source));
    await _writeOrRemove(prefs, _prefCity, city);
    await _writeOrRemove(prefs, _prefMosqueId, mosqueId);
    await _writeOrRemove(prefs, _prefLocationName, locationName);
  }

  static Future<void> _writeOrRemove(
    SharedPreferences prefs,
    String key,
    String? value,
  ) async {
    if (value == null || value.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }

  static JamaatSource _parseSource(String raw) {
    switch (raw) {
      case 'server_mosque':
        return JamaatSource.serverMosque;
      case 'local':
        return JamaatSource.local;
      case 'none':
      default:
        return JamaatSource.none;
    }
  }

  static String _encodeSource(JamaatSource source) {
    switch (source) {
      case JamaatSource.serverMosque:
        return 'server_mosque';
      case JamaatSource.local:
        return 'local';
      case JamaatSource.none:
        return 'none';
    }
  }

  @override
  String toString() =>
      'JamaatLocation(source: $source, city: $city, name: $locationName)';
}
