import 'package:flutter/material.dart';

// Handles deep links carried in FCM `data.deepLink` payloads.
//
// The app currently has no named-route table (home is built directly in
// MaterialApp.home). P2 wires a navigatorKey so future phases can land users
// on specific screens; this router is a stub that pops to root on tap.
// P9 replaces the stub with real route parsing (e.g. /home?city=X&date=Y).
class FcmDeepLinkRouter {
  FcmDeepLinkRouter(this._navigatorKey);

  final GlobalKey<NavigatorState> _navigatorKey;

  void handle(String? deepLink) {
    if (deepLink == null || deepLink.isEmpty) return;
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    nav.popUntil((route) => route.isFirst);
  }
}
