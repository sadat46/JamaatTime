import 'dart:async';

import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_locale_controller.dart';
import '../../core/constants.dart';
import '../../features/notice_board/data/notice_model.dart';
import '../../features/notice_board/data/notice_read_state_service.dart';
import '../../features/notice_board/data/notice_repository.dart';
import '../../models/location_config.dart';
import '../../services/jamaat_service.dart';
import '../../services/location_config_service.dart';
import '../../services/location_service.dart';
import '../../services/notifications/notification_service.dart';
import '../../services/notifications/reminders/jamaat_schedule_cache.dart';
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
    required this.selectedCity,
    required this.locationConfig,
    required this.coordinates,
    required this.currentPlaceName,
    required this.madhab,
    required this.bangladeshHijriOffsetDays,
    required this.cacheKey,
  });

  final String? selectedCity;
  final LocationConfig locationConfig;
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
       _prayerTimeCache = prayerTimeCache ?? PrayerTimeCache();

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
  String? _selectedCity;
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
  String? get selectedCity => _selectedCity;
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

    if (_locationConfig!.jamaatSource == JamaatSource.server &&
        _selectedCity != null) {
      await fetchJamaatTimes(_selectedCity!, preserveExisting: true);
      if (_isDisposed) return;
    } else if (_locationConfig!.jamaatSource == JamaatSource.localOffset) {
      calculateLocalJamaatTimes();
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
        selectedCity: _selectedCity,
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
      await _writeJamaatCacheForDate(_selectedDate, _jamaatTimes!);
      if (_isDisposed) return false;
    }

    final coords =
        _coords ??
        Coordinates(_locationConfig!.latitude, _locationConfig!.longitude);
    _prayerTimes = PrayerTimes(
      coordinates: coords,
      date: _selectedDate,
      calculationParameters: _params!,
      precision: true,
    );
    _computePrayerTableData();
    _notify();
    return true;
  }

  Future<_HomeStartupState> _resolveStartupState() async {
    final prefs = await SharedPreferences.getInstance();
    final isGpsMode = prefs.getBool('is_gps_mode') ?? false;
    final savedCity = prefs.getString('selected_city');
    final lastLat = prefs.getDouble('last_latitude');
    final lastLng = prefs.getDouble('last_longitude');
    final lastPlace = prefs.getString('last_location_name');
    final madhab = await _settingsService.getMadhab();
    final hijriOffset = await _settingsService.getBangladeshHijriOffsetDays();

    LocationConfig locationConfig;
    Coordinates? coordinates;
    String? selectedCity;
    String? currentPlaceName;

    if (isGpsMode && lastLat != null && lastLng != null) {
      currentPlaceName = (lastPlace != null && lastPlace.isNotEmpty)
          ? lastPlace
          : 'Current Location';
      locationConfig = LocationConfig.world(currentPlaceName, lastLat, lastLng);
      coordinates = Coordinates(lastLat, lastLng);
    } else {
      selectedCity = (savedCity != null && savedCity.isNotEmpty)
          ? savedCity
          : AppConstants.defaultCity;
      locationConfig = _locationConfigService.getConfigForCity(selectedCity);
      currentPlaceName = lastPlace;
    }

    return _HomeStartupState(
      selectedCity: selectedCity,
      locationConfig: locationConfig,
      coordinates: coordinates,
      currentPlaceName: currentPlaceName,
      madhab: madhab,
      bangladeshHijriOffsetDays: hijriOffset,
      cacheKey: _buildCacheKey(
        locationConfig: locationConfig,
        selectedCity: selectedCity,
        coordinates: coordinates,
        currentPlaceName: currentPlaceName,
        madhab: madhab,
        isGpsMode: isGpsMode && lastLat != null && lastLng != null,
      ),
    );
  }

  void _applyStartupState(_HomeStartupState state) {
    _selectedCity = state.selectedCity;
    _locationConfig = state.locationConfig;
    _coords = state.coordinates;
    _currentPlaceName = state.currentPlaceName;
    _madhab = state.madhab;
    _bangladeshHijriOffsetDays = state.bangladeshHijriOffsetDays;

    _locationConfigService.setCurrentConfig(_locationConfig!);
    _notificationService.setLocationConfig(_locationConfig!);
    _params = PrayerTimeEngine.instance.getCalculationParametersForConfig(
      _locationConfig!,
    );
    if (_locationConfig!.country == Country.bangladesh) {
      _params!.madhab = _madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    }
  }

  PrayerTimeCacheKey _buildCurrentCacheKey() {
    final config = _locationConfig;
    if (config == null) {
      return const PrayerTimeCacheKey(<String, String>{});
    }
    return _buildCacheKey(
      locationConfig: config,
      selectedCity: _selectedCity,
      coordinates: _coords,
      currentPlaceName: _currentPlaceName,
      madhab: _madhab,
      isGpsMode: _selectedCity == null,
    );
  }

  PrayerTimeCacheKey _buildCacheKey({
    required LocationConfig locationConfig,
    required String? selectedCity,
    required Coordinates? coordinates,
    required String? currentPlaceName,
    required String madhab,
    required bool isGpsMode,
  }) {
    final coordinateSource =
        coordinates ??
        Coordinates(locationConfig.latitude, locationConfig.longitude);
    return PrayerTimeCacheKey({
      'date': _formatCacheDate(_selectedDate),
      'mode': isGpsMode ? 'gps' : 'city',
      'city': locationConfig.cityName,
      'selectedCity': selectedCity ?? '',
      'placeName': currentPlaceName ?? '',
      'lat': coordinateSource.latitude.toStringAsFixed(6),
      'lng': coordinateSource.longitude.toStringAsFixed(6),
      'timezone': locationConfig.timezone,
      'method': locationConfig.calculationMethodType.name,
      'madhab': madhab,
      'jamaatSource': locationConfig.jamaatSource.name,
      'jamaatCity': selectedCity ?? '',
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

  Future<void> selectCity(String value) async {
    if (_isDisposed) {
      return;
    }
    if (value == _selectedCity) {
      return;
    }

    _selectedCity = value;
    _notify();

    final prefs = await SharedPreferences.getInstance();
    if (_isDisposed) return;
    await prefs.setBool('is_gps_mode', false);
    await prefs.setString('selected_city', value);

    _locationConfig = _locationConfigService.getConfigForCity(value);
    _locationConfigService.setCurrentConfig(_locationConfig!);
    _notificationService.setLocationConfig(_locationConfig!);

    _params = PrayerTimeEngine.instance.getCalculationParametersForConfig(
      _locationConfig!,
    );

    if (_locationConfig!.country == Country.bangladesh) {
      final madhab = await _settingsService.getMadhab();
      if (_isDisposed) return;
      _madhab = madhab;
      _params!.madhab = madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    }

    _notificationScheduler.invalidate();
    _coords = Coordinates(
      _locationConfig!.latitude,
      _locationConfig!.longitude,
    );
    updatePrayerTimes();

    if (_locationConfig!.jamaatSource == JamaatSource.server) {
      await fetchJamaatTimes(value);
    } else if (_locationConfig!.jamaatSource == JamaatSource.localOffset) {
      calculateLocalJamaatTimes();
    }
  }

  Future<void> refreshJamaatTimes() async {
    if (_isDisposed) {
      return;
    }
    if (_selectedCity == null) {
      return;
    }
    await fetchJamaatTimes(_selectedCity!, forceRefresh: true);
    updatePrayerTimes();
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

      final prefs = await SharedPreferences.getInstance();
      if (_isDisposed) return null;
      await prefs.setDouble('last_latitude', position.latitude);
      await prefs.setDouble('last_longitude', position.longitude);

      final place = await _locationService.getPlaceName(
        position.latitude,
        position.longitude,
      );
      if (_isDisposed) return null;
      final country = _locationConfigService.detectCountryFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (country == Country.other) {
        final placeName = place ?? 'Current Location';
        _locationConfig = LocationConfig.world(
          placeName,
          position.latitude,
          position.longitude,
        );
        _locationConfigService.setCurrentConfig(_locationConfig!);
        _notificationService.setLocationConfig(_locationConfig!);
        _params = PrayerTimeEngine.instance.getCalculationParametersForConfig(
          _locationConfig!,
        );
        _jamaatTimes = null;
        _jamaatError = null;
        _isLoadingJamaat = false;
        _selectedCity = null;
        await prefs.setBool('is_gps_mode', true);
        await prefs.remove('selected_city');
      } else if (country == Country.saudiArabia) {
        final nearestCity = _locationConfigService.getNearestSaudiCity(
          position.latitude,
          position.longitude,
        );

        if (nearestCity != null) {
          _selectedCity = nearestCity;
          _locationConfig = _locationConfigService.getConfigForCity(
            nearestCity,
          );
          _locationConfigService.setCurrentConfig(_locationConfig!);
          _notificationService.setLocationConfig(_locationConfig!);
          _params = PrayerTimeEngine.instance.getCalculationParametersForConfig(
            _locationConfig!,
          );
          calculateLocalJamaatTimes();
          await prefs.setBool('is_gps_mode', false);
          await prefs.setString('selected_city', nearestCity);
        }
      } else if (country == Country.bangladesh) {
        if (_locationConfig == null ||
            _locationConfig!.country != Country.bangladesh) {
          _selectedCity = AppConstants.defaultCity;
          _locationConfig = _locationConfigService.getConfigForCity(
            _selectedCity!,
          );
          _locationConfigService.setCurrentConfig(_locationConfig!);
          _notificationService.setLocationConfig(_locationConfig!);
          _params = PrayerTimeEngine.instance.getCalculationParametersForConfig(
            _locationConfig!,
          );

          final madhab = await _settingsService.getMadhab();
          if (_isDisposed) return null;
          _madhab = madhab;
          _params!.madhab = madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
          await fetchJamaatTimes(_selectedCity!);
          if (_isDisposed) return null;
        }
      }

      _currentPlaceName = place;
      _isFetchingPlaceName = false;
      updatePrayerTimes();
      _computePrayerTableData();
      _notify();

      if (place != null && place.isNotEmpty) {
        await prefs.setString('last_location_name', place);
      }

      return HomeLocationFetchResult.success(
        latitude: position.latitude,
        longitude: position.longitude,
        placeName: place,
      );
    } catch (error) {
      if (error.toString().contains('permission')) {
        await _locationService.openLocationSettings();
      }

      final prefs = await SharedPreferences.getInstance();
      if (_isDisposed) return HomeLocationFetchResult.error(error);
      final lastPlace = prefs.getString('last_location_name');
      final lastLat = prefs.getDouble('last_latitude');
      final lastLng = prefs.getDouble('last_longitude');

      _isFetchingPlaceName = false;
      if (lastLat != null && lastLng != null) {
        _coords = Coordinates(lastLat, lastLng);
        updatePrayerTimes();
      }
      if (lastPlace != null && lastPlace.isNotEmpty) {
        _currentPlaceName = lastPlace;
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
              selectedCity: _selectedCity,
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

        await _writeJamaatCacheForDate(_selectedDate, completeJamaatTimes);
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
          await _writeJamaatCacheForDate(_selectedDate, _jamaatTimes!);
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

  void calculateLocalJamaatTimes() {
    if (_isDisposed) {
      return;
    }
    if (_locationConfig == null || _locationConfig!.jamaatOffsets == null) {
      return;
    }

    final newJamaatTimes = _computeLocalOffsetJamaat(_times);

    _jamaatTimes = newJamaatTimes;
    _isLoadingJamaat = false;
    _jamaatError = null;
    _computePrayerTableData();
    _notify();
    _writeCache();

    unawaited(_persistLocalOffsetJamaatAndSchedule(newJamaatTimes));
  }

  Future<void> _persistLocalOffsetJamaatAndSchedule(
    Map<String, dynamic> newJamaatTimes,
  ) async {
    await _writeJamaatCacheForDate(_selectedDate, newJamaatTimes);
    if (_isDisposed) return;
    final tomorrowPrayers = _computeTomorrowPrayerTimes();
    if (tomorrowPrayers != null) {
      final tomorrowJamaat = _computeLocalOffsetJamaat(tomorrowPrayers);
      if (tomorrowJamaat.isNotEmpty) {
        await _writeJamaatCacheForDate(
          _selectedDate.add(const Duration(days: 1)),
          tomorrowJamaat,
        );
        if (_isDisposed) return;
      }
    }

    _notificationScheduler.invalidate();
    await _scheduleNotificationsIfNeeded();
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

    final coords =
        _coords ??
        (_locationConfig != null
            ? Coordinates(_locationConfig!.latitude, _locationConfig!.longitude)
            : Coordinates(
                AppConstants.defaultLatitude,
                AppConstants.defaultLongitude,
              ));

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
            selectedCity: _selectedCity,
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
          _writeJamaatCacheForDate(_selectedDate, jamaatSnapshot).then((_) {
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
      if (_locationConfig != null) {
        if (_locationConfig!.jamaatSource == JamaatSource.server &&
            _selectedCity != null) {
          unawaited(fetchJamaatTimes(_selectedCity!));
        } else if (_locationConfig!.jamaatSource == JamaatSource.localOffset) {
          // No _selectedCity guard: localOffset only needs jamaatOffsets, and
          // GPS-mode users have a null _selectedCity but still need their
          // reminders refreshed past midnight.
          calculateLocalJamaatTimes();
        }
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

  Future<void> _scheduleNotificationsIfNeeded() {
    return _notificationScheduler.scheduleIfNeeded(
      selectedDate: _selectedDate,
      prayerTimes: _times,
      tomorrowPrayerTimes: _computeTomorrowPrayerTimes(),
      jamaatTimes: _jamaatTimes,
      selectedCity: _selectedCity,
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

  Future<void> _writeJamaatCacheForDate(
    DateTime date,
    Map<String, dynamic> jamaatTimes,
  ) async {
    final stringified = <String, String>{};
    for (final entry in jamaatTimes.entries) {
      final value = entry.value;
      if (value == null) continue;
      final asString = value.toString();
      if (asString.isEmpty || asString == '-') continue;
      stringified[entry.key] = asString;
    }
    if (stringified.isEmpty) return;
    try {
      await JamaatScheduleCache.instance.write(
        date: date,
        times: stringified,
      );
    } catch (_) {
      // Cache write is best-effort; scheduling still proceeds.
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
            selectedCity: _selectedCity,
          );
      if (tomorrowMaghribJamaat != '-') {
        complete['maghrib'] = tomorrowMaghribJamaat;
      }
      await _writeJamaatCacheForDate(tomorrow, complete);
    } catch (_) {
      // Best-effort prefetch.
    }
  }

  Map<String, dynamic> _computeLocalOffsetJamaat(
    Map<String, DateTime?> prayerTimes,
  ) {
    final offsets = _locationConfig?.jamaatOffsets;
    final result = <String, dynamic>{};
    if (offsets == null) return result;
    const prayerMapping = {
      'fajr': 'Fajr',
      'dhuhr': 'Dhuhr',
      'asr': 'Asr',
      'maghrib': 'Maghrib',
      'isha': 'Isha',
    };
    for (final entry in offsets.entries) {
      final prayerKey = entry.key;
      final offset = entry.value;
      final prayerName = prayerMapping[prayerKey];
      if (prayerName == null) continue;
      final prayerTime = prayerTimes[prayerName];
      if (prayerTime == null) continue;
      final jamaatTime = prayerTime.add(Duration(minutes: offset));
      result[prayerKey] = DateFormat('HH:mm').format(jamaatTime.toLocal());
    }
    return result;
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
          selectedCity: _selectedCity,
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
