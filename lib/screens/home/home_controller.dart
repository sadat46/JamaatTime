import 'dart:async';

import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../core/app_locale_controller.dart';
import '../../core/constants.dart';
import '../../features/notice_board/data/notice_model.dart';
import '../../features/notice_board/data/notice_read_state_service.dart';
import '../../features/notice_board/data/notice_repository.dart';
import '../../models/jamaat_location.dart';
import '../../models/location_config.dart';
import '../../models/prayer_location.dart';
import '../../services/jamaat_service.dart';
import '../../services/local_jamaat_service.dart';
import '../../services/location_config_service.dart';
import '../../services/location_service.dart';
import '../../services/notifications/notification_service.dart';
import '../../services/notifications/reminders/jamaat_schedule_cache_writer.dart';
import '../../services/prayer_aux_calculator.dart';
import '../../services/prayer_time_cache.dart';
import '../../services/prayer_time_engine.dart';
import '../../services/settings_service.dart';
import 'models/prayer_row_data.dart';
import 'services/home_notification_scheduler.dart';
import 'services/home_widget_sync.dart';

class HomeLocationFetchResult {
  const HomeLocationFetchResult.success({
    required this.latitude,
    required this.longitude,
    required this.placeName,
  }) : error = null;

  const HomeLocationFetchResult.error(this.error)
    : latitude = null,
      longitude = null,
      placeName = null;

  final double? latitude;
  final double? longitude;
  final String? placeName;
  final Object? error;

  bool get isSuccess => error == null;
}

class _HomeStartupState {
  const _HomeStartupState({
    required this.prayerLocation,
    required this.jamaatLocation,
    required this.locationConfig,
    required this.coordinates,
    required this.currentPlaceName,
    required this.madhab,
    required this.bangladeshHijriOffsetDays,
    required this.cacheKey,
  });

  final PrayerLocation? prayerLocation;
  final JamaatLocation jamaatLocation;
  final LocationConfig? locationConfig;
  final Coordinates? coordinates;
  final String? currentPlaceName;
  final String madhab;
  final int bangladeshHijriOffsetDays;
  final PrayerTimeCacheKey cacheKey;
}

class HomeController extends ChangeNotifier {
  HomeController({
    required bool isActive,
    AppLifecycleState? lifecycleState,
    SettingsService? settingsService,
    LocationService? locationService,
    NotificationService? notificationService,
    JamaatService? jamaatService,
    LocationConfigService? locationConfigService,
    NoticeRepository? noticeRepository,
    NoticeReadStateService? noticeReadState,
    HomeNotificationScheduler? notificationScheduler,
    HomeWidgetSync? widgetSync,
    PrayerTimeCache? prayerTimeCache,
    JamaatScheduleCacheWriter? jamaatScheduleCacheWriter,
    LocalJamaatService? localJamaatService,
  }) : _isHomeActive = isActive,
       _appLifecycleActive =
           lifecycleState == null ||
           lifecycleState == AppLifecycleState.resumed,
       _settingsService = settingsService ?? SettingsService(),
       _locationService = locationService ?? LocationService(),
       _notificationService = notificationService ?? NotificationService(),
       _jamaatServiceOverride = jamaatService,
       _locationConfigService =
           locationConfigService ?? LocationConfigService(),
       _noticeRepositoryOverride = noticeRepository,
       _noticeReadStateOverride = noticeReadState,
       _notificationScheduler =
           notificationScheduler ??
           HomeNotificationScheduler(
             notificationService: notificationService ?? NotificationService(),
           ),
       _widgetSync = widgetSync ?? HomeWidgetSync(),
       _prayerTimeCache = prayerTimeCache ?? PrayerTimeCache(),
       _jamaatScheduleCacheWriter =
           jamaatScheduleCacheWriter ?? JamaatScheduleCacheWriter(),
       _localJamaatService = localJamaatService ?? LocalJamaatService();

  final SettingsService _settingsService;
  final LocationService _locationService;
  final NotificationService _notificationService;
  final JamaatService? _jamaatServiceOverride;
  final LocationConfigService _locationConfigService;
  NoticeRepository? _noticeRepositoryOverride;
  NoticeReadStateService? _noticeReadStateOverride;
  final HomeNotificationScheduler _notificationScheduler;
  final HomeWidgetSync _widgetSync;
  final PrayerTimeCache _prayerTimeCache;
  final JamaatScheduleCacheWriter _jamaatScheduleCacheWriter;
  final LocalJamaatService _localJamaatService;

