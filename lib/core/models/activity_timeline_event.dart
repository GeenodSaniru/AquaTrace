import '../constants/fault_constants.dart';

/// Represents an immutable audit trail entry in a report's lifecycle history.
class ActivityTimelineEvent {
  final String id;
  final String reportId;
  final String title;
  final String description;
  final String actorName;
  final String actorRole;
  final FaultStatus status;
  final DateTime timestamp;

  const ActivityTimelineEvent({
    required this.id,
    required this.reportId,
    required this.title,
    required this.description,
    required this.actorName,
    required this.actorRole,
    required this.status,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reportId': reportId,
      'title': title,
      'description': description,
      'actorName': actorName,
      'actorRole': actorRole,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ActivityTimelineEvent.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    return ActivityTimelineEvent(
      id: documentId ?? map['id'] as String? ?? '',
      reportId: map['reportId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      actorName: map['actorName'] as String? ?? 'System',
      actorRole: map['actorRole'] as String? ?? 'System',
      status: FaultStatus.fromString(map['status'] as String?),
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
