import '../constants/app_roles.dart';
import '../constants/fault_constants.dart';
import 'activity_timeline_event.dart';
import 'notification_item.dart';
import 'report_model.dart';
import 'user_model.dart';

/// Pre-populated reference dataset conforming to the AquaTrace Figma UI specification.
class MockData {
  MockData._();

  // Demo Users
  static final UserModel citizenUser = UserModel(
    uid: 'demo-citizen-001',
    email: 'citizen@demo.com',
    displayName: 'Amal Perera',
    phoneNumber: '+94 77 123 4567',
    role: UserRole.citizen,
    assignedArea: 'Colombo 03',
    createdAt: DateTime(2026, 1, 15),
  );

  static final UserModel technicianUser = UserModel(
    uid: 'demo-tech-002',
    email: 'tech@demo.com',
    displayName: 'Kasun Jayawardena',
    phoneNumber: '+94 71 987 6543',
    role: UserRole.technician,
    assignedArea: 'Colombo North',
    employeeId: 'WB-2024-087',
    createdAt: DateTime(2026, 2, 1),
  );

  static final UserModel adminUser = UserModel(
    uid: 'demo-admin-003',
    email: 'admin@demo.com',
    displayName: 'Dilani Wickramasinghe',
    phoneNumber: '+94 11 234 5678',
    role: UserRole.admin,
    assignedArea: 'National Water Board · Sri Lanka',
    createdAt: DateTime(2026, 1, 1),
  );

  static List<UserModel> get demoUsers => [
    citizenUser,
    technicianUser,
    adminUser,
  ];

  // Demo Fault Reports
  static List<ReportModel> get initialReports => [
    ReportModel(
      reportId: 'AT-2026-00124',
      reporterUid: citizenUser.uid,
      reporterName: citizenUser.displayName,
      faultType: FaultType.pipeLeak,
      description:
          'Water leaking rapidly from municipal pipe joint along the pavement.',
      severity: FaultSeverity.high,
      status: FaultStatus.ongoing,
      latitude: 6.8912,
      longitude: 79.8554,
      address: 'Galle Road, Colombo 03',
      assignedTechnicianUid: technicianUser.uid,
      assignedTechnicianName: technicianUser.displayName,
      assignedArea: 'Colombo 03',
      isEmergency: false,
      verificationCount: 3,
      disputeCount: 0,
      repairNotes: 'Technician on site; excavation and pipe sealing underway.',
      createdAt: DateTime(2026, 9, 24, 10, 32),
      updatedAt: DateTime(2026, 9, 24, 13, 15),
    ),
    ReportModel(
      reportId: 'AT-2026-00125',
      reporterUid: 'citizen-nirmala-004',
      reporterName: 'Nirmala Silva',
      faultType: FaultType.burstPipe,
      description: 'Main water pipe burst near market. Water gushing out continuously causing road flooding.',
      severity: FaultSeverity.critical,
      status: FaultStatus.pending,
      latitude: 6.8504,
      longitude: 79.9275,
      address: 'Main Street, Maharagama',
      assignedArea: 'Maharagama',
      isEmergency: true,
      verificationCount: 0,
      disputeCount: 0,
      createdAt: DateTime(2026, 9, 24, 9, 15),
    ),
    ReportModel(
      reportId: 'AT-2026-00126',
      reporterUid: 'citizen-ruwan-005',
      reporterName: 'Ruwan Fernando',
      faultType: FaultType.roadWaterFlow,
      description: 'Continuous water overflow spreading onto roadway from underground main.',
      severity: FaultSeverity.medium,
      status: FaultStatus.completed,
      latitude: 6.8415,
      longitude: 79.9654,
      address: 'Highlevel Road, Kottawa',
      assignedTechnicianUid: technicianUser.uid,
      assignedTechnicianName: technicianUser.displayName,
      assignedArea: 'Kottawa',
      verificationCount: 2,
      disputeCount: 0,
      repairNotes: 'Replaced damaged PVC junction and tested pressure.',
      createdAt: DateTime(2026, 9, 23, 14, 20),
      updatedAt: DateTime(2026, 9, 24, 11, 45),
    ),
    ReportModel(
      reportId: 'AT-2026-00127',
      reporterUid: 'citizen-chamara-006',
      reporterName: 'Chamara Bandara',
      faultType: FaultType.damagedPipe,
      description: 'Cracked main pipe leaking near junction after telecommunications digging.',
      severity: FaultSeverity.high,
      status: FaultStatus.disputed,
      latitude: 6.8722,
      longitude: 79.8890,
      address: 'Park Road, Nugegoda',
      assignedTechnicianUid: 'tech-nimal-007',
      assignedTechnicianName: 'Nimal Fernando',
      assignedArea: 'Nugegoda',
      verificationCount: 1,
      disputeCount: 2,
      repairNotes: 'Citizen reported persistent dampness and water seepage.',
      createdAt: DateTime(2026, 9, 22, 16, 10),
      updatedAt: DateTime(2026, 9, 24, 8, 30),
    ),
    ReportModel(
      reportId: 'AT-2026-00128',
      reporterUid: citizenUser.uid,
      reporterName: citizenUser.displayName,
      faultType: FaultType.pipeLeak,
      description: 'Minor leak near residential water meter connection.',
      severity: FaultSeverity.low,
      status: FaultStatus.assigned,
      latitude: 6.8995,
      longitude: 79.8542,
      address: 'Duplication Road, Colombo 03',
      assignedTechnicianUid: technicianUser.uid,
      assignedTechnicianName: technicianUser.displayName,
      assignedArea: 'Colombo 03',
      createdAt: DateTime(2026, 9, 24, 9, 45),
    ),
  ];

