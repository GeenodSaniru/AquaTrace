import '../constants/fault_constants.dart';
import 'firestore_time.dart';

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
      timestamp: parseFirestoreTime(map['timestamp']) ?? unknownTime,
    );
  }

  /// False when the stored document had no usable timestamp.
  bool get hasKnownTime => isKnownTime(timestamp);

  /// Chronological (oldest first) ordering with a stable tie-break on [id].
  ///
  /// Events with an unknown time sort first rather than being given a
  /// fabricated "now", so they cannot appear to be the newest event.
  static int compareChronologically(
    ActivityTimelineEvent a,
    ActivityTimelineEvent b,
  ) {
    final byTime = a.timestamp.compareTo(b.timestamp);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  }
}
