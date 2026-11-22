/// Community verification vote record stored at `/reports/{reportId}/verifications/{voterUid}`.
class VerificationVoteModel {
  final String voterUid;
  final String voterName;
  final String reportId;
  final DateTime createdAt;
  final String? note;

  const VerificationVoteModel({
    required this.voterUid,
    required this.voterName,
    required this.reportId,
    required this.createdAt,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'voterUid': voterUid,
      'voterName': voterName,
      'reportId': reportId,
      'createdAt': createdAt.toIso8601String(),
      if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
    };
  }

  factory VerificationVoteModel.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    return VerificationVoteModel(
      voterUid: documentId ?? map['voterUid'] as String? ?? '',
      voterName: map['voterName'] as String? ?? 'Citizen',
      reportId: map['reportId'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      note: map['note'] as String?,
    );
  }
}
