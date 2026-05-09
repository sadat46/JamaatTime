import 'package:timezone/data/latest.dart' as tzdata;

bool _initialized = false;

void ensureTimeZonesInitialized() {
  if (_initialized) {
    return;
  }
  tzdata.initializeTimeZones();
  _initialized = true;
}
