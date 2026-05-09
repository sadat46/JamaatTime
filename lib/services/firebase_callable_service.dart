import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/firebase_bootstrap.dart';

typedef FirebaseCallablePluginCaller =
    Future<Map<String, dynamic>> Function(
      String name,
      Map<String, dynamic> data,
      String region,
    );

typedef FirebaseIdTokenProvider = Future<String?> Function();

class FirebaseCallableException implements Exception {
  const FirebaseCallableException({
    required this.code,
    this.message,
    this.details,
  });

  final String code;
  final String? message;
  final Object? details;

  String get displayMessage {
    final trimmed = message?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return code;
    }
    return '$code $trimmed';
  }

  @override
  String toString() => displayMessage;
}

class FirebaseCallableService {
  FirebaseCallableService({
    http.Client? httpClient,
    FirebaseIdTokenProvider? idTokenProvider,
    FirebaseCallablePluginCaller? pluginCaller,
    TargetPlatform? targetPlatformOverride,
    bool? isWebOverride,
    this.projectId = 'jaamattime',
  }) : _httpClient = httpClient ?? http.Client(),
       _idTokenProvider =
           idTokenProvider ??
           (() async {
             final user = FirebaseAuth.instance.currentUser;
             return user?.getIdToken();
           }),
       _pluginCaller = pluginCaller ?? _callWithPlugin,
       _targetPlatformOverride = targetPlatformOverride,
       _isWebOverride = isWebOverride;

  final http.Client _httpClient;
  final FirebaseIdTokenProvider _idTokenProvider;
  final FirebaseCallablePluginCaller _pluginCaller;
  final TargetPlatform? _targetPlatformOverride;
  final bool? _isWebOverride;
  final String projectId;

  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const <String, dynamic>{},
    String region = 'us-central1',
  ]) async {
    if (!await firebaseReady) {
      throw const FirebaseCallableException(
        code: 'unavailable',
        message: 'Firebase is not initialized.',
      );
    }
    if (_usesWindowsHttpFallback) {
      return _callWithWindowsHttp(name, data, region);
    }
    try {
      return await _pluginCaller(name, data, region);
    } on FirebaseFunctionsException catch (e) {
      throw FirebaseCallableException(
        code: e.code,
        message: e.message,
        details: e.details,
      );
    }
  }

  bool get _usesWindowsHttpFallback {
    final isWeb = _isWebOverride ?? kIsWeb;
    final targetPlatform = _targetPlatformOverride ?? defaultTargetPlatform;
    return !isWeb && targetPlatform == TargetPlatform.windows;
  }

  Future<Map<String, dynamic>> _callWithWindowsHttp(
    String name,
    Map<String, dynamic> data,
    String region,
  ) async {
    final token = await _idTokenProvider();
    if (token == null || token.isEmpty) {
      throw const FirebaseCallableException(
        code: 'unauthenticated',
        message: 'Sign-in required.',
      );
    }

    final response = await _httpClient.post(
      Uri.parse('https://$region-$projectId.cloudfunctions.net/$name'),
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{'data': data}),
    );

    final decoded = _decodeResponse(response.body);
    final error = decoded['error'];
    if (error is Map) {
      throw FirebaseCallableException(
        code: _callableStatusToCode(error['status']?.toString()),
        message: error['message']?.toString(),
        details: error['details'],
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FirebaseCallableException(
        code: 'internal',
        message: 'Callable $name failed (${response.statusCode}).',
      );
    }

    return _normalizeResult(decoded['result']);
  }

  static Map<String, dynamic> _decodeResponse(String body) {
    if (body.isEmpty) {
      return const <String, dynamic>{};
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException catch (e) {
      throw FirebaseCallableException(
        code: 'internal',
        message: 'Callable response was not valid JSON: ${e.message}',
      );
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw const FirebaseCallableException(
      code: 'internal',
      message: 'Callable response was not a JSON object.',
    );
  }

  static Future<Map<String, dynamic>> _callWithPlugin(
    String name,
    Map<String, dynamic> data,
    String region,
  ) async {
    final callable = FirebaseFunctions.instanceFor(
      region: region,
    ).httpsCallable(name);
    final response = await callable.call<Object?>(data);
    return _normalizeResult(response.data);
  }

  static Map<String, dynamic> _normalizeResult(Object? value) {
    if (value == null) {
      return <String, dynamic>{};
    }
    if (value is Map) {
      return value.map((key, dynamic data) => MapEntry(key.toString(), data));
    }
    return <String, dynamic>{'result': value};
  }

  static String _callableStatusToCode(String? status) {
    switch (status) {
      case 'CANCELLED':
        return 'cancelled';
      case 'INVALID_ARGUMENT':
        return 'invalid-argument';
      case 'DEADLINE_EXCEEDED':
        return 'deadline-exceeded';
      case 'NOT_FOUND':
        return 'not-found';
      case 'ALREADY_EXISTS':
        return 'already-exists';
      case 'PERMISSION_DENIED':
        return 'permission-denied';
      case 'RESOURCE_EXHAUSTED':
        return 'resource-exhausted';
      case 'FAILED_PRECONDITION':
        return 'failed-precondition';
      case 'ABORTED':
        return 'aborted';
      case 'OUT_OF_RANGE':
        return 'out-of-range';
      case 'UNIMPLEMENTED':
        return 'unimplemented';
      case 'INTERNAL':
        return 'internal';
      case 'UNAVAILABLE':
        return 'unavailable';
      case 'DATA_LOSS':
        return 'data-loss';
      case 'UNAUTHENTICATED':
        return 'unauthenticated';
      case 'UNKNOWN':
      default:
        return 'unknown';
    }
  }
}
