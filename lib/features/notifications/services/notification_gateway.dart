import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models/activity_timeline_event.dart';
import '../../../core/models/notification_item.dart';

/// Storage boundary for notification records and report activity history.
///
/// The production implementation is [FirebaseNotificationGateway]; demo mode
/// and tests use `InMemoryNotificationGateway`. Notification records are
/// **created only by trusted backend code** (see `functions/`): this interface
/// intentionally exposes no "create notification" operation, so the client
/// cannot send itself a notification.
abstract class NotificationGateway {
  /// Live notifications for [uid], newest first.
  Stream<List<NotificationItem>> watchNotifications(
    String uid, {
    int limit = defaultNotificationLimit,
  });

  /// Marks one notification as read. Only `isRead` is ever written.
  Future<void> markRead(String uid, String notificationId);

  /// Marks every id in [notificationIds] as read.
  Future<void> markAllRead(String uid, Iterable<String> notificationIds);

  /// Live activity history for [reportId], oldest first.
  Stream<List<ActivityTimelineEvent>> watchActivity(
    String reportId, {
    int limit = defaultActivityLimit,
  });

  /// Maximum notifications loaded per user.
  static const int defaultNotificationLimit = 100;

  /// Maximum activity events loaded per report.
  static const int defaultActivityLimit = 200;
}

/// Sorts newest first; unknown times sink to the bottom. Ties are broken by id
/// so the order is deterministic across snapshots.
List<NotificationItem> sortNotificationsNewestFirst(
  Iterable<NotificationItem> items,
) {
  final sorted = items.toList()
    ..sort((a, b) {
      final byTime = b.createdAt.compareTo(a.createdAt);
      return byTime != 0 ? byTime : b.id.compareTo(a.id);
    });
  return sorted;
}

/// Sorts oldest first (audit-trail order).
List<ActivityTimelineEvent> sortActivityChronologically(
  Iterable<ActivityTimelineEvent> events,
) {
  return events.toList()..sort(ActivityTimelineEvent.compareChronologically);
}

/// Cloud Firestore implementation.
///
/// * `/users/{uid}/notifications/{id}`  - read / mark-read by the owner.
/// * `/reports/{reportId}/activity/{id}` - append-only audit trail.
class FirebaseNotificationGateway implements NotificationGateway {
  FirebaseNotificationGateway({this._firestore});

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  /// Firestore allows 500 writes per batch.
  static const int _batchLimit = 400;

  CollectionReference<Map<String, dynamic>> _notifications(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  @override
  Stream<List<NotificationItem>> watchNotifications(
    String uid, {
    int limit = NotificationGateway.defaultNotificationLimit,
  }) {
    return _notifications(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final items = <NotificationItem>[];
          for (final doc in snapshot.docs) {
            try {
              items.add(
                NotificationItem.fromMap(doc.data(), documentId: doc.id),
              );
            } on Object catch (error) {
              // One malformed document must not hide the rest of the inbox.
              debugPrint(
                '[AquaTrace] Skipping invalid notification ${doc.id}: $error',
              );
            }
          }
          return sortNotificationsNewestFirst(items);
        });
  }

  @override
  Future<void> markRead(String uid, String notificationId) {
    return _notifications(uid).doc(notificationId).update({'isRead': true});
  }

  @override
  Future<void> markAllRead(String uid, Iterable<String> notificationIds) async {
    final ids = notificationIds.toList();
    for (var start = 0; start < ids.length; start += _batchLimit) {
      final end = (start + _batchLimit).clamp(0, ids.length);
      final batch = _db.batch();
      for (final id in ids.sublist(start, end)) {
        batch.update(_notifications(uid).doc(id), {'isRead': true});
      }
      await batch.commit();
    }
  }

  @override
  Stream<List<ActivityTimelineEvent>> watchActivity(
    String reportId, {
    int limit = NotificationGateway.defaultActivityLimit,
  }) {
    // No server-side orderBy: legacy client events store ISO strings while
    // backend events store Timestamps, and Firestore orders mixed types by
    // type first. Order is normalised client-side after tolerant parsing.
    return _db
        .collection('reports')
        .doc(reportId)
        .collection('activity')
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final events = <ActivityTimelineEvent>[];
          for (final doc in snapshot.docs) {
            try {
              events.add(
                ActivityTimelineEvent.fromMap(doc.data(), documentId: doc.id),
              );
            } on Object catch (error) {
              debugPrint(
                '[AquaTrace] Skipping invalid activity ${doc.id}: $error',
              );
            }
          }
          return sortActivityChronologically(events);
        });
  }
}

/// Maps a low-level failure to a short, user-facing sentence.
String describeNotificationError(Object error) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to view these notifications.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Could not reach AquaTrace. Check your internet connection.';
      case 'not-found':
        return 'This notification is no longer available.';
    }
  }
  return 'Something went wrong while loading notifications.';
}
