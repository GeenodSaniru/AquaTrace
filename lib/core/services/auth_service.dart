import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import '../constants/app_roles.dart';
import '../errors/app_exception.dart';
import '../errors/error_handler.dart';
import '../models/mock_data.dart';
import '../models/user_model.dart';
import 'firebase_service.dart';
import 'preferences_service.dart';

/// Centralized authentication service handling Firebase Auth and safe demo fallbacks.
class AuthService {
  final PreferencesService _preferencesService;
  final StreamController<UserModel?> _authStateController =
      StreamController<UserModel?>.broadcast();

  UserModel? _currentUser;

  AuthService(this._preferencesService) {
    _initializeAuth();
  }

  UserModel? get currentUser => _currentUser;
  Stream<UserModel?> get authStateChanges => _authStateController.stream;

  Future<void> _initializeAuth() async {
    if (FirebaseService.isRealFirebase) {
      fb.FirebaseAuth.instance.authStateChanges().listen((fbUser) async {
        if (fbUser != null) {
          try {
            final doc = await FirebaseFirestore.instance
                .collection('users')
                .doc(fbUser.uid)
                .get();
            if (doc.exists && doc.data() != null) {
              _currentUser = UserModel.fromMap(
                doc.data()!,
                documentId: fbUser.uid,
              );
            } else {
              _currentUser = UserModel(
                uid: fbUser.uid,
                email: fbUser.email ?? '',
                displayName: fbUser.displayName ?? 'AquaTrace User',
                phoneNumber: fbUser.phoneNumber ?? '',
                role: UserRole.citizen,
                createdAt: DateTime.now(),
              );
            }
          } catch (e) {
            ErrorHandler.logError(e);
          }
        } else {
          _currentUser = null;
        }
        _authStateController.add(_currentUser);
      });
    } else {
      // In demo mode, restore last signed-in demo user if available, default to citizen
      final lastUid = _preferencesService.lastAuthUid;
      if (lastUid != null) {
        _currentUser = MockData.demoUsers.firstWhere(
          (u) => u.uid == lastUid,
          orElse: () => MockData.citizenUser,
        );
      } else {
        _currentUser = MockData.citizenUser;
      }
      _authStateController.add(_currentUser);
    }
  }

