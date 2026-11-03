// File generated for AquaTrace Firebase project aquatrace-92e2e.
// Values sourced via FlutterFire/Firebase CLI SDK config for existing project AquaTrace.
// ignore_for_file: type=lint

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'core/config/firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  /// True when this file contains options for a real Firebase project
  /// (not the previous demo placeholder).
  static bool get isConfigured {
    return _configuredProjectId.isNotEmpty &&
        _configuredProjectId != 'aquatrace-demo-project';
  }

  static const String _configuredProjectId = 'aquatrace-92e2e';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'run flutterfire configure to regenerate this file for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'run flutterfire configure to regenerate this file for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA75qUgh-y5f1XNsdeilumQxWqWw2r-Iuc',
    appId: '1:298509402653:web:cca7d1291ccb34d9b47cf4',
    messagingSenderId: '298509402653',
    projectId: 'aquatrace-92e2e',
    authDomain: 'aquatrace-92e2e.firebaseapp.com',
    storageBucket: 'aquatrace-92e2e.firebasestorage.app',
    measurementId: 'G-97PENMRNK2',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD2FXaUZYxRz7F6ciMXmggQGC7QHph6PMQ',
    appId: '1:298509402653:android:db2fc54fac90b6b5b47cf4',
    messagingSenderId: '298509402653',
    projectId: 'aquatrace-92e2e',
    storageBucket: 'aquatrace-92e2e.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAMoKCxdkpx8_Lg0scssC2r2Eufd_iiToM',
    appId: '1:298509402653:ios:e62995a1bb869e46b47cf4',
    messagingSenderId: '298509402653',
    projectId: 'aquatrace-92e2e',
    storageBucket: 'aquatrace-92e2e.firebasestorage.app',
    iosBundleId: 'com.aquatrace.aquatrace',
  );

  /// macOS shares the iOS Firebase app registration (same bundle id).
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAMoKCxdkpx8_Lg0scssC2r2Eufd_iiToM',
    appId: '1:298509402653:ios:e62995a1bb869e46b47cf4',
    messagingSenderId: '298509402653',
    projectId: 'aquatrace-92e2e',
    storageBucket: 'aquatrace-92e2e.firebasestorage.app',
    iosBundleId: 'com.aquatrace.aquatrace',
  );
}
