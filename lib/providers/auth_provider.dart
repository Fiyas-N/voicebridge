import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/models/user_profile.dart';
import '../data/local/database_helper.dart';
import '../services/firebase_service.dart';
import '../services/sync_service.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  UserProfile? _currentUser;
  bool _isLoading = true;
  bool _isAuthenticated = false;
  String? _errorMessage;

  UserProfile? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    _firebaseService.authStateChanges.listen(
      (User? user) async {
        if (user != null) {
          await _loadUserProfile(firebaseUser: user);
          SyncService().processPendingUploads();
        } else {
          _currentUser = null;
          _isAuthenticated = false;
          _isLoading = false;
          notifyListeners();
        }
      },
      onError: (error) {
        debugPrint('Auth state change error: $error');
        _isLoading = false;
        _isAuthenticated = false;
        notifyListeners();
      },
    );
  }

  /// Strategically resolves user identity. prioritizes High-Speed LOCAL SQLite cache
  /// for zero-latency UI rendering, while silently synchronizing with Cloud Firestore.
  Future<void> _loadUserProfile({User? firebaseUser}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final userIdent = firebaseUser ?? _firebaseService.currentFirebaseUser;
      if (userIdent == null) {
        _isAuthenticated = false;
        _isLoading = false;
        notifyListeners();
        return;
      }

      // ── PHASE 1: IMMEDIATE LOCAL LOOKUP ─────────────────────────────────
      final localMap = await DatabaseHelper.instance.getUserProfile(userIdent.uid);
      if (localMap != null) {
        debugPrint('AuthProvider: Local Profile Load Stabilized.');
        _currentUser = UserProfile.fromDbMap(localMap);
        _isAuthenticated = true;
        _isLoading = false;
        notifyListeners(); // Instant update for UI Screens (Progress, Home)!
      }

      // ── PHASE 2: SILENT CLOUD SYNC & RECONCILIATION ─────────────────────
      UserProfile? cloudProfile = await _firebaseService.getUserProfile();

      if (cloudProfile == null) {
        // Fallback to basic builder
        cloudProfile = UserProfile(
          userId: userIdent.uid,
          email: userIdent.email ?? '',
          displayName: userIdent.displayName ?? '',
          createdAt: userIdent.metadata.creationTime ?? DateTime.now(),
          lastActiveAt: DateTime.now(),
        );
        await _firebaseService.ensureUserProfile(cloudProfile);
      }

      // If local cache was outdated or missing, merge from cloud and update local
      if (_currentUser == null || cloudProfile.xp > _currentUser!.xp) {
        debugPrint('AuthProvider: Merging escalated Cloud Profile metrics.');
        _currentUser = cloudProfile;
        // Secure the latest metadata in local SQL
        await DatabaseHelper.instance.insertUserProfile(cloudProfile.toDbMap());
      }

      _isAuthenticated = true;
      _errorMessage = null;
    } catch (e) {
      debugPrint('Auth Flow Error: $e');
      // Fallback fallback logic
      if (_currentUser == null) {
        final fbUser = firebaseUser ?? _firebaseService.currentFirebaseUser;
        if (fbUser != null) {
          _currentUser = UserProfile(
            userId: fbUser.uid,
            email: fbUser.email ?? '',
            displayName: fbUser.displayName ?? '',
            createdAt: DateTime.now(),
            lastActiveAt: DateTime.now(),
          );
          _isAuthenticated = true;
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  Future<void> signUp(String email, String password, String displayName) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _firebaseService.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      // authStateChanges listener will fire and call _loadUserProfile automatically.
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _firebaseService.signIn(email: email, password: password);
      // authStateChanges listener will fire and call _loadUserProfile automatically.
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firebaseService.signOut();
      _currentUser = null;
      _isAuthenticated = false;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to sign out';
      debugPrint('Sign out failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateUserProfile(UserProfile profile) {
    _currentUser = profile;
    notifyListeners();
  }

  /// Reloads user profile from DB to reflect gamification changes
  Future<void> refreshUserProfile() async {
    if (_currentUser == null) return;
    await _loadUserProfile();
  }

  Future<void> updateDisplayName(String newName) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firebaseService.updateDisplayName(newName);
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(displayName: newName);
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firebaseService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendPasswordReset() async {
    if (_currentUser == null) return;
    try {
      await _firebaseService.sendPasswordResetEmail(_currentUser!.email);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      rethrow;
    }
  }

  /// Sends a password reset email without requiring the user to be logged in.
  /// Used by the Forgot Password button on the login screen.
  Future<void> sendPasswordResetForEmail(String email) async {
    try {
      await _firebaseService.sendPasswordResetEmail(email);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      rethrow;
    }
  }


  Future<void> deleteAccount(String currentPassword) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firebaseService.deleteAccount(currentPassword);
      _currentUser = null;
      _isAuthenticated = false;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
