import '../constants/fault_constants.dart';

/// Central Firestore data contract for water pipe fault reports in `/reports/{reportId}`.
class ReportModel {
  final String reportId;
  final String reporterUid;
  final String reporterName;
  final FaultType faultType;
  final String description;
  final FaultSeverity severity;
  final FaultStatus status;
  final double latitude;
  final double longitude;
  final String address;
  final String? beforeImageUrl;
  final String? afterImageUrl;
  final String? assignedTechnicianUid;
  final String? assignedTechnicianName;
  final String assignedArea;
  final bool isEmergency;
  final int verificationCount;
  final int disputeCount;
  final String? repairNotes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ReportModel({
    required this.reportId,
    required this.reporterUid,
    required this.reporterName,
    required this.faultType,
    required this.description,
    required this.severity,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.beforeImageUrl,
    this.afterImageUrl,
    this.assignedTechnicianUid,
    this.assignedTechnicianName,
    this.assignedArea = 'Colombo 03',
    this.isEmergency = false,
    this.verificationCount = 0,
    this.disputeCount = 0,
    this.repairNotes,
    required this.createdAt,
    this.updatedAt,
  });

  bool get hasValidLocation =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  Map<String, dynamic> toMap() {
    return {
      'reportId': reportId,
      'reporterUid': reporterUid,
      'reporterName': reporterName,
      'faultType': faultType.name,
      'description': description,
      'severity': severity.name,
      'status': status.name,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'beforeImageUrl': beforeImageUrl,
      'afterImageUrl': afterImageUrl,
      'assignedTechnicianUid': assignedTechnicianUid,
      'assignedTechnicianName': assignedTechnicianName,
      'assignedArea': assignedArea,
      'isEmergency': isEmergency,
      'verificationCount': verificationCount,
      'disputeCount': disputeCount,
      'repairNotes': repairNotes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory ReportModel.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return ReportModel(
      reportId: documentId ?? map['reportId'] as String? ?? '',
      reporterUid: map['reporterUid'] as String? ?? '',
      reporterName: map['reporterName'] as String? ?? 'Citizen',
      faultType: FaultType.fromString(map['faultType'] as String?),
      description: map['description'] as String? ?? '',
      severity: FaultSeverity.fromString(map['severity'] as String?),
      status: FaultStatus.fromString(map['status'] as String?),
      latitude: _coordinateFromMap(map['latitude'], -90, 90),
      longitude: _coordinateFromMap(map['longitude'], -180, 180),
      address: map['address'] as String? ?? 'Colombo',
      beforeImageUrl: map['beforeImageUrl'] as String?,
      afterImageUrl: map['afterImageUrl'] as String?,
      assignedTechnicianUid: map['assignedTechnicianUid'] as String?,
      assignedTechnicianName: map['assignedTechnicianName'] as String?,
      assignedArea: map['assignedArea'] as String? ?? 'Colombo 03',
      isEmergency: map['isEmergency'] as bool? ?? false,
      verificationCount: (map['verificationCount'] as num?)?.toInt() ?? 0,
      disputeCount: (map['disputeCount'] as num?)?.toInt() ?? 0,
      repairNotes: map['repairNotes'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }

  static double _coordinateFromMap(dynamic value, double min, double max) {
    if (value is! num) return double.nan;
    final coordinate = value.toDouble();
    return coordinate.isFinite && coordinate >= min && coordinate <= max
        ? coordinate
        : double.nan;
  }

  ReportModel copyWith({
    String? reportId,
    String? reporterUid,
    String? reporterName,
    FaultType? faultType,
    String? description,
    FaultSeverity? severity,
    FaultStatus? status,
    double? latitude,
    double? longitude,
    String? address,
    String? beforeImageUrl,
    String? afterImageUrl,
    String? assignedTechnicianUid,
    String? assignedTechnicianName,
    String? assignedArea,
    bool? isEmergency,
    int? verificationCount,
    int? disputeCount,
    String? repairNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReportModel(
      reportId: reportId ?? this.reportId,
      reporterUid: reporterUid ?? this.reporterUid,
      reporterName: reporterName ?? this.reporterName,
      faultType: faultType ?? this.faultType,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      beforeImageUrl: beforeImageUrl ?? this.beforeImageUrl,
      afterImageUrl: afterImageUrl ?? this.afterImageUrl,
      assignedTechnicianUid:
          assignedTechnicianUid ?? this.assignedTechnicianUid,
      assignedTechnicianName:
          assignedTechnicianName ?? this.assignedTechnicianName,
      assignedArea: assignedArea ?? this.assignedArea,
      isEmergency: isEmergency ?? this.isEmergency,
      verificationCount: verificationCount ?? this.verificationCount,
      disputeCount: disputeCount ?? this.disputeCount,
      repairNotes: repairNotes ?? this.repairNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
