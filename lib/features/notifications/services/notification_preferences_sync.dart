import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// The notification choices the backend needs to know about.
///
/// Settings screen mapping (see `profile_settings_screens.dart`):
/// * **Report Updates** switch -> [pushEnabled] (push delivery on this
///   account; in-app records are always kept);
/// * **Repair Verification** -> [repairVerification] (verification requests
///   and community milestones, in-app and push);
/// * **Nearby Faults** -> [nearbyFaults] (stored; no notification uses it yet).
@immutable
class NotificationPreferences {
  const NotificationPreferences({
    required this.pushEnabled,
    required this.repairVerification,
    required this.nearbyFaults,
  });

  final bool pushEnabled;
  final bool repairVerification;
  final bool nearbyFaults;

  Map<String, Object> toMap() => {
    'pushEnabled': pushEnabled,
    'repairVerification': repairVerification,
    'nearbyFaults': nearbyFaults,
  };

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferences &&
      other.pushEnabled == pushEnabled &&
      other.repairVerification == repairVerification &&
      other.nearbyFaults == nearbyFaults;

  @override
  int get hashCode =>
      Object.hash(pushEnabled, repairVerification, nearbyFaults);
}

/// Persists [NotificationPreferences] for a user.
abstract class NotificationPreferencesStore {
  Future<void> save(String uid, NotificationPreferences preferences);
}

/// `/users/{uid}/settings/notifications` (owner-only; read by the backend).
class FirebaseNotificationPreferencesStore
    implements NotificationPreferencesStore {
  FirebaseNotificationPreferencesStore({this._firestore});

  final FirebaseFirestore? _firestore;

  @override
  Future<void> save(String uid, NotificationPreferences preferences) {
    return (_firestore ?? FirebaseFirestore.instance)
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('notifications')
        .set({
          ...preferences.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }
}

/// Mirrors the user's notification choices to their account so the trusted
/// backend can honour them.
///
/// * Only the signed-in user's own document is written, and only with a real
///   backend session (demo identities and signed-out states never write).
/// * Unchanged values are not re-written.
/// * A failed write is remembered and retried (bounded), so a choice made
///   offline is not silently lost; the latest value always wins.
class NotificationPreferencesSync extends ChangeNotifier {
  NotificationPreferencesSync({
    required this._store,
    required this._read,
    bool Function(String uid)? canUseBackend,
    this.retryDelay = const Duration(seconds: 30),
    this.maxRetries = 5,
  }) : _canUseBackend = canUseBackend ?? ((_) => true);

  final NotificationPreferencesStore _store;
  final NotificationPreferences Function() _read;
  final bool Function(String uid) _canUseBackend;

  /// Delay before retrying a failed write.
  final Duration retryDelay;

  /// Retries after the first failed attempt.
  final int maxRetries;

  String? _uid;
  NotificationPreferences? _lastSynced;
  Timer? _retryTimer;
  int _failures = 0;
  bool _writing = false;
  bool _writeAgain = false;
  bool _disposed = false;

  /// Whether the last attempt failed and a retry is pending.
  bool get hasPendingChange => _retryTimer != null || _failures > 0;

  /// Last failure, for diagnostics.
  Object? lastError;

  /// Binds to the signed-in user (`null` = signed out) and syncs.
  Future<void> bindUser(String? uid) async {
    if (uid == _uid) return;
    _uid = uid;
    _lastSynced = null;
    _failures = 0;
    _retryTimer?.cancel();
    _retryTimer = null;
    lastError = null;
    if (uid != null) await sync();
  }

  /// Writes the current choices if they changed since the last successful
  /// write. Safe to call on every preferences change.
  Future<void> sync() async {
    final uid = _uid;
    if (uid == null || !_canUseBackend(uid)) return;
    if (_writing) {
      _writeAgain = true;
      return;
    }
    final current = _read();
    if (current == _lastSynced) return;

    _writing = true;
    try {
      await _store.save(uid, current);
      // If the account changed during the write, do not record it as synced
      // for the new user; the pending re-sync below handles them.
      if (_uid == uid) {
        _lastSynced = current;
        _failures = 0;
        _retryTimer?.cancel();
        _retryTimer = null;
        lastError = null;
      }
    } on Object catch (error) {
      debugPrint('[AquaTrace] Notification preferences sync failed: $error');
      if (_uid == uid) {
        lastError = error;
        _failures++;
        _scheduleRetry();
      }
    } finally {
      _writing = false;
    }
    _notify();
    if (_writeAgain) {
      _writeAgain = false;
      await sync(); // A newer choice arrived while writing.
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (_failures > maxRetries || _disposed) return;
    _retryTimer = Timer(retryDelay, () {
      _retryTimer = null;
      unawaited(sync());
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    super.dispose();
  }
}
