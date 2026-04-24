import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum UserRole { user, admin, superadmin }

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Stream<User?> get userChanges => _auth.userChanges();
  User? get currentUser => _auth.currentUser;

  Future<User?> signIn(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return result.user;
  }

  Future<User?> register(String email, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(email: email, password: password);

    // Create profile doc WITHOUT the `role` field.
    // Role is assigned only by Cloud Functions (bootstrapSuperadminRole / setUserRole).
    if (result.user != null) {
      await _firestore.collection('users').doc(result.user!.uid).set({
        'email': email,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    return result.user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> savePreferredCity(String city) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'preferred_city': city,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<String?> loadPreferredCity() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.data()?['preferred_city'] as String?;
    }
    return null;
  }

  /// Read-only role lookup. Returns [UserRole.user] if the doc is missing.
  /// The client never writes the `role` field; seeding happens exclusively
  /// through `bootstrapSuperadminRole` (single-use self-bootstrap against
  /// a server-side allowlist) and `setUserRole` (superadmin-only).
  Future<UserRole> getUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return UserRole.user;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return UserRole.user;

    final role = doc.data()?['role'] as String?;
    switch (role) {
      case 'superadmin':
        return UserRole.superadmin;
      case 'admin':
        return UserRole.admin;
      case 'user':
      default:
        return UserRole.user;
    }
  }

  Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role == UserRole.admin || role == UserRole.superadmin;
  }

  Future<bool> isSuperAdmin() async {
    final role = await getUserRole();
    return role == UserRole.superadmin;
  }

  /// Attempt the single-use self-bootstrap against the server-side allowlist
  /// at `system_config/bootstrap_superadmins`. Returns normally on success;
  /// throws [FirebaseFunctionsException] with code `permission-denied` when
  /// the caller's email is not on the allowlist. After success, the caller
  /// must refresh their id token (`user.getIdToken(true)`) and re-read the
  /// role via [getUserRole].
  Future<void> bootstrapSuperadminRole() async {
    final callable = _functions.httpsCallable('bootstrapSuperadminRole');
    await callable.call();
  }

  /// Change another user's role. Wraps the `setUserRole` Cloud Function
  /// callable so all role writes funnel through one server-side path and
  /// every change lands in `role_audit/`. The client never writes `role`
  /// to Firestore directly.
  Future<void> updateUserRole(String userId, UserRole newRole) async {
    final callable = _functions.httpsCallable('setUserRole');
    await callable.call<void>({'targetUid': userId, 'role': newRole.name});
  }

  /// List users for the superadmin console. This reads the `users`
  /// collection, which is governed by Firestore rules; non-superadmins
  /// will be rejected at the rule layer.
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final querySnapshot = await _firestore.collection('users').get();

    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'uid': doc.id,
        'email': data['email'] ?? '',
        'role': data['role'] ?? 'user',
        'preferred_city': data['preferred_city'] ?? '',
        'created_at': data['created_at'],
        'updated_at': data['updated_at'],
      };
    }).toList();
  }

  Future<Map<String, dynamic>> getUserStats() async {
    final querySnapshot = await _firestore.collection('users').get();
    final users = querySnapshot.docs;

    int userCount = 0;
    int adminCount = 0;
    int superadminCount = 0;

    for (final doc in users) {
      final role = doc.data()['role'] as String? ?? 'user';
      switch (role) {
        case 'user':
          userCount++;
          break;
        case 'admin':
          adminCount++;
          break;
        case 'superadmin':
          superadminCount++;
          break;
      }
    }

    return {
      'total_users': users.length,
      'users': userCount,
      'admins': adminCount,
      'superadmins': superadminCount,
    };
  }
}
