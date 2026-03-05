import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../data/models/user_profile.dart';

/// Firebase Service
/// Handles all Firebase operations including authentication and database
class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // ── Auth ──────────────────────────────────────────────────────────────────

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  bool get isAuthenticated => _auth.currentUser != null;
  String? get currentUserId => _auth.currentUser?.uid;

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(displayName);

      // Write user profile to Realtime Database
      await _db.child('users/${credential.user!.uid}').set({
        'userId': credential.user!.uid,
        'email': email,
        'displayName': displayName,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'lastActiveAt': DateTime.now().millisecondsSinceEpoch,
        'baselineCompleted': false,
        'currentStreak': 0,
        'longestStreak': 0,
        'totalSessions': 0,
        'weakAreas': [],
      });
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not authenticated');
    await _auth.currentUser?.updateDisplayName(displayName);
    await _db.child('users/$uid/displayName').set(displayName);
    await _db.child('users/$uid/lastActiveAt')
        .set(DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw Exception('Not authenticated');

    // Re-authenticate first
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    try {
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    }
  }

  Future<void> deleteAccount(String currentPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw Exception('Not authenticated');

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    try {
      await user.reauthenticateWithCredential(credential);
      await _db.child('users/${user.uid}').remove();
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    }
  }

  // ── User Profile ──────────────────────────────────────────────────────────

  Future<UserProfile?> getUserProfile() async {
    final uid = currentUserId;
    if (uid == null) return null;

    try {
      final snapshot = await _db.child('users/$uid').get();
      if (!snapshot.exists || snapshot.value == null) return null;

      // Firebase returns dynamic types — use safe casting
      final raw = Map<String, dynamic>.from(snapshot.value as Map);

      // Safely read weakAreas — Firebase stores lists as maps with int keys
      List<String> weakAreas = [];
      if (raw['weakAreas'] != null) {
        final wa = raw['weakAreas'];
        if (wa is List) {
          weakAreas = wa.map((e) => e.toString()).toList();
        } else if (wa is Map) {
          weakAreas = wa.values.map((e) => e.toString()).toList();
        }
      }

      return UserProfile(
        userId:       raw['userId']?.toString() ?? uid,
        email:        raw['email']?.toString() ?? '',
        displayName:  raw['displayName']?.toString() ?? '',
        createdAt:    raw['createdAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch((raw['createdAt'] as num).toInt())
            : DateTime.now(),
        lastActiveAt: raw['lastActiveAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch((raw['lastActiveAt'] as num).toInt())
            : DateTime.now(),
        baselineCompleted: raw['baselineCompleted'] == true ||
            raw['baselineCompleted'] == 1,
        currentStreak: (raw['currentStreak'] as num?)?.toInt() ?? 0,
        longestStreak: (raw['longestStreak'] as num?)?.toInt() ?? 0,
        totalSessions: (raw['totalSessions'] as num?)?.toInt() ?? 0,
        weakAreas:    weakAreas,
      );
    } catch (e) {
      debugPrint('getUserProfile error: $e');
      return null;
    }
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not authenticated');
    await _db.child('users/$uid').update(profile.toJson());
  }

  // ── Sessions ──────────────────────────────────────────────────────────────

  Future<void> saveSessionData({
    required String userId,
    required String sessionId,
    required Map<String, dynamic> sessionData,
  }) async {
    try {
      await _db.child('sessions/$userId/$sessionId').set(sessionData);
    } catch (e) {
      throw Exception('Failed to save session: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserSessionsFromFirebase(
      String userId) async {
    try {
      final snapshot = await _db
          .child('sessions/$userId')
          .orderByChild('createdAt')
          .get();

      if (!snapshot.exists || snapshot.value == null) return [];

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      return data.values
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList()
          .reversed
          .toList();
    } catch (e) {
      debugPrint('getUserSessions error: $e');
      return [];
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }
}
