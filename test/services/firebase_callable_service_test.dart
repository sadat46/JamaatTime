import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jamaat_time/services/firebase_callable_service.dart';

void main() {
  test(
    'non-Windows platforms delegate to the cloud_functions plugin path',
    () async {
      String? calledName;
      Map<String, dynamic>? calledData;
      String? calledRegion;

      final service = FirebaseCallableService(
        targetPlatformOverride: TargetPlatform.android,
        isWebOverride: false,
        idTokenProvider: () =>
            throw StateError('token should not be requested'),
        pluginCaller: (name, data, region) async {
          calledName = name;
          calledData = data;
          calledRegion = region;
          return <String, dynamic>{'ok': true};
        },
      );

      final result = await service.call('broadcastNotification', {
        'title': 'Hello',
      });

      expect(result, <String, dynamic>{'ok': true});
      expect(calledName, 'broadcastNotification');
      expect(calledData, <String, dynamic>{'title': 'Hello'});
      expect(calledRegion, 'us-central1');
    },
  );

  test('Windows sends callable protocol JSON with bearer token', () async {
    late http.Request capturedRequest;
    final service = FirebaseCallableService(
      targetPlatformOverride: TargetPlatform.windows,
      isWebOverride: false,
      idTokenProvider: () async => 'id-token',
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'result': <String, dynamic>{'status': 'sent'},
          }),
          200,
        );
      }),
      pluginCaller: (_, __, ___) => throw StateError('plugin should not run'),
    );

    final result = await service.call('broadcastNotification', {
      'type': 'text',
    });

    expect(
      capturedRequest.url.toString(),
      'https://us-central1-jaamattime.cloudfunctions.net/broadcastNotification',
    );
    expect(capturedRequest.headers['Authorization'], 'Bearer id-token');
    expect(
      capturedRequest.headers['Content-Type'],
      startsWith('application/json'),
    );
    expect(jsonDecode(capturedRequest.body), <String, dynamic>{
      'data': <String, dynamic>{'type': 'text'},
    });
    expect(result, <String, dynamic>{'status': 'sent'});
  });

  test('Windows maps callable errors into readable exceptions', () async {
    final service = FirebaseCallableService(
      targetPlatformOverride: TargetPlatform.windows,
      isWebOverride: false,
      idTokenProvider: () async => 'id-token',
      httpClient: MockClient((_) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'error': <String, dynamic>{
              'status': 'PERMISSION_DENIED',
              'message': 'Superadmin only.',
            },
          }),
          200,
        );
      }),
    );

    expect(
      () => service.call('broadcastNotification'),
      throwsA(
        isA<FirebaseCallableException>()
            .having((e) => e.code, 'code', 'permission-denied')
            .having((e) => e.message, 'message', 'Superadmin only.'),
      ),
    );
  });

  test('Windows requires a signed-in Firebase Auth user', () async {
    final service = FirebaseCallableService(
      targetPlatformOverride: TargetPlatform.windows,
      isWebOverride: false,
      idTokenProvider: () async => null,
      httpClient: MockClient((_) async {
        throw StateError('HTTP should not run without a token');
      }),
    );

    expect(
      () => service.call('broadcastNotification'),
      throwsA(
        isA<FirebaseCallableException>().having(
          (e) => e.code,
          'code',
          'unauthenticated',
        ),
      ),
    );
  });
}
