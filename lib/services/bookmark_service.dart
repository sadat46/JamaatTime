import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';

class BookmarkService {
  static final BookmarkService _instance = BookmarkService._internal();
  factory BookmarkService() => _instance;
  BookmarkService._internal() {
    _initAuthListener();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // In-memory cache for fast lookups
  final Set<String> _bookmarkedIds = {};
  bool _initialized = false;

  // Check if user can bookmark (must be logged in)
  bool get canBookmark => _authService.currentUser != null;

  String? get _userId => _authService.currentUser?.uid;

  // Listen to auth state changes
  void _initAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        // User logged in, initialize bookmarks
        initialize();
      } else {
        // User logged out, clear bookmarks
        _bookmarkedIds.clear();
        _initialized = false;
      }
    });
  }

  // Initialize/refresh bookmarks from Firestore
  Future<void> initialize() async {
    if (!canBookmark) {
      _bookmarkedIds.clear();
      _initialized = false;
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('bookmarks')
          .get();

      _bookmarkedIds.clear();
      for (var doc in snapshot.docs) {
        _bookmarkedIds.add(doc.id);
      }
      _initialized = true;
    } catch (e) {
      // Handle error silently, bookmarks are not critical
      _bookmarkedIds.clear();
      _initialized = false;
    }
  }

  // Check if content is bookmarked
  bool isBookmarked(String contentType, int contentId) {
    return _bookmarkedIds.contains('${contentType}_$contentId');
  }

  // Toggle bookmark - returns new state (true = bookmarked)
  Future<bool> toggleBookmark(
    String contentType,
    int contentId, {
    String? title,
  }) async {
    if (!canBookmark) return false;

    final key = '${contentType}_$contentId';
    final ref = _firestore
        .collection('users')
        .doc(_userId)
        .collection('bookmarks')
        .doc(key);

    try {
      if (_bookmarkedIds.contains(key)) {
        await ref.delete();
        _bookmarkedIds.remove(key);
        return false;
      } else {
        await ref.set({
          'contentType': contentType,
          'contentId': contentId,
          'title': title,
          'createdAt': FieldValue.serverTimestamp(),
        });
        _bookmarkedIds.add(key);
        return true;
      }
    } catch (e) {
      // Return current state if operation fails
      return _bookmarkedIds.contains(key);
    }
  }

  // Get all bookmark IDs for a content type
  List<int> getBookmarkIds(String contentType) {
    return _bookmarkedIds
        .where((key) => key.startsWith('${contentType}_'))
        .map((key) => int.parse(key.split('_')[1]))
        .toList();
  }

  // Get all bookmarks with details (for bookmarks screen)
  Future<List<Map<String, dynamic>>> getAllBookmarks() async {
    if (!canBookmark) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('bookmarks')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      // Return empty list if fetch fails
      return [];
    }
  }

  // Get bookmarks by content type
  Future<List<Map<String, dynamic>>> getBookmarksByType(
      String contentType) async {
    if (!canBookmark) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('bookmarks')
          .where('contentType', isEqualTo: contentType)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Clear all bookmarks (useful for testing or user preference)
  Future<void> clearAllBookmarks() async {
    if (!canBookmark) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('bookmarks')
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      _bookmarkedIds.clear();
    } catch (e) {
      // Silently fail
    }
  }

  // Check if bookmarks are initialized
  bool get isInitialized => _initialized;

  // Force refresh from server
  Future<void> refresh() async {
    await initialize();
  }
}
