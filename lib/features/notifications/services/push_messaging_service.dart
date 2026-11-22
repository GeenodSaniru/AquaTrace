import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models/notification_item.dart';

/// Result of the operating-system notification permission check.
enum PushPermissionStatus {
  /// Not checked yet.
  unknown,

  /// The user has not been asked yet.
  notDetermined,

  /// Notifications are allowed (including iOS provisional).
  granted,

  /// The user refused; only system settings can change this.
  denied,

  /// This platform / build cannot receive push (web, desktop, no Firebase).
  unsupported,
}

/// Platform-neutral view of a push message.
///
/// Only the fields the app needs are kept. Payloads are expected to carry no
/// sensitive data: the authoritative content lives in the (access-controlled)
/// notification document; the push is just a pointer to it.
class PushMessage {
  const PushMessage({
    this.messageId,
    this.title,
    this.body,
    this.data = const {},
  });

  factory PushMessage.fromRemote(RemoteMessage message) {
    return PushMessage(
      messageId: message.messageId,
      title: message.notification?.title,
      body: message.notification?.body,
      data: {
        for (final entry in message.data.entries)
          entry.key: entry.value?.toString() ?? '',
      },
    );
  }

  final String? messageId;
  final String? title;
  final String? body;
  final Map<String, String> data;

  /// Related report id, or `null` when absent / malformed.
  String? get reportId => sanitizeReportId(data['reportId']);

  /// Related notification document id, if the backend included it.
  String? get notificationId {
    final id = data['notificationId']?.trim();
    return (id == null || id.isEmpty) ? null : id;
  }

  /// Notification category from the payload, or `null` when absent. Unknown
  /// values degrade to [NotificationType.update] rather than being trusted.
  NotificationType? get type {
    final raw = data['type']?.trim();
    return (raw == null || raw.isEmpty)
        ? null
        : NotificationType.fromString(raw);
  }
}

final RegExp _reportIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$');

/// Validates an id coming from an external payload before it is used for
/// navigation. Anything that is not a plain id is rejected.
String? sanitizeReportId(String? raw) {
  final value = raw?.trim();
  if (value == null || !_reportIdPattern.hasMatch(value)) return null;
  return value;
}

/// Thin wrapper over the messaging SDK so the lifecycle logic can be tested
/// without a device.
abstract class PushMessagingClient {
  /// Platform tag stored with the token (`android`, `ios`, `macos`, ...).
  String get platformName;

  Future<bool> isSupported();
  Future<PushPermissionStatus> getPermissionStatus();
  Future<PushPermissionStatus> requestPermission();
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
  Stream<PushMessage> get onForegroundMessage;
  Stream<PushMessage> get onMessageOpenedApp;
  Future<PushMessage?> getInitialMessage();
  Future<void> deleteToken();
  Future<void> configureForegroundPresentation();
}

/// Persists device tokens so the backend can address a user's devices.
abstract class PushTokenStore {
  Future<void> upsert({
    required String uid,
    required String token,
    required String platform,
  });

  Future<void> remove({required String uid, required String token});
}

/// Used when push cannot work (Firebase not configured, unsupported platform).
class UnsupportedPushMessagingClient implements PushMessagingClient {
  const UnsupportedPushMessagingClient();

  @override
  String get platformName => 'unsupported';

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<PushPermissionStatus> getPermissionStatus() async =>
      PushPermissionStatus.unsupported;

  @override
  Future<PushPermissionStatus> requestPermission() async =>
      PushPermissionStatus.unsupported;

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream<String>.empty();

  @override
  Stream<PushMessage> get onForegroundMessage =>
      const Stream<PushMessage>.empty();

  @override
  Stream<PushMessage> get onMessageOpenedApp =>
      const Stream<PushMessage>.empty();

  @override
  Future<PushMessage?> getInitialMessage() async => null;

  @override
  Future<void> deleteToken() async {}

  @override
  Future<void> configureForegroundPresentation() async {}
}

