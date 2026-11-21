import 'firestore_time.dart';

/// Event categories carried by `/users/{uid}/notifications/{id}.type`.
///
/// The string values are part of the shared Firestore contract and the
/// Firestore rules allow-list; do not rename them.
enum NotificationType {
  /// A technician was assigned to a report / job.
  assignment('assignment'),

  /// A completed repair needs (or received) community verification.
  verification('verification'),

  /// An administrator approved / verified a report.
  approval('approval'),

  /// A dispute was opened on a repair.
  dispute('dispute'),

  /// Any other repair or report status update.
  update('update');

  const NotificationType(this.value);

  /// Value stored in Firestore.
  final String value;

  /// Parses a stored value; unknown values degrade to [update] so a newer
  /// backend never breaks an older client.
  static NotificationType fromString(String? value) {
    for (final type in NotificationType.values) {
      if (type.value == value) return type;
    }
    return NotificationType.update;
  }
}

/// In-app notification model representing `/users/{uid}/notifications/{id}`.
class NotificationItem {
  final String id;
  final String recipientUid;
  final String title;
  final String body;
  final String reportId;
  final String type; // assignment, verification, approval, dispute, update
  final bool isRead;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.recipientUid,
    required this.title,
    required this.body,
    required this.reportId,
    required this.type,
    this.isRead = false,
    required this.createdAt,
  });

  /// Typed view of [type].
  NotificationType get notificationType => NotificationType.fromString(type);

  /// False when the stored document had no usable timestamp.
  bool get hasKnownTime => isKnownTime(createdAt);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipientUid': recipientUid,
      'title': title,
      'body': body,
      'reportId': reportId,
      'type': type,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory NotificationItem.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    return NotificationItem(
      id: documentId ?? map['id'] as String? ?? '',
      recipientUid: map['recipientUid'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      reportId: map['reportId'] as String? ?? '',
      type: map['type'] as String? ?? NotificationType.update.value,
      isRead: map['isRead'] as bool? ?? false,
      createdAt: parseFirestoreTime(map['createdAt']) ?? unknownTime,
    );
  }

  NotificationItem copyWith({
    String? id,
    String? recipientUid,
    String? title,
    String? body,
    String? reportId,
    String? type,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      recipientUid: recipientUid ?? this.recipientUid,
      title: title ?? this.title,
      body: body ?? this.body,
      reportId: reportId ?? this.reportId,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
