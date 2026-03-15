import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/models/user_profile.dart';
import '../services/firebase_service.dart';

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
    // Single source of truth: Firebase auth state stream.
    // This fires once on startup (with current user or null) and again
    // whenever the user signs in or out.
    _firebaseService.authStateChanges.listen(
      (User? user) async {
        if (user != null) {
          await _loadUserProfile(firebaseUser: user);
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

  /// Loads the user profile from Firebase DB.
  /// If the DB read fails or returns null, we still mark the user as
  /// authenticated (Firebase Auth succeeded) and build a minimal profile
  /// from the FirebaseAuth user object so the app can function.
  Future<void> _loadUserProfile({User? firebaseUser}) async {
    _isLoading = true;
    notifyListeners();
    try {
      UserProfile? profile = await _firebaseService.getUserProfile();

      if (profile == null) {
        // Profile missing from DB — create a minimal one from FirebaseAuth data
        final fbUser = firebaseUser ?? _firebaseService.currentFirebaseUser;
        if (fbUser != null) {
          profile = UserProfile(
            userId: fbUser.uid,
            email: fbUser.email ?? '',
            displayName: fbUser.displayName ?? '',
            createdAt: fbUser.metadata.creationTime ?? DateTime.now(),
            lastActiveAt: DateTime.now(),
          );
          // Try to write the missing profile back to Firebase (best-effort)
          try {
            await _firebaseService.ensureUserProfile(profile);
          } catch (e) {
            debugPrint('Could not write missing profile to Firebase: $e');
          }
        }
      }

      _currentUser = profile;
      _isAuthenticated = true;
      _errorMessage = null;
      debugPrint('Auth ready — user: ${_currentUser?.email}');
    } catch (e) {
      debugPrint('_loadUserProfile error: $e');
      // Even if the DB read fails, the user IS authenticated via Firebase Auth.
      // Build a minimal profile so they can use the app.
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
      } else {
        _isAuthenticated = false;
      }
      _errorMessage = null;
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