  Timer? _timer;
  DateTime _now = DateTime.now();
  final ValueNotifier<DateTime> _nowNotifier = ValueNotifier<DateTime>(
    DateTime.now(),
  );
  Coordinates? _coords;
  CalculationParameters? _params;
  PrayerTimes? _prayerTimes;
  Map<String, DateTime?> _times = {};
  Map<String, dynamic>? _jamaatTimes;
  bool _isLoadingJamaat = false;
  String? _jamaatError;
  DateTime? _lastJamaatUpdate;
  DateTime _selectedDate = DateTime.now();
  PrayerLocation? _prayerLocation;
  JamaatLocation _jamaatLocation = JamaatLocation.empty;
  LocationConfig? _locationConfig;
  String? _currentPlaceName;
  bool _isFetchingPlaceName = false;
  int _bangladeshHijriOffsetDays =
      SettingsService.defaultBangladeshHijriOffsetDays;
  List<PrayerRowData> _prayerTableData = [];
  String? _lastCurrentPeriod;
  StreamSubscription<void>? _settingsSubscription;
  bool _isHomeActive;
  bool _appLifecycleActive;
  bool _isDisposed = false;
  bool _initialized = false;
  bool _hydratedFromCache = false;
  String _madhab = 'hanafi';
  Future<bool>? _hydrateFuture;
  Map<String, DateTime?>? _hydratedTimes;
  Map<String, dynamic>? _hydratedJamaatTimes;

  JamaatService get _jamaatService => _jamaatServiceOverride ?? JamaatService();

  DateTime get now => _now;
  Coordinates? get coords => _coords;
  CalculationParameters? get calculationParams => _params;
  PrayerTimes? get prayerTimes => _prayerTimes;
  Map<String, DateTime?> get times => _times;
  ValueListenable<DateTime> get nowNotifier => _nowNotifier;
  List<DateTime?> get orderedPrayerDateTimes => const [
    'Fajr',
    'Sunrise',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ].map((n) => _times[n]).toList(growable: false);
  Map<String, dynamic>? get jamaatTimes => _jamaatTimes;
  bool get isLoadingJamaat => _isLoadingJamaat;
  String? get jamaatError => _jamaatError;
  DateTime? get lastJamaatUpdate => _lastJamaatUpdate;
  DateTime get selectedDate => _selectedDate;
  /// Jamaat-side city selection (the home-screen mosque dropdown). Prayer
  /// location is independent and read from `_prayerLocation`.
  String? get selectedCity => _jamaatLocation.city;
  PrayerLocation? get prayerLocation => _prayerLocation;
  JamaatLocation get jamaatLocation => _jamaatLocation;
  LocationConfig? get locationConfig => _locationConfig;
  String? get currentPlaceName => _currentPlaceName;
  bool get isFetchingPlaceName => _isFetchingPlaceName;
  int get bangladeshHijriOffsetDays => _bangladeshHijriOffsetDays;
  List<PrayerRowData> get prayerTableData => _prayerTableData;
  bool get shouldRunHomeTimer => _isHomeActive && _appLifecycleActive;

  Stream<NoticeModel?> watchLatestNotice() => noticeRepository.watchLatest();

  Future<bool> hasUnreadLatestNotice(NoticeModel? latest) {
    return noticeReadState.hasUnreadLatest(latest);
  }

  Future<void> markLatestNoticeSeen(NoticeModel latest) {
    return noticeReadState.markAllSeen([latest]);
  }

  NoticeRepository get noticeRepository {
    return _noticeRepositoryOverride ??= NoticeRepository();
  }

  NoticeReadStateService get noticeReadState {
    return _noticeReadStateOverride ??= NoticeReadStateService();
  }

  Future<void> initialize() async {
    if (_initialized || _isDisposed) {
      return;
    }
    _initialized = true;

    if (_hydrateFuture != null) {
      await _hydrateFuture;
      if (_isDisposed) return;
    }

    final startupState = await _resolveStartupState();
    if (_isDisposed) return;
    _applyStartupState(startupState);

    updatePrayerTimes(
      notify: false,
      scheduleNotifications: false,
      writeCache: false,
    );
    if (!_hydratedFromCache ||
        !_dateTimeMapsEqual(_times, _hydratedTimes) ||
        !_dynamicMapsEqual(_jamaatTimes, _hydratedJamaatTimes)) {
      _notify();
    }
    _writeCache();

    if (_jamaatLocation.hasServerMosque) {
      await fetchJamaatTimes(_jamaatLocation.city!, preserveExisting: true);
      if (_isDisposed) return;
    } else if (_jamaatLocation.source == JamaatSource.local) {
      await refreshLocalJamaatTimes(preserveExisting: true);
      if (_isDisposed) return;
    }

    unawaited(_scheduleNotificationsIfNeeded());
    _syncHomeTimer();

    _settingsSubscription = _settingsService.onSettingsChanged.listen((
      _,
    ) async {
      await _loadMadhab();
      if (_isDisposed) return;
      await _loadBangladeshHijriOffset();
      if (_isDisposed) return;
      await _notificationScheduler.handleSettingsChange(
        selectedDate: _selectedDate,
        prayerTimes: _times,
        tomorrowPrayerTimes: _computeTomorrowPrayerTimes(),
        jamaatTimes: _jamaatTimes,
        jamaatLocation: _jamaatLocation,
        currentPlaceName: _currentPlaceName,
        locationConfig: _locationConfig,
      );
      if (_isDisposed) return;
      _updateHomeWidget();
    });
  }

