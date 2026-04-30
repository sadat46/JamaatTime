import 'package:flutter/foundation.dart';

class NoticeTelemetry {
  const NoticeTelemetry._();

  static void event(String name, [Map<String, Object?> params = const {}]) {
    if (kDebugMode) {
      debugPrint('notice_analytics $name $params');
    }
  }
}