  // Activity Timeline for AT-2026-00124
  static List<ActivityTimelineEvent> get activityTimelineFor124 => [
    ActivityTimelineEvent(
      id: 'act-001',
      reportId: 'AT-2026-00124',
      title: 'Report Submitted',
      description: 'Citizen submitted report for pipe leak at Galle Road.',
      actorName: 'Amal Perera',
      actorRole: 'Citizen',
      status: FaultStatus.pending,
      timestamp: DateTime(2026, 9, 24, 10, 32),
    ),
    ActivityTimelineEvent(
      id: 'act-002',
      reportId: 'AT-2026-00124',
      title: 'Report Verified',
      description:
          'Admin verified and approved the report. Priority set to High.',
      actorName: 'Dilani Wickramasinghe',
      actorRole: 'Admin',
      status: FaultStatus.assigned,
      timestamp: DateTime(2026, 9, 24, 11, 5),
    ),
    ActivityTimelineEvent(
      id: 'act-003',
      reportId: 'AT-2026-00124',
      title: 'Technician Assigned',
      description: 'Kasun Jayawardena assigned to repair. ETA 45 minutes.',
      actorName: 'Dilani Wickramasinghe',
      actorRole: 'Admin',
      status: FaultStatus.assigned,
      timestamp: DateTime(2026, 9, 24, 11, 20),
    ),
    ActivityTimelineEvent(
      id: 'act-004',
      reportId: 'AT-2026-00124',
      title: 'Repair Started',
      description: 'Technician arrived and started repair work.',
      actorName: 'Kasun Jayawardena',
      actorRole: 'Technician',
      status: FaultStatus.ongoing,
      timestamp: DateTime(2026, 9, 24, 13, 15),
    ),
    ActivityTimelineEvent(
      id: 'act-005',
      reportId: 'AT-2026-00124',
      title: 'Community Verified',
      description: '3 nearby citizens confirmed the ongoing repair update.',
      actorName: 'Community',
      actorRole: 'Citizen Verification',
      status: FaultStatus.ongoing,
      timestamp: DateTime(2026, 9, 24, 15, 10),
    ),
  ];

  // Notifications matching the screenshots
  static List<NotificationItem> get initialNotifications => [
    NotificationItem(
      id: 'notif-001',
      recipientUid: citizenUser.uid,
      title: 'Technician Assigned',
      body: 'Your report AT-2026-00124 has been assigned to Kasun Jayawardena.',
      reportId: 'AT-2026-00124',
      type: 'assignment',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    NotificationItem(
      id: 'notif-002',
      recipientUid: citizenUser.uid,
      title: 'Verify Repair',
      body: 'Repair completed for AT-2026-00126. Please verify whether the issue has been resolved.',
      reportId: 'AT-2026-00126',
      type: 'verification',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    NotificationItem(
      id: 'notif-003',
      recipientUid: citizenUser.uid,
      title: 'Report Approved',
      body: 'Your report AT-2026-00128 has been verified by admin and is now assigned.',
      reportId: 'AT-2026-00128',
      type: 'approval',
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    NotificationItem(
      id: 'notif-004',
      recipientUid: citizenUser.uid,
      title: 'Dispute Opened',
      body: 'A dispute has been raised on AT-2026-00127. Admin is reviewing.',
      reportId: 'AT-2026-00127',
      type: 'dispute',
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];
}