  Future<bool> hydrateFromCache() {
    return _hydrateFuture ??= _hydrateFromCache();
  }

  Future<bool> _hydrateFromCache() async {
    if (_isDisposed) {
      return false;
    }
    final startupState = await _resolveStartupState();
    if (_isDisposed) return false;

    _applyStartupState(startupState);
    _computePrayerTableData();

    final cached = await _prayerTimeCache.read(startupState.cacheKey);
    if (_isDisposed) return false;
    if (cached == null) {
      _notify();
      return false;
    }

    _times = Map<String, DateTime?>.from(cached.times);
    _jamaatTimes = cached.jamaatTimes == null
        ? null
        : Map<String, dynamic>.from(cached.jamaatTimes!);
    _lastJamaatUpdate = cached.lastJamaatUpdate;
    _hydratedTimes = Map<String, DateTime?>.from(_times);
    _hydratedJamaatTimes = _jamaatTimes == null
        ? null
        : Map<String, dynamic>.from(_jamaatTimes!);
    _hydratedFromCache = true;

    // Mirror hydrated jamaat times into JamaatScheduleCache so the scheduler
    // has data even when no fetch / localOffset path runs this session.
    if (_jamaatTimes != null) {
      await _jamaatScheduleCacheWriter.writeForDate(
        date: _selectedDate,
        jamaatTimes: _jamaatTimes!,
      );
      if (_isDisposed) return false;
    }

    final config = _locationConfig;
    final params = _params;
    if (config == null || params == null) {
      _notify();
      return _hydratedFromCache;
    }
    final coords = _coords ?? Coordinates(config.latitude, config.longitude);
    _prayerTimes = PrayerTimes(
      coordinates: coords,
      date: _selectedDate,
      calculationParameters: params,
      precision: true,
    );
    _computePrayerTableData();
    _notify();
    return true;
  }

  Future<_HomeStartupState> _resolveStartupState() async {
    // Phase 1: prayer state and Jamaat state are read independently from
    // their own keys. Old keys (selected_city, is_gps_mode, last_latitude/
    // longitude) are intentionally not read — this is a fresh-start migration.
    final prayerLocation = await _settingsService.getPrayerLocation();
    final jamaatLocation = await _settingsService.getJamaatLocation();
    final madhab = await _settingsService.getMadhab();
    final hijriOffset = await _settingsService.getBangladeshHijriOffsetDays();

    LocationConfig? locationConfig;
    Coordinates? coordinates;
    String? currentPlaceName;

    if (prayerLocation != null) {
      locationConfig = prayerLocation.toLocationConfig();
      coordinates =
          Coordinates(prayerLocation.latitude, prayerLocation.longitude);
      currentPlaceName = prayerLocation.locationName;
    }

    return _HomeStartupState(
      prayerLocation: prayerLocation,
      jamaatLocation: jamaatLocation,
      locationConfig: locationConfig,
      coordinates: coordinates,
      currentPlaceName: currentPlaceName,
      madhab: madhab,
      bangladeshHijriOffsetDays: hijriOffset,
      cacheKey: _buildCacheKey(
        locationConfig: locationConfig,
        jamaatLocation: jamaatLocation,
        coordinates: coordinates,
        currentPlaceName: currentPlaceName,
        madhab: madhab,
        isGpsMode: prayerLocation?.mode == PrayerLocationMode.gps,
      ),
    );
  }

  void _applyStartupState(_HomeStartupState state) {
    _prayerLocation = state.prayerLocation;
    _jamaatLocation = state.jamaatLocation;
    _locationConfig = state.locationConfig;
    _coords = state.coordinates;
    _currentPlaceName = state.currentPlaceName;
    _madhab = state.madhab;
    _bangladeshHijriOffsetDays = state.bangladeshHijriOffsetDays;

    final config = _locationConfig;
    if (config != null) {
      _locationConfigService.setCurrentConfig(config);
      _notificationService.setLocationConfig(config);
      _params = PrayerTimeEngine.instance.getCalculationParametersForConfig(
        config,
      );
      if (config.country == Country.bangladesh) {
        _params!.madhab = _madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
      }
    } else {
      _params = null;
    }
  }

  PrayerTimeCacheKey _buildCurrentCacheKey() {
    final config = _locationConfig;
    if (config == null) {
      return const PrayerTimeCacheKey(<String, String>{});
    }
    return _buildCacheKey(
      locationConfig: config,
      jamaatLocation: _jamaatLocation,
      coordinates: _coords,
      currentPlaceName: _currentPlaceName,
      madhab: _madhab,
      isGpsMode: _prayerLocation?.mode == PrayerLocationMode.gps,
    );
  }

