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
    // Listen to auth state changes
    _firebaseService.authStateChanges.listen(
      (User? user) async {
        if (user != null) {
          await Future.delayed(const Duration(milliseconds: 500));
          await _loadUserProfile();
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

    await _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();
    try {
      if (_firebaseService.isAuthenticated) {
        await _loadUserProfile();
      }
    } catch (e) {
      debugPrint('Auth check failed: $e');
      _errorMessage = 'Failed to check authentication status';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadUserProfile() async {
    _isLoading = true;
    notifyListeners();
    try {
      _currentUser = await _firebaseService.getUserProfile();
      _isAuthenticated = true;
      _errorMessage = null;
      debugPrint('User profile loaded: ${_currentUser?.email}');
    } catch (e) {
      debugPrint('Failed to load user profile: $e');
      _errorMessage = 'Failed to load user profile';
      _isAuthenticated = false;
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
      await _loadUserProfile();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _firebaseService.signIn(email: email, password: password);
      await _loadUserProfile();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
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
