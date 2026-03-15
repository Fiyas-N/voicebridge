import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../data/models/user_profile.dart';

/// Firebase Service
/// Handles all Firebase operations — authentication via FirebaseAuth,
/// structured data via Cloud Firestore.
class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Auth ────────────────────────────────────────────────────────────────────

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  bool get isAuthenticated => _auth.currentUser != null;
  String? get currentUserId => _auth.currentUser?.uid;
  User? get currentFirebaseUser => _auth.currentUser;

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

      // Write user profile to Firestore
      final uid = credential.user!.uid;
      await _db.collection('users').doc(uid).set({
        'userId': uid,
        'email': email,
        'displayName': displayName,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
        'baselineCompleted': false,
        'currentStreak': 0,
        'longestStreak': 0,
        'totalSessions': 0,
        'weakAreas': <String>[],
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
    await _db.collection('users').doc(uid).update({
      'displayName': displayName,
      'lastActiveAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw Exception('Not authenticated');

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
      // Delete Firestore data first, then the auth account
      await _db.collection('users').doc(user.uid).delete();
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    }
  }

  // ── User Profile ─────────────────────────────────────────────────────────────

  Future<UserProfile?> getUserProfile() async {
    final uid = currentUserId;
    if (uid == null) return null;

    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;

      final raw = doc.data()!;

      // Firestore Timestamps → DateTime
      DateTime tsToDate(String key) {
        final val = raw[key];
        if (val is Timestamp) return val.toDate();
        if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
        return DateTime.now();
      }

      // weakAreas is stored as a Firestore array of strings
      List<String> weakAreas = [];
      if (raw['weakAreas'] is List) {
        weakAreas = List<String>.from(
            (raw['weakAreas'] as List).map((e) => e.toString()));
      }

      // baselineScores sub-map (optional)
      BaselineScores? baselineScores;
      if (raw['baselineScores'] is Map) {
        final bs = raw['baselineScores'] as Map<String, dynamic>;
        baselineScores = BaselineScores(
          fluency: (bs['fluency'] as num?)?.toDouble() ?? 0,
          grammar: (bs['grammar'] as num?)?.toDouble() ?? 0,
          pronunciation: (bs['pronunciation'] as num?)?.toDouble() ?? 0,
          composite: (bs['composite'] as num?)?.toDouble() ?? 0,
        );
      }

      return UserProfile(
        userId: raw['userId']?.toString() ?? uid,
        email: raw['email']?.toString() ?? '',
        displayName: raw['displayName']?.toString() ?? '',
        createdAt: tsToDate('createdAt'),
        lastActiveAt: tsToDate('lastActiveAt'),
        baselineCompleted: raw['baselineCompleted'] == true,
        currentStreak: (raw['currentStreak'] as num?)?.toInt() ?? 0,
        longestStreak: (raw['longestStreak'] as num?)?.toInt() ?? 0,
        totalSessions: (raw['totalSessions'] as num?)?.toInt() ?? 0,
        baselineScores: baselineScores,
        weakAreas: weakAreas,
      );
    } catch (e) {
      debugPrint('getUserProfile error: $e');
      return null;
    }
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not authenticated');
    await _db.collection('users').doc(uid).update({
      ...profile.toJson(),
      'lastActiveAt': FieldValue.serverTimestamp(),
    });
  }

  /// Writes a minimal profile to Firestore if none exists yet.
  /// Uses set() with merge: false only when the document doesn't exist.
  Future<void> ensureUserProfile(UserProfile profile) async {
    final uid = currentUserId;
    if (uid == null) return;

    final docRef = _db.collection('users').doc(uid);
    final snap = await docRef.get();
    if (!snap.exists) {
      await docRef.set({
        'userId': profile.userId,
        'email': profile.email,
        'displayName': profile.displayName,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
        'baselineCompleted': false,
        'currentStreak': 0,
        'longestStreak': 0,
        'totalSessions': 0,
        'weakAreas': <String>[],
      });
    }
  }

  /// Marks the baseline assessment as completed in Firestore.
  /// Writes the score breakdown and inferred weak areas atomically.
  Future<void> markBaselineCompleted({
    required String userId,
    required BaselineScores scores,
    required List<String> weakAreas,
  }) async {
    await _db.collection('users').doc(userId).update({
      'baselineCompleted': true,
      'baselineCompletedAt': FieldValue.serverTimestamp(),
      'lastActiveAt': FieldValue.serverTimestamp(),
      'baselineScores': {
        'fluency': scores.fluency,
        'grammar': scores.grammar,
        'pronunciation': scores.pronunciation,
        'composite': scores.composite,
      },
      'weakAreas': weakAreas,
    });
  }

  // ── Sessions ──────────────────────────────────────────────────────────────

  /// Saves session summary metrics to Firestore.
  /// Full audio + transcript stays local (privacy-first).
  Future<void> saveSessionData({
    required String userId,
    required String sessionId,
    required Map<String, dynamic> sessionData,
  }) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('sessions')
          .doc(sessionId)
          .set({
        ...sessionData,
        'savedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to save session: $e');
    }
  }

  /// Fetches session summaries from Firestore, ordered newest-first.
  Future<List<Map<String, dynamic>>> getUserSessionsFromFirebase(
      String userId) async {
    try {
      final query = await _db
          .collection('users')
          .doc(userId)
          .collection('sessions')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return query.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      debugPrint('getUserSessions error: $e');
      return [];
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
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
