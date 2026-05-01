import 'package:flutter/services.dart';

class PrivateDnsState {
  const PrivateDnsState({
    required this.mode,
    this.host,
    this.supported = true,
    this.error,
  });

  factory PrivateDnsState.fromMap(Map<String, Object?> map) {
    final mode = map['mode'];
    final host = map['host'];
    return PrivateDnsState(
      mode: mode is String && mode.isNotEmpty ? mode : 'unknown',
      host: host is String && host.isNotEmpty ? host : null,
    );
  }

  factory PrivateDnsState.unsupported() {
    return const PrivateDnsState(mode: 'unsupported', supported: false);
  }

  factory PrivateDnsState.unavailable(String error) {
    return PrivateDnsState(mode: 'unknown', supported: false, error: error);
  }

  static const Set<String> knownDohProviders = <String>{
    '1dot1dot1dot1.cloudflare-dns.com',
    'cloudflare-dns.com',
    'dns.adguard.com',
    'dns.google',
    'dns.quad9.net',
    'doh.opendns.com',
    'family.cloudflare-dns.com',
    'one.one.one.one',
    'security.cloudflare-dns.com',
  };

  final String mode;
  final String? host;
  final bool supported;
  final String? error;

  bool get isHostnameMode => mode == 'hostname';

  bool get usesKnownDohProvider {
    final normalizedHost = host?.trim().toLowerCase();
    return isHostnameMode &&
        normalizedHost != null &&
        knownDohProviders.contains(normalizedHost);
  }
}

class FamilySafetyChannel {
  FamilySafetyChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'jamaat_time/family_safety';

  final MethodChannel _channel;

  Future<PrivateDnsState> getPrivateDnsState() async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'getPrivateDnsState',
      );
      return PrivateDnsState.fromMap(result ?? const <String, Object?>{});
    } on MissingPluginException {
      return PrivateDnsState.unsupported();
    } on PlatformException catch (error) {
      return PrivateDnsState.unavailable(error.message ?? error.code);
    }
  }

  Future<bool> openNetworkSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openNetworkSettings');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
