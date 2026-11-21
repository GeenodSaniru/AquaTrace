import 'dart:async';

import '../../../core/models/activity_timeline_event.dart';
import '../../../core/models/notification_item.dart';
import 'notification_gateway.dart';

/// Non-persistent [NotificationGateway] used for demo mode (no Firebase) and
/// automated tests.
///
/// [deliver] stands in for the trusted backend that creates notifications in
/// production; the app itself never calls it outside demo seeding.
class InMemoryNotificationGateway implements NotificationGateway {
  InMemoryNotificationGateway({
    Map<String, List<NotificationItem>> seed = const {},
  }) {
    seed.forEach((uid, items) => _byUser[uid] = List.of(items));
  }

  final Map<String, List<NotificationItem>> _byUser = {};
  final Map<String, List<ActivityTimelineEvent>> _activity = {};
  final Map<String, StreamController<List<NotificationItem>>> _userStreams = {};
  final Map<String, StreamController<List<ActivityTimelineEvent>>>
  _activityStreams = {};

  /// When set, [markRead] / [markAllRead] throw it (failure-path testing).
  Object? markFailure;

  /// When set, [watchNotifications] emits it as a stream error.
  Object? watchFailure;

  /// Number of write calls, for asserting batching / no-op behaviour.
  int markReadCalls = 0;
  int markAllReadCalls = 0;

  /// Simulates the backend creating a notification for [item.recipientUid].
  void deliver(NotificationItem item) {
    final list = _byUser.putIfAbsent(item.recipientUid, () => []);
    // Deterministic ids make backend retries idempotent.
    list.removeWhere((existing) => existing.id == item.id);
    list.add(item);
    _emitUser(item.recipientUid);
  }

  void seedActivity(String reportId, List<ActivityTimelineEvent> events) {
    _activity[reportId] = List.of(events);
    _emitActivity(reportId);
  }

  void appendActivity(ActivityTimelineEvent event) {
    _activity.putIfAbsent(event.reportId, () => []).add(event);
    _emitActivity(event.reportId);
  }

  List<NotificationItem> snapshotFor(String uid) =>
      List.unmodifiable(_byUser[uid] ?? const []);

  void _emitUser(String uid) {
    final controller = _userStreams[uid];
    if (controller != null && !controller.isClosed) {
      controller.add(sortNotificationsNewestFirst(_byUser[uid] ?? const []));
    }
  }

  void _emitActivity(String reportId) {
    final controller = _activityStreams[reportId];
    if (controller != null && !controller.isClosed) {
      controller.add(
        sortActivityChronologically(_activity[reportId] ?? const []),
      );
    }
  }

  @override
  Stream<List<NotificationItem>> watchNotifications(
    String uid, {
    int limit = NotificationGateway.defaultNotificationLimit,
  }) {
    final failure = watchFailure;
    if (failure != null) {
      return Stream<List<NotificationItem>>.error(failure);
    }
    final controller = _userStreams.putIfAbsent(
      uid,
      () => StreamController<List<NotificationItem>>.broadcast(),
    );
    return Stream<List<NotificationItem>>.multi((multi) {
      multi.add(
        sortNotificationsNewestFirst(_byUser[uid] ?? const [])
            .take(limit)
            .toList(),
      );
      final subscription = controller.stream.listen(
        multi.add,
        onError: multi.addError,
      );
      multi.onCancel = subscription.cancel;
    });
  }

  @override
  Future<void> markRead(String uid, String notificationId) async {
    markReadCalls++;
    final failure = markFailure;
    if (failure != null) throw failure;
    final list = _byUser[uid];
    if (list == null) return;
    final index = list.indexWhere((item) => item.id == notificationId);
    if (index == -1) return;
    list[index] = list[index].copyWith(isRead: true);
    _emitUser(uid);
  }

  @override
  Future<void> markAllRead(String uid, Iterable<String> notificationIds) async {
    markAllReadCalls++;
    final failure = markFailure;
    if (failure != null) throw failure;
    final ids = notificationIds.toSet();
    final list = _byUser[uid];
    if (list == null) return;
    for (var i = 0; i < list.length; i++) {
      if (ids.contains(list[i].id)) list[i] = list[i].copyWith(isRead: true);
    }
    _emitUser(uid);
  }

  @override
  Stream<List<ActivityTimelineEvent>> watchActivity(
    String reportId, {
    int limit = NotificationGateway.defaultActivityLimit,
  }) {
    final controller = _activityStreams.putIfAbsent(
      reportId,
      () => StreamController<List<ActivityTimelineEvent>>.broadcast(),
    );
    return Stream<List<ActivityTimelineEvent>>.multi((multi) {
      multi.add(sortActivityChronologically(_activity[reportId] ?? const []));
      final subscription = controller.stream.listen(
        multi.add,
        onError: multi.addError,
      );
      multi.onCancel = subscription.cancel;
    });
  }
}