  Future<UserModel> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      throw const ValidationException(
        'Please provide both email and password.',
      );
    }

    if (FirebaseService.isRealFirebase) {
      try {
        final credential = await fb.FirebaseAuth.instance
            .signInWithEmailAndPassword(
              email: trimmedEmail,
              password: password,
            );
        final fbUser = credential.user!;
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(fbUser.uid)
            .get();

        if (doc.exists && doc.data() != null) {
          _currentUser = UserModel.fromMap(doc.data()!, documentId: fbUser.uid);
        } else {
          _currentUser = UserModel(
            uid: fbUser.uid,
            email: trimmedEmail,
            displayName: fbUser.displayName ?? 'AquaTrace User',
            phoneNumber: fbUser.phoneNumber ?? '',
            role: UserRole.citizen,
            createdAt: DateTime.now(),
          );
        }
        await _preferencesService.setLastAuthUid(_currentUser!.uid);
        _authStateController.add(_currentUser);
        return _currentUser!;
      } on fb.FirebaseAuthException catch (e) {
        throw AuthException(ErrorHandler.getUserMessage(e), code: e.code);
      } catch (e) {
        throw AuthException(ErrorHandler.getUserMessage(e));
      }
    } else {
      // Demo authentication match
      await Future.delayed(const Duration(milliseconds: 400));
      final matched = MockData.demoUsers.firstWhere(
        (u) => u.email.toLowerCase() == trimmedEmail.toLowerCase(),
        orElse: () {
          // If custom email entered in demo mode, create user as Citizen
          return UserModel(
            uid: 'demo-user-${DateTime.now().millisecondsSinceEpoch}',
            email: trimmedEmail,
            displayName: trimmedEmail.split('@').first,
            phoneNumber: '+94 77 000 0000',
            role: UserRole.citizen,
            assignedArea: 'Colombo 03',
            createdAt: DateTime.now(),
          );
        },
      );
      _currentUser = matched;
      await _preferencesService.setLastAuthUid(matched.uid);
      _authStateController.add(_currentUser);
      return matched;
    }
  }

  Future<UserModel> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
    required String phoneNumber,
    required UserRole role,
    String assignedArea = 'Colombo 03',
  }) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.length < 6) {
      throw const ValidationException(
        'Password must be at least 6 characters.',
      );
    }

    if (FirebaseService.isRealFirebase) {
      try {
        final credential = await fb.FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: trimmedEmail,
              password: password,
            );
        final fbUser = credential.user!;
        await fbUser.updateDisplayName(displayName);

        final userModel = UserModel(
          uid: fbUser.uid,
          email: trimmedEmail,
          displayName: displayName,
          phoneNumber: phoneNumber,
          role: role,
          assignedArea: assignedArea,
          createdAt: DateTime.now(),
        );

        await FirebaseFirestore.instance
            .collection('users')
            .doc(fbUser.uid)
            .set(userModel.toMap());

        _currentUser = userModel;
        await _preferencesService.setLastAuthUid(userModel.uid);
        _authStateController.add(_currentUser);
        return userModel;
      } on fb.FirebaseAuthException catch (e) {
        throw AuthException(ErrorHandler.getUserMessage(e), code: e.code);
      } catch (e) {
        throw AuthException(ErrorHandler.getUserMessage(e));
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 400));
      final newUser = UserModel(
        uid: 'user-${DateTime.now().millisecondsSinceEpoch}',
        email: trimmedEmail,
        displayName: displayName,
        phoneNumber: phoneNumber,
        role: role,
        assignedArea: assignedArea,
        createdAt: DateTime.now(),
      );
      _currentUser = newUser;
      await _preferencesService.setLastAuthUid(newUser.uid);
      _authStateController.add(_currentUser);
      return newUser;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      throw const ValidationException('Please provide an email address.');
    }

    if (FirebaseService.isRealFirebase) {
      try {
        await fb.FirebaseAuth.instance.sendPasswordResetEmail(
          email: trimmedEmail,
        );
      } catch (e) {
        throw AuthException(ErrorHandler.getUserMessage(e));
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 300));
      debugPrint('[AquaTrace Demo] Password reset link sent to: $trimmedEmail');
    }
  }

  Future<UserModel> signInWithDemoRole(UserRole role) async {
    await Future.delayed(const Duration(milliseconds: 200));
    UserModel selected;
    switch (role) {
      case UserRole.citizen:
        selected = MockData.citizenUser;
        break;
      case UserRole.technician:
        selected = MockData.technicianUser;
        break;
      case UserRole.admin:
        selected = MockData.adminUser;
        break;
    }
    _currentUser = selected;
    await _preferencesService.setLastAuthUid(selected.uid);
    _authStateController.add(_currentUser);
    return selected;
  }

  Future<void> updateProfile({
    String? displayName,
    String? phoneNumber,
    String? assignedArea,
    String? photoUrl,
  }) async {
    if (_currentUser == null) return;

    final updated = _currentUser!.copyWith(
      displayName: displayName,
      phoneNumber: phoneNumber,
      assignedArea: assignedArea,
      photoUrl: photoUrl,
      updatedAt: DateTime.now(),
    );

    if (FirebaseService.isRealFirebase) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(updated.uid)
            .update(updated.toMap());
      } catch (e) {
        ErrorHandler.logError(e);
      }
    }

    _currentUser = updated;
    _authStateController.add(_currentUser);
  }

  Future<void> signOut() async {
    if (FirebaseService.isRealFirebase) {
      await fb.FirebaseAuth.instance.signOut();
    }
    _currentUser = null;
    await _preferencesService.setLastAuthUid(null);
    _authStateController.add(null);
  }

  void dispose() {
    _authStateController.close();
  }
}
