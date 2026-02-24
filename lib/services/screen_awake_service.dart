import 'package:flutter/services.dart';

class ScreenAwakeService {
  static const MethodChannel _channel = MethodChannel(
    'jamaat_time/screen_awake',
  );

  static Future<void> setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setKeepScreenOn', {
        'enabled': enabled,
      });
    } on MissingPluginException {
      // No-op on unsupported platforms.
    } on PlatformException {
      // No-op on platform channel failures.
    }
  }
}