/// Firebase Cloud Messaging implementation (Android, iOS, macOS).
///
/// Web is deliberately reported as unsupported: browser push needs a service
/// worker and a VAPID key that this project has not configured.
class FirebasePushMessagingClient implements PushMessagingClient {
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  static bool get _platformSupported {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS => true,
      _ => false,
    };
  }

  @override
  String get platformName => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    _ => 'other',
  };

  @override
  Future<bool> isSupported() async {
    if (!_platformSupported) return false;
    return _messaging.isSupported();
  }

  PushPermissionStatus _map(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        return PushPermissionStatus.granted;
      case AuthorizationStatus.denied:
      case AuthorizationStatus.deniedPermanently:
        return PushPermissionStatus.denied;
      case AuthorizationStatus.notDetermined:
        return PushPermissionStatus.notDetermined;
    }
  }

  @override
  Future<PushPermissionStatus> getPermissionStatus() async =>
      _map((await _messaging.getNotificationSettings()).authorizationStatus);

  @override
  Future<PushPermissionStatus> requestPermission() async =>
      _map((await _messaging.requestPermission()).authorizationStatus);

  // firebase_messaging 17 marks the token API deprecated in favour of
  // register()/onRegistered, which yield a Firebase Installation ID for a new
  // "direct send" path. The backend contract here (Admin SDK token sends,
  // documented in functions/README.md) is token based, and the token API is
  // still fully supported, so it is used deliberately. Migrating is a
  // client + backend change that should be made together.
  @override
  // ignore: deprecated_member_use
  Future<String?> getToken() => _messaging.getToken();

  @override
  // ignore: deprecated_member_use
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<PushMessage> get onForegroundMessage =>
      FirebaseMessaging.onMessage.map(PushMessage.fromRemote);

  @override
  Stream<PushMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp.map(PushMessage.fromRemote);

  @override
  Future<PushMessage?> getInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : PushMessage.fromRemote(message);
  }

  @override
  // ignore: deprecated_member_use
  Future<void> deleteToken() => _messaging.deleteToken();

  @override
  Future<void> configureForegroundPresentation() {
    // The app shows its own in-app banner while foregrounded, so suppress the
    // system alert on Apple platforms to avoid a duplicate. (Android never
    // shows system notifications for foreground messages.)
    return _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );
  }
}

/// Stores tokens at `/users/{uid}/fcmTokens/{token}`.
class FirebasePushTokenStore implements PushTokenStore {
  FirebasePushTokenStore({this._firestore});

