import 'package:flutter/foundation.dart';

import '../../../core/constants/app_roles.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';

/// State management provider for authentication and role authorization.
class AuthProvider with ChangeNotifier {
  final AuthService _authService;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  UserRole get currentRole => _currentUser?.role ?? UserRole.citizen;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider(this._authService) {
    _currentUser = _authService.currentUser;
    _authService.authStateChanges.listen((user) {
      _currentUser = user;
      notifyListeners();
    });
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      _currentUser = await _authService.signInWithEmailAndPassword(
        email,
        password,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = ErrorHandler.getUserMessage(e);
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
    required String phoneNumber,
    required UserRole role,
    String assignedArea = 'Colombo 03',
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      _currentUser = await _authService.registerWithEmailAndPassword(
        email: email,
        password: password,
        displayName: displayName,
        phoneNumber: phoneNumber,
        role: role,
        assignedArea: assignedArea,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = ErrorHandler.getUserMessage(e);
      _setLoading(false);
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _authService.sendPasswordResetEmail(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = ErrorHandler.getUserMessage(e);
      _setLoading(false);
      return false;
    }
  }

  Future<void> signInWithDemoRole(UserRole role) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      _currentUser = await _authService.signInWithDemoRole(role);
    } catch (e) {
      _errorMessage = ErrorHandler.getUserMessage(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateProfile({
    String? displayName,
    String? phoneNumber,
    String? assignedArea,
    String? photoUrl,
  }) async {
    try {
      await _authService.updateProfile(
        displayName: displayName,
        phoneNumber: phoneNumber,
        assignedArea: assignedArea,
        photoUrl: photoUrl,
      );
      _currentUser = _authService.currentUser;
      notifyListeners();
    } catch (e) {
      _errorMessage = ErrorHandler.getUserMessage(e);
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authService.signOut();
      _currentUser = null;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
