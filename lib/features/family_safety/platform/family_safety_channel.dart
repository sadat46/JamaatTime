import 'package:flutter/services.dart';

class FamilySafetyChannel {
  FamilySafetyChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'jamaat_time/family_safety';

  final MethodChannel _channel;

  Future<Map<String, Object?>> getPrivateDnsState() async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'getPrivateDnsState',
    );
    return result ?? const <String, Object?>{};
  }
}