  final FirebaseFirestore? _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid, String token) =>
      (_firestore ?? FirebaseFirestore.instance)
          .collection('users')
          .doc(uid)
          .collection('fcmTokens')
          .doc(token);

  @override
  Future<void> upsert({
    required String uid,
    required String token,
    required String platform,
  }) async {
    final ref = _doc(uid, token);
    final existing = await ref.get();
    if (existing.exists) {
      await ref.update({
        'platform': platform,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.set({
        'token': token,
        'platform': platform,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Future<void> remove({required String uid, required String token}) =>
      _doc(uid, token).delete();
}

/// Push permission, device-token lifecycle and deep-link handling.
///
/// Lifecycle
/// * [initialize] - once at startup: attaches message listeners.
/// * [bindUser] - on sign-in / account change: refreshes the permission
///   status and, when allowed, registers the token for that user.
/// * [requestPermission] - user-initiated prompt (never automatic).
/// * token refresh - the new token is saved and the old one removed.
/// * [unregister] - before sign-out or when the user turns push off: removes
///   the token document and invalidates the device token so the previous
///   account can no longer reach this device.
class PushMessagingService extends ChangeNotifier {
  PushMessagingService({
    required this._client,
    required this._tokenStore,
    bool Function(String uid)? canUseBackend,
    bool Function()? isUserEnabled,
    this._onOpenReport,
    this._onForegroundMessage,
    DateTime Function()? clock,
  }) : _canUseBackend = canUseBackend ?? ((_) => true),
       _isUserEnabled = isUserEnabled ?? (() => true),
       _clock = clock ?? DateTime.now;

  /// The same message reported again within this window is treated as a
  /// duplicate delivery; later taps (a user re-opening a notification) are not.
  static const Duration duplicateWindow = Duration(seconds: 5);

  final PushMessagingClient _client;
  final PushTokenStore _tokenStore;
  final bool Function(String uid) _canUseBackend;
  final bool Function() _isUserEnabled;
  final void Function(
    String reportId,
    String? notificationId,
    NotificationType? type,
  )?
  _onOpenReport;
  final void Function(PushMessage message)? _onForegroundMessage;
  final DateTime Function() _clock;

  final List<StreamSubscription<Object?>> _subscriptions = [];
  PushPermissionStatus _status = PushPermissionStatus.unknown;
  String? _uid;
  String? _token;
  String? _lastError;
  bool _initialized = false;
  bool _suspended = false;
  bool _disposed = false;
  final Map<String, DateTime> _seenForeground = {};
  final Map<String, DateTime> _seenOpened = {};
  String? _pendingReportId;
  String? _pendingNotificationId;
  NotificationType? _pendingType;

  /// Current OS permission state.
  PushPermissionStatus get status => _status;

  /// Whether a token is currently registered for the signed-in user.
  bool get isRegistered => _token != null;

  /// Registered token (exposed for diagnostics and tests only).
  @visibleForTesting
  String? get currentToken => _token;

  /// Last registration failure, if any.
  String? get lastError => _lastError;

  /// Whether the user has turned push on in app preferences.
  bool get isUserEnabled => _isUserEnabled();

  /// Whether the banner should offer to turn push on.
  bool get canPromptForPermission =>
      _status == PushPermissionStatus.notDetermined;

  /// Attaches listeners and reads the initial permission state. Safe to call
  /// repeatedly; never throws.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      if (!await _client.isSupported()) {
        _setStatus(PushPermissionStatus.unsupported);
        return;
      }
      await _client.configureForegroundPresentation();
      _subscriptions
        ..add(_client.onTokenRefresh.listen(_onTokenRefresh))
        ..add(_client.onForegroundMessage.listen(_handleForeground))
        ..add(_client.onMessageOpenedApp.listen(_handleOpened));
      final initial = await _client.getInitialMessage();
      if (initial != null) _handleOpened(initial);
      _setStatus(await _client.getPermissionStatus());
    } on Object catch (error) {
      debugPrint('[AquaTrace] Push initialisation failed: $error');
      _lastError = 'Push notifications are unavailable on this device.';
      _setStatus(PushPermissionStatus.unsupported);
    }
  }

  /// Binds push to the signed-in user (`null` = signed out).
  Future<void> bindUser(String? uid) async {
    if (uid == _uid) return;
    final previousUid = _uid;
    final previousToken = _token;
    _uid = uid;
    _token = null;
    _suspended = false;
    _lastError = null;

    if (previousUid != null && previousToken != null) {
      // Normally already done by [unregister] before sign-out. If it was not
      // (expired session, forced sign-out), kill the device token so the
      // previous account cannot keep receiving this device's pushes. Awaited so
      // the deletion cannot race with the new user's token registration.
      await _discard(previousUid, previousToken);
    }
    _notify();
    if (uid == null || _uid != uid) return;

    await refreshStatus();
    _dispatchPending();
  }

  /// Re-reads the OS permission (e.g. after returning from system settings)
  /// and registers the token if it is now allowed.
  Future<void> refreshStatus() async {
    if (_status == PushPermissionStatus.unsupported) return;
    try {
      _setStatus(await _client.getPermissionStatus());
    } on Object catch (error) {
      debugPrint('[AquaTrace] Could not read push permission: $error');
    }
    final uid = _uid;
    if (uid != null && _status == PushPermissionStatus.granted) {
      await _registerToken(uid);
    } else if (uid != null &&
        _token != null &&
        _status == PushPermissionStatus.denied) {
      // Permission was revoked in system settings while signed in: this device
      // can no longer show pushes, so stop advertising it to the backend. A
      // later re-grant registers a fresh token (see above).
      final stale = _token!;
      _token = null;
      _notify();
      await _discard(uid, stale);
    }
  }

  /// Asks the user for notification permission. Must be triggered by a user
  /// action. Returns the resulting status.
  Future<PushPermissionStatus> requestPermission() async {
    if (_status == PushPermissionStatus.unsupported) return _status;
    _suspended = false;
    try {
      _setStatus(await _client.requestPermission());
    } on Object catch (error) {
      debugPrint('[AquaTrace] Push permission request failed: $error');
      _lastError = 'Could not request notification permission.';
      _notify();
      return _status;
    }
    final uid = _uid;
    if (uid != null && _status == PushPermissionStatus.granted) {
      await _registerToken(uid);
    }
    return _status;
  }

  /// Reacts to the in-app "Push Notifications" preference.
  Future<void> onPreferenceChanged() async {
    if (_uid == null) return;
    if (_isUserEnabled()) {
      _suspended = false;
      await refreshStatus();
    } else {
      await unregister();
    }
  }

  Future<void> _registerToken(String uid) async {
    if (_suspended || !_isUserEnabled() || !_canUseBackend(uid)) return;
    if (_token != null) return;
    try {
      final token = await _client.getToken();
      if (_uid != uid || _suspended) return;
      if (token == null || token.isEmpty) {
        _lastError = 'This device did not return a push token.';
        _notify();
        return;
      }
      await _tokenStore.upsert(
        uid: uid,
        token: token,
        platform: _client.platformName,
      );
      if (_uid != uid || _suspended) {
        // Signed out / disabled while saving: do not leave the doc behind.
        unawaited(_discard(uid, token));
        return;
      }
      _token = token;
      _lastError = null;
      _notify();
    } on Object catch (error) {
      debugPrint('[AquaTrace] Push token registration failed: $error');
      _lastError = 'Could not register this device for notifications.';
      _notify();
    }
  }

  Future<void> _onTokenRefresh(String newToken) async {
    final uid = _uid;
    if (uid == null ||
        _suspended ||
        newToken.isEmpty ||
        !_isUserEnabled() ||
        !_canUseBackend(uid) ||
        _status != PushPermissionStatus.granted) {
      return;
    }
    final oldToken = _token;
    if (oldToken == newToken) return;
    try {
      await _tokenStore.upsert(
        uid: uid,
        token: newToken,
        platform: _client.platformName,
      );
      if (_uid != uid || _suspended) {
        unawaited(_discard(uid, newToken));
        return;
      }
      _token = newToken;
      _lastError = null;
      _notify();
      if (oldToken != null) {
        try {
          await _tokenStore.remove(uid: uid, token: oldToken);
        } on Object catch (error) {
          debugPrint('[AquaTrace] Could not remove stale token: $error');
        }
      }
    } on Object catch (error) {
      debugPrint('[AquaTrace] Push token refresh failed: $error');
      _lastError = 'Could not update this device for notifications.';
      _notify();
    }
  }

  /// Removes this device's token for the current user and invalidates it.
  /// Call **before** signing out, while the Firebase session is still valid.
  Future<void> unregister() async {
    _suspended = true;
    final uid = _uid;
    final token = _token;
    _token = null;
    _notify();
    if (uid != null && token != null) {
      await _discard(uid, token);
    }
  }

  Future<void> _discard(String uid, String token) async {
    try {
      await _tokenStore.remove(uid: uid, token: token);
    } on Object catch (error) {
      // Unauthenticated deletes are rejected by the rules; the device-token
      // invalidation below is what actually stops delivery.
      debugPrint('[AquaTrace] Could not delete token document: $error');
    }
    try {
      await _client.deleteToken();
    } on Object catch (error) {
      debugPrint('[AquaTrace] Could not delete device token: $error');
    }
  }

  /// Identity of a message for duplicate suppression: the FCM message id, or
  /// the notification document id the backend put in the payload.
  static String? _messageKey(PushMessage message) =>
      message.messageId ?? message.notificationId;

  /// True if [key] was already seen within [duplicateWindow] (and records
  /// it otherwise). Old entries are dropped, so the map stays small.
  bool _alreadySeen(Map<String, DateTime> seen, String? key) {
    if (key == null) return false;
    final now = _clock();
    seen.removeWhere((_, at) => now.difference(at) > duplicateWindow);
    if (seen.containsKey(key)) return true;
    seen[key] = now;
    return false;
  }

  void _handleForeground(PushMessage message) {
    if (_uid == null) return;
    // The platform can deliver the same message twice (e.g. a retry); show
    // one banner.
    if (_alreadySeen(_seenForeground, _messageKey(message))) return;
    _onForegroundMessage?.call(message);
  }

  void _handleOpened(PushMessage message) {
    final reportId = message.reportId;
    if (reportId == null) return;
    // `getInitialMessage` and `onMessageOpenedApp` can both report the same
    // tap on a cold start; navigate once.
    if (_alreadySeen(_seenOpened, _messageKey(message))) return;
    if (_uid == null) {
      // Not signed in: remember the link and open it after sign-in. The
      // destination screen re-checks authorization against the user's own data.
      _pendingReportId = reportId;
      _pendingNotificationId = message.notificationId;
      _pendingType = message.type;
      return;
    }
    _onOpenReport?.call(reportId, message.notificationId, message.type);
  }

  void _dispatchPending() {
    final reportId = _pendingReportId;
    if (reportId == null) return;
    final notificationId = _pendingNotificationId;
    final notificationType = _pendingType;
    _pendingReportId = null;
    _pendingNotificationId = null;
    _pendingType = null;
    _onOpenReport?.call(reportId, notificationId, notificationType);
  }

  /// Visible for tests: simulates tapping a push while the app is signed in/out.
  @visibleForTesting
  void debugHandleOpened(PushMessage message) => _handleOpened(message);

  void _setStatus(PushPermissionStatus status) {
    if (_status == status) return;
    _status = status;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
