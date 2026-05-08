import 'dart:io' show Platform;

import 'package:flutter/services.dart';

class BatteryOptimizationService {
  static const MethodChannel _channel = MethodChannel(
    'jamaat_time/battery_optimization',
  );

  static bool get _supported => Platform.isAndroid;

  static Future<bool> isIgnoring() async {
    if (!_supported) return true;
    try {
      final value = await _channel.invokeMethod<bool>('isIgnoring');
      return value ?? false;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> requestExemption() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('requestExemption');
    } on MissingPluginException {
      // No-op on unsupported platforms.
    } on PlatformException {
      // Fall back silently — caller already shows a manual instruction.
    }
  }
}