  PrayerTimeCacheKey _buildCacheKey({
    required LocationConfig? locationConfig,
    required JamaatLocation jamaatLocation,
    required Coordinates? coordinates,
    required String? currentPlaceName,
    required String madhab,
    required bool isGpsMode,
  }) {
    if (locationConfig == null) {
      return const PrayerTimeCacheKey(<String, String>{});
    }
    final coordinateSource =
        coordinates ??
        Coordinates(locationConfig.latitude, locationConfig.longitude);
    return PrayerTimeCacheKey({
      'date': _formatCacheDate(_selectedDate),
      'mode': isGpsMode ? 'gps' : 'city',
      'city': locationConfig.cityName,
      'placeName': currentPlaceName ?? '',
      'lat': coordinateSource.latitude.toStringAsFixed(6),
      'lng': coordinateSource.longitude.toStringAsFixed(6),
      'timezone': locationConfig.timezone,
      'method': locationConfig.calculationMethodType.name,
      'madhab': madhab,
      'jamaatSource': jamaatLocation.source.name,
      'jamaatCity': jamaatLocation.city ?? '',
    });
  }

  String _formatCacheDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  void _writeCache() {
    if (_times.isEmpty || _locationConfig == null) {
      return;
    }
    unawaited(
      _prayerTimeCache.write(
        HomeCachedState(
          cacheKey: _buildCurrentCacheKey(),
          times: Map<String, DateTime?>.from(_times),
          jamaatTimes: _jamaatTimes == null
              ? null
              : Map<String, dynamic>.from(_jamaatTimes!),
          lastJamaatUpdate: _lastJamaatUpdate,
        ),
      ),
    );
  }

