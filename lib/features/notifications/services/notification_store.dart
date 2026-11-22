import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/models/notification_item.dart';
import 'notification_gateway.dart';

/// Holds the signed-in user's notification inbox and exposes read / unread
/// state to the UI.
///
/// * One live subscription per bound user; switching or clearing the user
///   cancels the previous one so notifications never leak between accounts.
/// * Read state changes are applied optimistically and rolled back (with a
///   user-visible message) if the write fails.
class NotificationStore extends ChangeNotifier {
  NotificationStore({required this._gateway});

  final NotificationGateway _gateway;

  StreamSubscription<List<NotificationItem>>? _subscription;
  String? _uid;
  List<NotificationItem> _items = const [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _actionError;
  bool _disposed = false;

  /// Ids opened (e.g. from a push) before the inbox finished loading; marked
  /// read as soon as the matching notification arrives.
  final Set<String> _pendingReadIds = {};

  /// Notifications for the bound user, newest first.
  List<NotificationItem> get items => _items;

  /// Number of unread notifications (drives the header badge).
  int get unreadCount => _items.where((item) => !item.isRead).length;

  /// True until the first snapshot (or error) arrives for the bound user.
  bool get isLoading => _isLoading;

  /// Load failure for the inbox itself; shown with a retry action.
  String? get errorMessage => _errorMessage;

  /// Failure of the most recent mark-read action; shown once, then cleared.
  String? get actionError => _actionError;

  /// Uid the inbox is currently bound to, if any.
  String? get boundUid => _uid;

  /// Binds the store to [uid]. Idempotent for the same uid; `null` clears the
  /// inbox (signed out, or no authenticated backend session).
  void bindUser(String? uid) {
    if (uid == _uid) return;
    _subscription?.cancel();
    _subscription = null;
    _uid = uid;
    _items = const [];
    _errorMessage = null;
    _actionError = null;
    _pendingReadIds.clear();
    if (uid == null) {
      _isLoading = false;
      _notify();
      return;
    }
    _isLoading = true;
    _notify();
    _subscribe(uid);
  }

  void _subscribe(String uid) {
    _subscription = _gateway
        .watchNotifications(uid)
        .listen(
          (items) {
            if (_uid != uid) return;
            _items = sortNotificationsNewestFirst(items);
            _isLoading = false;
            _errorMessage = null;
            _notify();
            _applyPendingReads();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (_uid != uid) return;
            debugPrint('[AquaTrace] Notification stream failed: $error');
            _isLoading = false;
            _errorMessage = describeNotificationError(error);
            _notify();
          },
        );
  }

  /// Re-subscribes after a load failure.
  void retry() {
    final uid = _uid;
    if (uid == null) return;
    _subscription?.cancel();
    _errorMessage = null;
    _isLoading = true;
    _notify();
    _subscribe(uid);
  }

  /// Marks [id] as read. A no-op for unknown or already-read notifications, so
  /// repeated taps never cause redundant writes.
  Future<void> markAsRead(String id) async {
    final uid = _uid;
    if (uid == null) return;
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1 || _items[index].isRead) return;

    _items = List.of(_items)..[index] = _items[index].copyWith(isRead: true);
    _notify();
    try {
      await _gateway.markRead(uid, id);
    } on Object catch (error) {
      debugPrint('[AquaTrace] markRead failed: $error');
      _revert(uid, {id});
      _actionError = 'Could not update the notification. Please try again.';
      _notify();
    }
  }

  /// Marks [id] read now if it is loaded, otherwise as soon as it arrives.
  /// Used when a push is opened before the inbox has loaded.
  void markReadWhenAvailable(String id) {
    if (_uid == null || id.isEmpty) return;
    if (_items.any((item) => item.id == id)) {
      unawaited(markAsRead(id));
    } else if (_pendingReadIds.length < 20) {
      _pendingReadIds.add(id);
    }
  }

  void _applyPendingReads() {
    if (_pendingReadIds.isEmpty) return;
    final loaded = _items.map((item) => item.id).toSet();
    final ready = _pendingReadIds.where(loaded.contains).toList();
    for (final id in ready) {
      _pendingReadIds.remove(id);
      unawaited(markAsRead(id));
    }
  }

  /// Marks every unread notification as read.
  Future<void> markAllAsRead() async {
    final uid = _uid;
    if (uid == null) return;
    final unreadIds = _items
        .where((item) => !item.isRead)
        .map((item) => item.id)
        .toSet();
    if (unreadIds.isEmpty) return;

    _items = [
      for (final item in _items)
        if (unreadIds.contains(item.id)) item.copyWith(isRead: true) else item,
    ];
    _notify();
    try {
      await _gateway.markAllRead(uid, unreadIds);
    } on Object catch (error) {
      debugPrint('[AquaTrace] markAllRead failed: $error');
      _revert(uid, unreadIds);
      _actionError = 'Could not mark notifications as read. Please try again.';
      _notify();
    }
  }

  void _revert(String uid, Set<String> ids) {
    if (_uid != uid) return; // Account changed while the write was in flight.
    _items = [
      for (final item in _items)
        if (ids.contains(item.id)) item.copyWith(isRead: false) else item,
    ];
  }

  /// Returns and clears the pending action error so it is shown only once.
  String? takeActionError() {
    final message = _actionError;
    _actionError = null;
    return message;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
