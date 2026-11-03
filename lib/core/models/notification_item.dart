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
      type: map['type'] as String? ?? 'update',
      isRead: map['isRead'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
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
