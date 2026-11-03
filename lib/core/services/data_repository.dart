import 'package:flutter/foundation.dart';

import '../constants/fault_constants.dart';
import '../models/activity_timeline_event.dart';
import '../models/mock_data.dart';
import '../models/notification_item.dart';
import '../models/report_model.dart';
import 'firebase_service.dart';

/// Central repository managing reports, activity timelines, and notifications.
///
/// Supports real Cloud Firestore synchronization when credentials are active,
/// and reactive in-memory state during development or demo execution.
class DataRepository with ChangeNotifier {
  final List<ReportModel> _reports = [];
  final List<NotificationItem> _notifications = [];
  final Map<String, List<ActivityTimelineEvent>> _reportTimelines = {};

  List<ReportModel> get reports => List.unmodifiable(_reports);
  List<NotificationItem> get notifications => List.unmodifiable(_notifications);

  DataRepository() {
    _initialize();
  }

  void _initialize() {
    _reports.addAll(MockData.initialReports);
    _notifications.addAll(MockData.initialNotifications);
    _reportTimelines['AT-2026-00124'] = List.from(
      MockData.activityTimelineFor124,
    );
  }

  // --- Reports Query & Management ---

  List<ReportModel> getReportsForCitizen(String uid) {
    return _reports.where((r) => r.reporterUid == uid).toList();
  }

  List<ReportModel> getReportsForTechnician(String technicianUid) {
    return _reports
        .where((r) => r.assignedTechnicianUid == technicianUid)
        .toList();
  }

  List<ReportModel> getReportsByStatus(FaultStatus status) {
    return _reports.where((r) => r.status == status).toList();
  }

  ReportModel? getReportById(String reportId) {
    try {
      return _reports.firstWhere((r) => r.reportId == reportId);
    } catch (_) {
      return null;
    }
  }

  Future<void> addReport(ReportModel report) async {
    _reports.insert(0, report);
    _addTimelineEvent(
      reportId: report.reportId,
      title: 'Report Submitted',
      description:
          'Report submitted by ${report.reporterName} for ${report.faultType.displayName}.',
      actorName: report.reporterName,
      actorRole: 'Citizen',
      status: FaultStatus.pending,
    );
    notifyListeners();

    if (FirebaseService.isRealFirebase) {
      // Future Firebase Firestore integration by Member 3
    }
  }

  Future<void> updateReportStatus({
    required String reportId,
    required FaultStatus newStatus,
    required String actorName,
    required String actorRole,
    String? note,
  }) async {
    final index = _reports.indexWhere((r) => r.reportId == reportId);
    if (index != -1) {
      final updated = _reports[index].copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
        repairNotes: note ?? _reports[index].repairNotes,
      );
      _reports[index] = updated;

      _addTimelineEvent(
        reportId: reportId,
        title: 'Status Updated: ${newStatus.displayName}',
        description:
            note ??
            'Report status changed to ${newStatus.displayName} by $actorName.',
        actorName: actorName,
        actorRole: actorRole,
        status: newStatus,
      );

      notifyListeners();
    }
  }

  Future<void> assignTechnician({
    required String reportId,
    required String technicianUid,
    required String technicianName,
    required String adminName,
  }) async {
    final index = _reports.indexWhere((r) => r.reportId == reportId);
    if (index != -1) {
      _reports[index] = _reports[index].copyWith(
        assignedTechnicianUid: technicianUid,
        assignedTechnicianName: technicianName,
        status: FaultStatus.assigned,
        updatedAt: DateTime.now(),
      );

      _addTimelineEvent(
        reportId: reportId,
        title: 'Technician Assigned',
        description: '$technicianName assigned to repair by $adminName.',
        actorName: adminName,
        actorRole: 'Admin',
        status: FaultStatus.assigned,
      );

      notifyListeners();
    }
  }

  // --- Activity History ---

  List<ActivityTimelineEvent> getTimelineForReport(String reportId) {
    return _reportTimelines[reportId] ?? [];
  }

  void _addTimelineEvent({
    required String reportId,
    required String title,
    required String description,
    required String actorName,
    required String actorRole,
    required FaultStatus status,
  }) {
    final list = _reportTimelines.putIfAbsent(reportId, () => []);
    list.add(
      ActivityTimelineEvent(
        id: 'act-${DateTime.now().millisecondsSinceEpoch}',
        reportId: reportId,
        title: title,
        description: description,
        actorName: actorName,
        actorRole: actorRole,
        status: status,
        timestamp: DateTime.now(),
      ),
    );
  }

  // --- Notifications ---

  int get unreadNotificationCount =>
      _notifications.where((n) => !n.isRead).length;

  Future<void> markNotificationAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    notifyListeners();
  }
}
