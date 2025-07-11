import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    return result.user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> savePreferredCity(String city) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({'preferred_city': city}, SetOptions(merge: true));
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

  Future<bool> isAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    // Option 1: Check Firestore field
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists && doc.data()?['isAdmin'] == true) return true;
    // Option 2: Hardcoded admin email list
    const adminEmails = [
      'sadat46@gmail.com', // replace with your admin email(s)
    ];
    return adminEmails.contains(user.email);
  }
} 