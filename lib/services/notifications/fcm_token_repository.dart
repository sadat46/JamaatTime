import 'package:cloud_firestore/cloud_firestore.dart';

// Writes FCM tokens to Firestore.
// - Logged-in users → user_tokens/{uid}
// - Guest users    → device_tokens/{installationId}
//
// Token rows are merged so repeat calls with the same token are idempotent.
class FcmTokenRepository {
  FcmTokenRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<void> saveForUser({
    required String uid,
    required String token,
    required String locale,
    String? installationId,
  }) async {
    final ref = _db.collection('user_tokens').doc(uid);
    final entry = {
      'token': token,
      'platform': 'android',
      'updatedAt': FieldValue.serverTimestamp(),
      if (installationId != null) 'installationId': installationId,
    };
    await ref.set({
      'tokens': FieldValue.arrayUnion([entry]),
      'topics': FieldValue.arrayUnion(['all_users']),
      'locale': locale,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveForDevice({
    required String installationId,
    required String token,
    required String locale,
  }) async {
    final ref = _db.collection('device_tokens').doc(installationId);
    await ref.set({
      'token': token,
      'platform': 'android',
      'topics': ['all_users'],
      'locale': locale,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> migrateGuestToUser({
    required String installationId,
    required String uid,
    required String token,
    required String locale,
  }) async {
    await saveForUser(
      uid: uid,
      token: token,
      locale: locale,
      installationId: installationId,
    );
    // Keep the device_tokens row — user may log out and become a guest again.
  }
}
