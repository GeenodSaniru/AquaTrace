import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/firebase_options.dart';

/// Environment-safe Firebase initialization manager.
///
/// Prevents the application from crashing on startup when Firebase credentials
/// have not yet been generated or configured by the developer.
class FirebaseService {
  FirebaseService._();

  static bool _isInitialized = false;
  static bool _isRealFirebase = false;

  static bool get isInitialized => _isInitialized;
  static bool get isRealFirebase => _isRealFirebase;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (DefaultFirebaseOptions.isConfigured) {
        final options = DefaultFirebaseOptions.currentPlatform;
        await Firebase.initializeApp(options: options);
        _isRealFirebase = true;
        debugPrint(
          '[AquaTrace] Connected to Firebase project '
          '"${options.projectId}" (${options.appId}).',
        );
      } else {
        // Attempt default platform initialization (e.g. google-services.json on Android)
        try {
          await Firebase.initializeApp();
          _isRealFirebase = true;
          debugPrint(
            '[AquaTrace] Connected to native default Firebase configuration.',
          );
        } catch (_) {
          _isRealFirebase = false;
          debugPrint(
            '[AquaTrace] Firebase credentials pending. Running in environment-safe demo mode.',
          );
        }
      }
    } catch (e) {
      _isRealFirebase = false;
      debugPrint('[AquaTrace] Firebase initialization notice: $e');
      debugPrint(
        '[AquaTrace] Safe fallback active. App functionality is fully operational.',
      );
    } finally {
      _isInitialized = true;
    }
  }
}
