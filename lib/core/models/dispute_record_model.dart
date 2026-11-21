/// Community dispute record lodged by a citizen at `/reports/{reportId}/disputes/{voterUid}`.
class DisputeRecordModel {
  final String voterUid;
  final String voterName;
  final String reportId;
  final String reason;
  final String? evidenceImageUrl;
  final DateTime createdAt;

  const DisputeRecordModel({
    required this.voterUid,
    required this.voterName,
    required this.reportId,
    required this.reason,
    this.evidenceImageUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'voterUid': voterUid,
      'voterName': voterName,
      'reportId': reportId,
      'reason': reason.trim(),
      if (evidenceImageUrl != null && evidenceImageUrl!.isNotEmpty)
        'evidenceImageUrl': evidenceImageUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DisputeRecordModel.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    return DisputeRecordModel(
      voterUid: documentId ?? map['voterUid'] as String? ?? '',
      voterName: map['voterName'] as String? ?? 'Citizen',
      reportId: map['reportId'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      evidenceImageUrl: map['evidenceImageUrl'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
