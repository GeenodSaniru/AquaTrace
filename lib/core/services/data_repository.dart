import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../constants/fault_constants.dart';
import '../errors/app_exception.dart';
import '../models/activity_timeline_event.dart';
import '../models/mock_data.dart';
import '../models/notification_item.dart';
import '../models/report_model.dart';
import 'firebase_service.dart';
import 'report_submission_gateway.dart';

/// Central repository managing reports, activity timelines, and notifications.
///
/// Supports real Cloud Firestore synchronization when credentials are active,
/// and reactive in-memory state during development or demo execution.
class DataRepository with ChangeNotifier {
  final ReportSubmissionGateway _reportSubmissionGateway;
  final List<ReportModel> _reports = [];
  final List<NotificationItem> _notifications = [];
  final Map<String, List<ActivityTimelineEvent>> _reportTimelines = {};
  final Set<String> _submissionsInFlight = {};
  bool _isReportsLoading = false;
  String? _reportsError;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _reportsSubscription;

  List<ReportModel> get reports => List.unmodifiable(_reports);
  List<NotificationItem> get notifications => List.unmodifiable(_notifications);
  bool get isReportsLoading => _isReportsLoading;
  String? get reportsError => _reportsError;

  DataRepository({ReportSubmissionGateway? reportSubmissionGateway})
    : _reportSubmissionGateway =
          reportSubmissionGateway ?? FirebaseReportSubmissionGateway() {
    _initialize();
    if (FirebaseService.isRealFirebase) {
      _listenForReports();
    }
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

  Future<void> addReport(
    ReportModel report, {
    required Uint8List evidenceBytes,
    required String contentType,
  }) async {
    if (report.reportId.trim().isEmpty || report.reporterUid.trim().isEmpty) {
      throw const ValidationException('Report identity is required.');
    }
    if (report.status != FaultStatus.pending) {
      throw const ValidationException(
        'New reports must start with Pending status.',
      );
    }
    if (!report.latitude.isFinite ||
        !report.longitude.isFinite ||
        report.latitude < -90 ||
        report.latitude > 90 ||
        report.longitude < -180 ||
        report.longitude > 180) {
      throw const ValidationException(
        'A valid GPS location is required to submit a report.',
      );
    }
    if (report.reporterName.trim().isEmpty ||
        report.description.trim().length < 10 ||
        report.description.trim().length > 1000 ||
        report.address.trim().length < 3 ||
        report.address.trim().length > 120) {
      throw const ValidationException(
        'Check the reporter name, description, and location details.',
      );
    }
    if (evidenceBytes.isEmpty || evidenceBytes.length > 10 * 1024 * 1024) {
      throw const ValidationException(
        'Choose an evidence photo smaller than 10 MB.',
      );
    }
    if (!const {
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/heic',
    }.contains(contentType)) {
      throw const ValidationException(
        'Choose a JPEG, PNG, WebP, or HEIC evidence photo.',
      );
    }
    if (_submissionsInFlight.contains(report.reportId) ||
        _reports.any((saved) => saved.reportId == report.reportId)) {
      throw const ValidationException(
        'This report has already been submitted.',
      );
    }

    _submissionsInFlight.add(report.reportId);
    try {
      final imageUrl = await _reportSubmissionGateway.uploadEvidence(
        report: report,
        bytes: evidenceBytes,
        contentType: contentType,
      );
      if (imageUrl.trim().isEmpty) {
        throw const DatabaseException(
          'The evidence photo upload did not return a file URL.',
        );
      }

      final savedReport = report.copyWith(beforeImageUrl: imageUrl);
      await _reportSubmissionGateway.createReport(savedReport);

      _reports.insert(0, savedReport);
      _addTimelineEvent(
        reportId: savedReport.reportId,
        title: 'Report Submitted',
        description:
            'Report submitted by ${savedReport.reporterName} for ${savedReport.faultType.displayName}.',
        actorName: savedReport.reporterName,
        actorRole: 'Citizen',
        status: FaultStatus.pending,
      );
      notifyListeners();
    } finally {
      _submissionsInFlight.remove(report.reportId);
    }
  }

  void _listenForReports() {
    _isReportsLoading = true;
    _reportsError = null;
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      _reportsSubscription?.cancel();
      if (user == null) {
        _reports
          ..clear()
          ..addAll(MockData.initialReports);
        _isReportsLoading = false;
        notifyListeners();
        return;
      }

      _reportsSubscription = FirebaseFirestore.instance
          .collection('reports')
          .orderBy('createdAt', descending: true)
          .limit(500)
          .snapshots()
          .listen(
            (snapshot) {
              final reports =
                  snapshot.docs
                      .map(
                        (document) => ReportModel.fromMap(
                          document.data(),
                          documentId: document.id,
                        ),
                      )
                      .toList()
                    ..sort((first, second) {
                      return second.createdAt.compareTo(first.createdAt);
                    });
              _reports
                ..clear()
                ..addAll(reports);
              _isReportsLoading = false;
              _reportsError = null;
              notifyListeners();
            },
            onError: (Object error, StackTrace stackTrace) {
              _isReportsLoading = false;
              _reportsError = 'Reports could not be refreshed. Pull to retry.';
              debugPrint('[AquaTrace] Report sync failed: $error');
              notifyListeners();
            },
          );
    });
  }

  void retryReportsSync() {
    if (!FirebaseService.isRealFirebase) return;
    _reportsSubscription?.cancel();
    _authSubscription?.cancel();
    _listenForReports();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _reportsSubscription?.cancel();
    super.dispose();
  }

  Future<void> updateReportStatus({
    required String reportId,
    required FaultStatus newStatus,
    required String actorName,
    required String actorRole,
    String? note,
  }) async {
    await _requireAuthorizedActor(actorRole);
    final index = _reports.indexWhere((r) => r.reportId == reportId);
    if (index != -1) {
      final report = _reports[index];
      _validateStatusTransition(report.status, newStatus, actorRole);
      final updatedAt = DateTime.now();
      final updated = _reports[index].copyWith(
        status: newStatus,
        updatedAt: updatedAt,
        repairNotes: note ?? report.repairNotes,
      );
      await _persistReportUpdate(reportId, {
        'status': newStatus.name,
        'updatedAt': updatedAt.toIso8601String(),
        if (note != null) 'repairNotes': note,
      });
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
    await _requireAuthorizedActor('Admin');
    final index = _reports.indexWhere((r) => r.reportId == reportId);
    if (index != -1) {
      final report = _reports[index];
      if (report.status != FaultStatus.pending &&
          report.status != FaultStatus.disputed) {
        throw const ValidationException(
          'Only pending or disputed reports can be assigned.',
        );
      }
      final updatedAt = DateTime.now();
      await _persistReportUpdate(reportId, {
        'assignedTechnicianUid': technicianUid,
        'assignedTechnicianName': technicianName,
        'assignedAt': updatedAt.toIso8601String(),
        'status': FaultStatus.assigned.name,
        'updatedAt': updatedAt.toIso8601String(),
      });
      _reports[index] = _reports[index].copyWith(
        assignedTechnicianUid: technicianUid,
        assignedTechnicianName: technicianName,
        assignedAt: updatedAt,
        status: FaultStatus.assigned,
        updatedAt: updatedAt,
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

  Future<void> updateReportSeverity({
    required String reportId,
    required FaultSeverity severity,
    required String adminName,
  }) async {
    await _requireAuthorizedActor('Admin');
    final index = _reports.indexWhere((r) => r.reportId == reportId);
    if (index == -1) return;
    final updatedAt = DateTime.now();
    await _persistReportUpdate(reportId, {
      'severity': severity.name,
      'updatedAt': updatedAt.toIso8601String(),
    });
    _reports[index] = _reports[index].copyWith(
      severity: severity,
      updatedAt: updatedAt,
    );
    _addTimelineEvent(
      reportId: reportId,
      title: 'Priority Updated',
      description: 'Priority set to ${severity.displayName} by $adminName.',
      actorName: adminName,
      actorRole: 'Admin',
      status: _reports[index].status,
    );
    notifyListeners();
  }

  Future<void> _requireAuthorizedActor(String actorRole) async {
    if (actorRole.trim().toLowerCase() == 'admin' &&
        FirebaseService.isRealFirebase) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw const PermissionException('Sign in as an administrator first.');
      }
      final user = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (user.data()?['role'] != 'admin') {
        throw const PermissionException('Administrator access is required.');
      }
    } else if (actorRole.trim().isEmpty) {
      throw const PermissionException('A signed-in role is required.');
    }
  }

  void _validateStatusTransition(
    FaultStatus current,
    FaultStatus next,
    String actorRole,
  ) {
    if (current == next) return;
    final allowed = switch (actorRole.trim().toLowerCase()) {
      'admin' =>
        current == FaultStatus.pending && next == FaultStatus.assigned ||
            current == FaultStatus.disputed && next == FaultStatus.assigned,
      'technician' =>
        (current == FaultStatus.assigned && next == FaultStatus.ongoing) ||
            (current == FaultStatus.ongoing && next == FaultStatus.completed),
      _ => false,
    };
    if (!allowed) {
      throw ValidationException(
        'Cannot change ${current.displayName} to ${next.displayName}.',
      );
    }
  }

  Future<void> _persistReportUpdate(
    String reportId,
    Map<String, dynamic> changes,
  ) async {
    if (!FirebaseService.isRealFirebase) return;
    await FirebaseFirestore.instance
        .collection('reports')
        .doc(reportId)
        .update(changes);
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
    if (FirebaseService.isRealFirebase) {
      final event = list.last;
      FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .collection('activity')
          .doc(event.id)
          .set(event.toMap())
          .catchError((error) {
            debugPrint('[AquaTrace] Activity write failed: $error');
          });
    }
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