  bool _dateTimeMapsEqual(
    Map<String, DateTime?>? a,
    Map<String, DateTime?>? b,
  ) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key]?.millisecondsSinceEpoch !=
          entry.value?.millisecondsSinceEpoch) {
        return false;
      }
    }
    return true;
  }

  bool _dynamicMapsEqual(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key]?.toString() != entry.value?.toString()) {
        return false;
      }
    }
    return true;
  }

  void setHomeActive(bool isActive) {
    if (_isDisposed) {
      return;
    }
    if (_isHomeActive == isActive) {
      return;
    }
    _isHomeActive = isActive;
    _syncHomeTimer();
    if (shouldRunHomeTimer) {
      _handleHomeMinuteTick();
    }
    _notify();
  }

  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) {
      return;
    }
    final wasActive = _appLifecycleActive;
    _appLifecycleActive = state == AppLifecycleState.resumed;
    if (wasActive != _appLifecycleActive) {
      _syncHomeTimer();
      if (shouldRunHomeTimer) {
        _handleHomeMinuteTick();
      }
      _notify();
    }
  }

  /// User picked a Jamaat mosque (server-mosque source). Writes only Jamaat
  /// state; prayer location/coordinates are unaffected.
  Future<void> selectJamaatMosque(String value) async {
    if (_isDisposed) {
      return;
    }
    if (value == _jamaatLocation.city &&
        _jamaatLocation.source == JamaatSource.serverMosque) {
      return;
    }

    // Switching Jamaat target invalidates the in-memory Jamaat snapshot so
    // stale times from the previous city don't survive into reminders/widget.
    _jamaatLocation = JamaatLocation(
      source: JamaatSource.serverMosque,
      city: value,
      locationName: value,
    );
    _jamaatTimes = null;
    _jamaatError = null;
    _notify();

    await _settingsService.setJamaatLocation(_jamaatLocation);
    if (_isDisposed) return;

    _notificationScheduler.invalidate();
    await fetchJamaatTimes(value);
  }

  /// Backwards-compatible alias kept for the existing dropdown UI. Treats the
  /// chosen city as a Jamaat selection only — it never moves the prayer-time
  /// location, which is GPS-driven.
  Future<void> selectCity(String value) => selectJamaatMosque(value);

  /// Switch Jamaat source to Local Mosque. Writes only Jamaat state and
  /// triggers a recompute from the local CSV + per-date overrides.
  Future<void> selectLocalMosque() async {
    if (_isDisposed) return;
    if (_jamaatLocation.source == JamaatSource.local) return;

    _jamaatLocation = const JamaatLocation(source: JamaatSource.local);
    _jamaatTimes = null;
    _jamaatError = null;
    _notify();

    await _settingsService.setJamaatLocation(_jamaatLocation);
    if (_isDisposed) return;

    _notificationScheduler.invalidate();
    await refreshLocalJamaatTimes();
  }

  Future<void> refreshJamaatTimes() async {
    if (_isDisposed) {
      return;
    }
    if (_jamaatLocation.source == JamaatSource.local) {
      await refreshLocalJamaatTimes();
      updatePrayerTimes();
      return;
    }
    final city = _jamaatLocation.city;
    if (city == null || _jamaatLocation.source != JamaatSource.serverMosque) {
      return;
    }
    await fetchJamaatTimes(city, forceRefresh: true);
    updatePrayerTimes();
  }

  /// Resolve effective Local Mosque Jamaat times (override > CSV default) for
  /// today and tomorrow, mirror them into the schedule cache, and re-arm
  /// reminders. Maghrib stays calculated downstream from prayer Maghrib +
  /// cantt offset (handled by PrayerAuxCalculator).
  Future<void> refreshLocalJamaatTimes({bool preserveExisting = false}) async {
    if (_isDisposed) return;
    if (_jamaatLocation.source != JamaatSource.local) return;

    final showLoading = !preserveExisting || _jamaatTimes == null;
    _isLoadingJamaat = showLoading;
    _jamaatError = null;
    if (!preserveExisting) {
      _jamaatTimes = null;
    }
    if (showLoading) _notify();

    try {
      final todayTimes =
          await _localJamaatService.getEffectiveTimesForDate(_selectedDate);
      if (_isDisposed) return;

      if (todayTimes == null) {
        if (!preserveExisting) _jamaatTimes = null;
        _isLoadingJamaat = false;
        _computePrayerTableData();
        if (showLoading) _notify();
        _writeCache();
        _notificationScheduler.invalidate();
        unawaited(_scheduleNotificationsIfNeeded());
        return;
      }

      final completeJamaatTimes = todayTimes.toJamaatMap();
      // Maghrib still derives from the prayer Maghrib + cantt offset. With no
      // mosque city in Local mode, the calculator returns '-' and the table
      // hides the value — matches the documented "Maghrib is calculated, not
      // edited from the local CSV/settings page" rule.
      final maghribJamaatTime = PrayerAuxCalculator.instance
          .calculateMaghribJamaatTime(
        maghribPrayerTime: _times['Maghrib'],
        selectedCity: _jamaatLocation.city,
      );
      if (maghribJamaatTime != '-') {
        completeJamaatTimes['maghrib'] = maghribJamaatTime;
      }

      _jamaatTimes = completeJamaatTimes;
      _lastJamaatUpdate = DateTime.now();
      _isLoadingJamaat = false;
      _computePrayerTableData();
      _notify();
      _writeCache();

      await _jamaatScheduleCacheWriter.writeForDate(
        date: _selectedDate,
        jamaatTimes: completeJamaatTimes,
      );

      // Prefetch tomorrow so reminders cover the day rollover window.
      final tomorrow = _selectedDate.add(const Duration(days: 1));
      final tomorrowTimes =
          await _localJamaatService.getEffectiveTimesForDate(tomorrow);
      if (_isDisposed) return;
      Map<String, dynamic>? tomorrowJamaat;
      if (tomorrowTimes != null) {
        tomorrowJamaat = tomorrowTimes.toJamaatMap();
        final tomorrowMaghribPrayer = _computeTomorrowPrayerTimes()?['Maghrib'];
        final tomorrowMaghribJamaat = PrayerAuxCalculator.instance
            .calculateMaghribJamaatTime(
          maghribPrayerTime: tomorrowMaghribPrayer,
          selectedCity: _jamaatLocation.city,
        );
        if (tomorrowMaghribJamaat != '-') {
          tomorrowJamaat['maghrib'] = tomorrowMaghribJamaat;
        }
        await _jamaatScheduleCacheWriter.writeForDate(
          date: tomorrow,
          jamaatTimes: tomorrowJamaat,
        );
        if (_isDisposed) return;
      }

      _notificationScheduler.invalidate();
      unawaited(
        _scheduleNotificationsIfNeeded(tomorrowJamaatTimes: tomorrowJamaat),
      );
    } catch (_) {
      if (_isDisposed) return;
      _isLoadingJamaat = false;
      _jamaatError = _trCurrent(
        'লোকাল জামাত সময় লোড করতে সমস্যা হয়েছে',
        'Failed to load Local Mosque jamaat times',
      );
      _computePrayerTableData();
      if (showLoading) _notify();
    }
  }

  Future<HomeLocationFetchResult?> fetchUserLocation() async {
    if (_isDisposed) {
      return null;
    }
    if (_isFetchingPlaceName) {
      return null;
    }

    _coords = null;
    _isFetchingPlaceName = true;
    _currentPlaceName = null;
    _notify();

    try {
      final position = await _locationService.getCurrentPosition();
      if (_isDisposed) return null;
      _coords = Coordinates(position.latitude, position.longitude);

      final place = await _locationService.getPlaceName(
        position.latitude,
        position.longitude,
      );
      if (_isDisposed) return null;
      final country = _locationConfigService.detectCountryFromCoordinates(
        position.latitude,
        position.longitude,
      );

      LocationConfig newConfig;
      if (country == Country.saudiArabia) {
        final nearestCity = _locationConfigService.getNearestSaudiCity(
          position.latitude,
          position.longitude,
        );
        newConfig = nearestCity != null
            ? _locationConfigService.getConfigForCity(nearestCity)
            : LocationConfig.world(
                place ?? 'Current Location',
                position.latitude,
                position.longitude,
              );
      } else if (country == Country.bangladesh) {
        // Bangladesh GPS uses the Bangladesh prayer calc method/timezone but
        // keeps the user's actual GPS coordinates (no Savar fallback).
        newConfig = LocationConfig(
          cityName: place ?? 'Current Location',
          country: Country.bangladesh,
          timezone: 'Asia/Dhaka',
          calculationMethodType:
              PrayerCalculationMethodType.muslimWorldLeague,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      } else {
        newConfig = LocationConfig.world(
          place ?? 'Current Location',
          position.latitude,
          position.longitude,
        );
      }

      _locationConfig = newConfig;
      _locationConfigService.setCurrentConfig(newConfig);
      _notificationService.setLocationConfig(newConfig);
      _params = PrayerTimeEngine.instance.getCalculationParametersForConfig(
        newConfig,
      );
      if (newConfig.country == Country.bangladesh) {
        final madhab = await _settingsService.getMadhab();
        if (_isDisposed) return null;
        _madhab = madhab;
        _params!.madhab = madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
      }

      // Persist prayer location only — never touches Jamaat state.
      _prayerLocation = PrayerLocation(
        mode: PrayerLocationMode.gps,
        latitude: position.latitude,
        longitude: position.longitude,
        locationName: place ?? 'Current Location',
        timezone: newConfig.timezone,
        country: newConfig.country,
        calculationMethodType: newConfig.calculationMethodType,
      );
      await _settingsService.setPrayerLocation(_prayerLocation!);
      if (_isDisposed) return null;

      _currentPlaceName = place;
      _isFetchingPlaceName = false;
      updatePrayerTimes();
      _computePrayerTableData();
      _notify();

      return HomeLocationFetchResult.success(
        latitude: position.latitude,
        longitude: position.longitude,
        placeName: place,
      );
    } catch (error) {
      if (error.toString().contains('permission')) {
        await _locationService.openLocationSettings();
      }

      // On failure, fall back to whatever PrayerLocation was already saved.
      final saved = _prayerLocation;
      _isFetchingPlaceName = false;
      if (saved != null) {
        _coords = Coordinates(saved.latitude, saved.longitude);
        if (_currentPlaceName == null || _currentPlaceName!.isEmpty) {
          _currentPlaceName = saved.locationName;
        }
        updatePrayerTimes();
      }
      _computePrayerTableData();
      _notify();

      return HomeLocationFetchResult.error(error);
    }
  }

  Future<void> fetchJamaatTimes(
    String city, {
    bool forceRefresh = false,
    bool preserveExisting = false,
  }) async {
    if (_isDisposed) {
      return;
    }
    final previousJamaatTimes = _jamaatTimes == null
        ? null
        : Map<String, dynamic>.from(_jamaatTimes!);
    final showLoading = !preserveExisting || _jamaatTimes == null;
    _isLoadingJamaat = showLoading;
    _jamaatError = null;
    if (!preserveExisting) {
      _jamaatTimes = null;
    }
    if (showLoading) {
      _notify();
    }

    try {
      final times = await _jamaatService.getJamaatTimes(
        city: city,
        date: _selectedDate,
        forceRefresh: forceRefresh,
      );
      if (_isDisposed) return;

      if (times != null) {
        final completeJamaatTimes = Map<String, dynamic>.from(times);
        final maghribJamaatTime = PrayerAuxCalculator.instance
            .calculateMaghribJamaatTime(
              maghribPrayerTime: _times['Maghrib'],
              selectedCity: _jamaatLocation.city,
            );
        if (maghribJamaatTime != '-') {
          completeJamaatTimes['maghrib'] = maghribJamaatTime;
        }

        _jamaatTimes = completeJamaatTimes;
        _lastJamaatUpdate = DateTime.now();
        _isLoadingJamaat = false;
        _computePrayerTableData();
        if (showLoading ||
            !_dynamicMapsEqual(_jamaatTimes, previousJamaatTimes)) {
          _notify();
        }
        _writeCache();

        await _jamaatScheduleCacheWriter.writeForDate(
          date: _selectedDate,
          jamaatTimes: completeJamaatTimes,
        );
        unawaited(_fetchAndCacheTomorrowJamaat(city));

        _notificationScheduler.invalidate();
        unawaited(_scheduleNotificationsIfNeeded());
      } else {
        if (!preserveExisting) {
          _jamaatTimes = null;
        }
        _isLoadingJamaat = false;
        _computePrayerTableData();
        if (showLoading) {
          _notify();
        }
        _writeCache();

        // Transient Firestore miss: if we still have in-memory jamaat times
        // (preserveExisting kept them), mirror them into JamaatScheduleCache
        // before scheduling so today's reminders still arm.
        if (_jamaatTimes != null) {
          await _jamaatScheduleCacheWriter.writeForDate(
            date: _selectedDate,
            jamaatTimes: _jamaatTimes!,
          );
          if (_isDisposed) return;
        }

        _notificationScheduler.invalidate();
        unawaited(_scheduleNotificationsIfNeeded());
      }
    } catch (_) {
      if (_isDisposed) {
        return;
      }
      if (!preserveExisting) {
        _jamaatTimes = null;
      }
      _isLoadingJamaat = false;
      _jamaatError = _trCurrent(
        'জামাত সময় লোড করতে সমস্যা হয়েছে',
        'Failed to load jamaat times',
      );
      _computePrayerTableData();
      if (showLoading) {
        _notify();
      }

      _notificationScheduler.invalidate();
      unawaited(_scheduleNotificationsIfNeeded());
    }
  }

  void updatePrayerTimes({
    bool notify = true,
    bool scheduleNotifications = true,
    bool writeCache = true,
  }) {
    if (_isDisposed) {
      return;
    }
    if (_params == null) {
      return;
    }

    final config = _locationConfig;
    if (config == null) {
      // No prayer location set yet — nothing to compute. UI shows empty state.
      return;
    }
    final coords =
        _coords ?? Coordinates(config.latitude, config.longitude);

    _prayerTimes = PrayerTimes(
      coordinates: coords,
      date: _selectedDate,
      calculationParameters: _params!,
      precision: true,
    );
    _times = PrayerTimeEngine.instance.createPrayerTimesMap(_prayerTimes!);

    if (_jamaatTimes != null) {
      final updatedJamaatTimes = Map<String, dynamic>.from(_jamaatTimes!);
      final maghribJamaatTime = PrayerAuxCalculator.instance
          .calculateMaghribJamaatTime(
            maghribPrayerTime: _times['Maghrib'],
            selectedCity: _jamaatLocation.city,
          );
      if (maghribJamaatTime != '-') {
        updatedJamaatTimes['maghrib'] = maghribJamaatTime;
      }
      _jamaatTimes = updatedJamaatTimes;
    }

    if (scheduleNotifications) {
      // Mirror the (possibly recomputed) jamaat times into the schedule cache
      // before kicking the scheduler, so day-rollover and Maghrib-recompute
      // flows don't leave the cache stale.
      final jamaatSnapshot = _jamaatTimes;
      if (jamaatSnapshot != null) {
        unawaited(
          _jamaatScheduleCacheWriter
              .writeForDate(date: _selectedDate, jamaatTimes: jamaatSnapshot)
              .then((_) {
                if (_isDisposed) return;
                _notificationScheduler.invalidate();
                unawaited(_scheduleNotificationsIfNeeded());
              }),
        );
      } else {
        _notificationScheduler.invalidate();
        unawaited(_scheduleNotificationsIfNeeded());
      }
    }
    _computePrayerTableData();
    if (notify) {
      _notify();
    }
    if (writeCache) {
      _writeCache();
    }
  }

  void _syncHomeTimer() {
    if (!shouldRunHomeTimer) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_timer?.isActive ?? false) {
      return;
    }
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (shouldRunHomeTimer) {
        _handleHomeMinuteTick();
      }
    });
  }

  void _handleHomeMinuteTick() {
    final newNow = DateTime.now();
    final oldDay = DateTime(_now.year, _now.month, _now.day);
    final newDay = DateTime(newNow.year, newNow.month, newNow.day);

    if (newDay.isAfter(oldDay)) {
      _now = newNow;
      _selectedDate = newNow;
      updatePrayerTimes();
      if (_jamaatLocation.hasServerMosque) {
        unawaited(fetchJamaatTimes(_jamaatLocation.city!));
      } else if (_jamaatLocation.source == JamaatSource.local) {
        unawaited(refreshLocalJamaatTimes());
      }
    } else if (_times.isNotEmpty) {
      final newPeriod = PrayerTimeEngine.instance.getCurrentPrayerPeriod(
        times: _times,
        now: newNow,
      );
      if (newPeriod != _lastCurrentPeriod) {
        _now = newNow;
        _computePrayerTableData();
        _notify();
      }
    }
    _now = newNow;
    _nowNotifier.value = newNow;
  }

  Future<void> _loadMadhab() async {
    if (_locationConfig == null ||
        _locationConfig!.country != Country.bangladesh ||
        _params == null) {
      return;
    }

    final madhab = await _settingsService.getMadhab();
    if (_isDisposed) return;
    _madhab = madhab;
    _params!.madhab = madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    if (madhab == 'hanafi') {
      _params!.adjustments = Map.from(AppConstants.defaultAdjustments);
    } else {
      _params!.adjustments = {'asr': 0, 'isha': 2};
    }
    updatePrayerTimes();
  }

  Future<void> _loadBangladeshHijriOffset() async {
    final offset = await _settingsService.getBangladeshHijriOffsetDays();
    if (_isDisposed) {
      return;
    }
    _bangladeshHijriOffsetDays = offset;
    _notify();
  }

  Future<void> _scheduleNotificationsIfNeeded({
    Map<String, dynamic>? tomorrowJamaatTimes,
  }) {
    return _notificationScheduler.scheduleIfNeeded(
      selectedDate: _selectedDate,
      prayerTimes: _times,
      tomorrowPrayerTimes: _computeTomorrowPrayerTimes(),
      jamaatTimes: _jamaatTimes,
      tomorrowJamaatTimes: tomorrowJamaatTimes,
      jamaatLocation: _jamaatLocation,
      currentPlaceName: _currentPlaceName,
      locationConfig: _locationConfig,
    );
  }

  Map<String, DateTime?>? _computeTomorrowPrayerTimes() {
    if (_params == null || _locationConfig == null) return null;
    final coords =
        _coords ??
        Coordinates(_locationConfig!.latitude, _locationConfig!.longitude);
    try {
      final tomorrow = _selectedDate.add(const Duration(days: 1));
      final tomorrowPrayer = PrayerTimes(
        coordinates: coords,
        date: tomorrow,
        calculationParameters: _params!,
        precision: true,
      );
      return PrayerTimeEngine.instance.createPrayerTimesMap(tomorrowPrayer);
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchAndCacheTomorrowJamaat(String city) async {
    try {
      final tomorrow = _selectedDate.add(const Duration(days: 1));
      final times = await _jamaatService.getJamaatTimes(
        city: city,
        date: tomorrow,
      );
      if (_isDisposed || times == null) return;
      final complete = Map<String, dynamic>.from(times);
      final tomorrowMaghribPrayer = _computeTomorrowPrayerTimes()?['Maghrib'];
      final tomorrowMaghribJamaat = PrayerAuxCalculator.instance
          .calculateMaghribJamaatTime(
            maghribPrayerTime: tomorrowMaghribPrayer,
            selectedCity: _jamaatLocation.city,
          );
      if (tomorrowMaghribJamaat != '-') {
        complete['maghrib'] = tomorrowMaghribJamaat;
      }
      final wroteCache = await _jamaatScheduleCacheWriter.writeForDate(
        date: tomorrow,
        jamaatTimes: complete,
      );
      if (_isDisposed || !wroteCache) return;
      _notificationScheduler.invalidate();
      unawaited(_scheduleNotificationsIfNeeded(tomorrowJamaatTimes: complete));
    } catch (_) {
      // Best-effort prefetch.
    }
  }

  String _getCurrentPrayerName() {
    final now = DateTime.now();
    final selectedDateOnly = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final todayOnly = DateTime(now.year, now.month, now.day);

    if (selectedDateOnly.isBefore(todayOnly)) {
      return 'Isha';
    } else if (selectedDateOnly.isAfter(todayOnly)) {
      return 'Fajr';
    } else {
      final current = _prayerTimes?.currentPrayer(date: _now);
      if (current == Prayer.fajr) return 'Fajr';
      if (current == Prayer.sunrise) return 'Sunrise';
      if (current == Prayer.dhuhr) return 'Dhuhr';
      if (current == Prayer.asr) return 'Asr';
      if (current == Prayer.maghrib) return 'Maghrib';
      if (current == Prayer.isha) return 'Isha';
      return 'Fajr';
    }
  }

  void _computePrayerTableData() {
    final currentPrayer = _getCurrentPrayerName();
    final tableData = <PrayerRowData>[];
    const prayerNames = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    for (final name in prayerNames) {
      final prayerTime = _times[name];
      final timeStr = prayerTime != null
          ? DateFormat('HH:mm').format(prayerTime.toLocal())
          : '-';

      final type = name == 'Sunrise'
          ? PrayerRowType.info
          : PrayerRowType.prayer;
      final jamaatKey = switch (name) {
        'Fajr' => 'fajr',
        'Dhuhr' => 'dhuhr',
        'Asr' => 'asr',
        'Maghrib' => 'maghrib',
        'Isha' => 'isha',
        _ => name.toLowerCase(),
      };

      var jamaatStr = '-';
      if (name == 'Maghrib') {
        jamaatStr = PrayerAuxCalculator.instance.calculateMaghribJamaatTime(
          maghribPrayerTime: _times['Maghrib'],
          selectedCity: _jamaatLocation.city,
        );
      } else if (_jamaatTimes != null && _jamaatTimes!.containsKey(jamaatKey)) {
        final value = _jamaatTimes![jamaatKey];
        if (value != null && value.toString().isNotEmpty) {
          jamaatStr = PrayerAuxCalculator.instance.formatJamaatTime(
            value.toString(),
          );
        }
      }

      tableData.add(
        PrayerRowData(
          name: name,
          timeStr: timeStr,
          jamaatStr: jamaatStr,
          isCurrent: name == currentPrayer,
          type: type,
        ),
      );
    }

    _prayerTableData = tableData;
    if (_times.isNotEmpty) {
      _lastCurrentPeriod = PrayerTimeEngine.instance.getCurrentPrayerPeriod(
        times: _times,
        now: DateTime.now(),
      );
    }
    _updateHomeWidget();
  }

  void _updateHomeWidget() {
    _widgetSync.update(
      times: _times,
      selectedDate: _selectedDate,
      locationConfig: _locationConfig,
      jamaatLocation: _jamaatLocation,
      calculationParameters: _params,
      coordinates: _coords,
      currentPlaceName: _currentPlaceName,
      bangladeshHijriOffsetDays: _bangladeshHijriOffsetDays,
      jamaatTimes: _jamaatTimes,
    );
  }

  bool get _isEnglishCurrent =>
      AppLocaleController.instance.current.languageCode == 'en';

  String _trCurrent(String bn, String en) => _isEnglishCurrent ? en : bn;

  void _notify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _settingsSubscription?.cancel();
    _nowNotifier.dispose();
    super.dispose();
  }
}
