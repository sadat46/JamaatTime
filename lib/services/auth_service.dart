import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { user, admin, superadmin }

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get userChanges => _auth.userChanges();
  User? get currentUser => _auth.currentUser;

  Future<User?> signIn(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return result.user;
  }

  Future<User?> register(String email, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    
    // Set default role as user for new registrations
    if (result.user != null) {
      await _firestore.collection('users').doc(result.user!.uid).set({
        'email': email,
        'role': 'user',
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

  /// Get current user's role
  Future<UserRole> getUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return UserRole.user;
    
    // Check Firestore for role
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
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
    
    // Fallback to hardcoded admin emails (legacy support)
    const adminEmails = [
      'test@gmail.com', // replace with your admin email(s)
    ];
    const superadminEmails = [
      'sadat46@gmail.com', // replace with your superadmin email(s)
    ];
    
    if (superadminEmails.contains(user.email)) {
      return UserRole.superadmin;
    }
    if (adminEmails.contains(user.email)) {
      return UserRole.admin;
    }
    
    return UserRole.user;
  }

  /// Check if current user is admin (includes superadmin)
  Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role == UserRole.admin || role == UserRole.superadmin;
  }

  /// Check if current user is superadmin
  Future<bool> isSuperAdmin() async {
    final role = await getUserRole();
    return role == UserRole.superadmin;
  }

  /// Get all users (superadmin only)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    if (!await isSuperAdmin()) {
      throw Exception('Only superadmins can view all users');
    }
    
    final querySnapshot = await _firestore.collection('users').get();
    
    final users = querySnapshot.docs.map((doc) {
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
    
    return users;
  }

  /// Update user role (superadmin only)
  Future<void> updateUserRole(String userId, UserRole newRole) async {
    if (!await isSuperAdmin()) {
      throw Exception('Only superadmins can update user roles');
    }
    
    // Prevent superadmin from changing their own role
    if (userId == _auth.currentUser?.uid) {
      throw Exception('Cannot change your own role');
    }
    
    // Prevent superadmin from changing other superadmins
    final targetUserDoc = await _firestore.collection('users').doc(userId).get();
    if (targetUserDoc.exists && targetUserDoc.data()?['role'] == 'superadmin') {
      throw Exception('Cannot change another superadmin\'s role');
    }
    
    await _firestore.collection('users').doc(userId).update({
      'role': newRole.name,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Delete user (superadmin only)
  Future<void> deleteUser(String userId) async {
    if (!await isSuperAdmin()) {
      throw Exception('Only superadmins can delete users');
    }
    
    // Prevent superadmin from deleting themselves
    if (userId == _auth.currentUser?.uid) {
      throw Exception('Cannot delete your own account');
    }
    
    // Prevent superadmin from deleting other superadmins
    final targetUserDoc = await _firestore.collection('users').doc(userId).get();
    if (targetUserDoc.exists && targetUserDoc.data()?['role'] == 'superadmin') {
      throw Exception('Cannot delete another superadmin');
    }
    
    await _firestore.collection('users').doc(userId).delete();
  }

  /// Get user statistics (superadmin only)
  Future<Map<String, dynamic>> getUserStats() async {
    if (!await isSuperAdmin()) {
      throw Exception('Only superadmins can view user statistics');
    }
    
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

  /// Migrate existing Firebase Auth users to Firestore
  /// This helps with users who registered before Firestore integration
  Future<void> migrateExistingUsers() async {
    if (!await isSuperAdmin()) {
      throw Exception('Only superadmins can migrate users');
    }
    
    try {
      // For now, we'll create a document for the current user if it doesn't exist
      // and provide instructions for manual migration
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (!userDoc.exists) {
          await _firestore.collection('users').doc(currentUser.uid).set({
            'email': currentUser.email,
            'role': await getUserRole() == UserRole.superadmin ? 'superadmin' : 'user',
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      }
      
      // Create a helper method to manually add users
      // To add missing users, call:
      // await _authService.addUserToFirestore(userId, email, role)
      // Example:
      // await _authService.addUserToFirestore("user123", "user@example.com", "user")
      
    } catch (e) {
      throw Exception('Error migrating users: $e');
    }
  }

  /// Manually add a user to Firestore (for migration purposes)
  Future<void> addUserToFirestore(String userId, String email, String role) async {
    if (!await isSuperAdmin()) {
      throw Exception('Only superadmins can add users to Firestore');
    }
    
    await _firestore.collection('users').doc(userId).set({
      'email': email,
      'role': role,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
} 