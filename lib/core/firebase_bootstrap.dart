import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

final Future<bool> firebaseReady = _initializeFirebase();

Future<bool> _initializeFirebase() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    return true;
  } catch (error, stackTrace) {
    developer.log(
      'Firebase initialization failed',
      name: 'FirebaseBootstrap',
      error: error,
      stackTrace: stackTrace,
    );
    return false;
  }
}
