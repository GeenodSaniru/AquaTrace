import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/firebase_service.dart';

/// Whether [uid] may use backend (Firestore / FCM) features.
///
/// * Firebase not configured (demo mode) -> `true`: demo data is in memory.
/// * Firebase configured -> `true` only when a real Firebase Auth session for
///   exactly [uid] exists. Demo-role sign-in uses local mock identities that
///   have no Auth session; those must not hit Firestore (it would be
///   permission-denied) or register push tokens under a uid they do not own.
bool hasBackendSession(String uid) {
  if (!FirebaseService.isRealFirebase) return true;
  return FirebaseAuth.instance.currentUser?.uid == uid;
}
