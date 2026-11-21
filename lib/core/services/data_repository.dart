import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../constants/fault_constants.dart';
import '../errors/app_exception.dart';
import '../models/activity_timeline_event.dart';
import '../models/dispute_record_model.dart';
import '../models/mock_data.dart';
import '../models/notification_item.dart';
import '../models/report_model.dart';
import '../models/user_model.dart';
import '../models/verification_vote_model.dart';
import '../../features/verification/services/community_verification_service.dart';
import 'community_verification_gateway.dart';
import 'firebase_service.dart';
import 'report_submission_gateway.dart';
import 'technician_job_gateway.dart';

/// Central repository managing reports, activity timelines, and notifications.
///
/// Supports real Cloud Firestore synchronization when credentials are active,
/// and reactive in-memory state during development or demo execution.
class DataRepository with ChangeNotifier {
  final ReportSubmissionGateway _reportSubmissionGateway;
  final TechnicianJobGateway _technicianJobGateway;
  final CommunityVerificationGateway _communityVerificationGateway;
  final List<ReportModel> _reports = [];
  final List<NotificationItem> _notifications = [];
  final Map<String, List<ActivityTimelineEvent>> _reportTimelines = {};
  final Map<String, List<VerificationVoteModel>> _reportVerifications = {};
  final Map<String, List<DisputeRecordModel>> _reportDisputes = {};
  final Set<String> _submissionsInFlight = {};
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _reportsSubscription;
  bool _reportsLoading = false;
  String? _reportsErrorMessage;

  List<ReportModel> get reports => List.unmodifiable(_reports);
  List<NotificationItem> get notifications => List.unmodifiable(_notifications);
  bool get isReportsLoading => _reportsLoading;
  String? get reportsError => _reportsErrorMessage;
  bool get reportsLoading => _reportsLoading;
  String? get reportsErrorMessage => _reportsErrorMessage;

  DataRepository({
    ReportSubmissionGateway? reportSubmissionGateway,
    @visibleForTesting List<ReportModel>? initialReports,
    TechnicianJobGateway? technicianJobGateway,
    CommunityVerificationGateway? communityVerificationGateway,
  }) : _reportSubmissionGateway =
           reportSubmissionGateway ?? FirebaseReportSubmissionGateway(),
       _technicianJobGateway =
           technicianJobGateway ?? FirebaseTechnicianJobGateway(),
       _communityVerificationGateway =
           communityVerificationGateway ??
           FirebaseCommunityVerificationGateway() {
    if (initialReports != null) {
      _reports.addAll(initialReports);
    } else {
      _initialize();
    }
    if (FirebaseService.isRealFirebase) {
      _listenForReports();
    }
  }

  void _initialize() {
    if (!FirebaseService.isRealFirebase) {
      _reports.addAll(MockData.initialReports);
      _notifications.addAll(MockData.initialNotifications);
      _reportTimelines['AT-2026-00124'] = List.from(
        MockData.activityTimelineFor124,
      );
      _reportVerifications['AT-2026-00126'] = [
        VerificationVoteModel(
          voterUid: 'citizen-sarath-010',
          voterName: 'Sarath Gunawardena',
          reportId: 'AT-2026-00126',
          createdAt: DateTime(2026, 9, 24, 12, 0),
          note: 'Roadway is clear and leak is stopped.',
        ),
        VerificationVoteModel(
          voterUid: 'citizen-anula-011',
          voterName: 'Anula Weerasinghe',
          reportId: 'AT-2026-00126',
          createdAt: DateTime(2026, 9, 24, 12, 30),
          note: 'Confirmed dry pavement.',
        ),
      ];
      _reportDisputes['AT-2026-00127'] = [
        DisputeRecordModel(
          voterUid: 'citizen-priyantha-012',
          voterName: 'Priyantha Alwis',
          reportId: 'AT-2026-00127',
          reason: 'Water continues to pool along pavement curb.',
          createdAt: DateTime(2026, 9, 23, 10, 15),
        ),
        DisputeRecordModel(
          voterUid: 'citizen-chandani-013',
          voterName: 'Chandani Silva',
          reportId: 'AT-2026-00127',
          reason: 'Repair asphalt collapsed; leak still active.',
          createdAt: DateTime(2026, 9, 23, 14, 45),
        ),
      ];
    }
  }

  // --- Reports Query & Management ---

  List<ReportModel> getReportsForCitizen(String uid) {
    return _reports.where((r) => r.reporterUid == uid).toList();
  }

  List<ReportModel> getReportsForTechnician(String technicianUid) {
    final normalizedUid = technicianUid.trim();
    if (normalizedUid.isEmpty) {
      return const [];
    }
    return _reports
        .where((r) => r.assignedTechnicianUid?.trim() == normalizedUid)
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
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      unawaited(_listenForUserReports(user));
    });
  }

  Future<void> _listenForUserReports(User? user) async {
    _reportsSubscription?.cancel();
    _reportsErrorMessage = null;
    if (user == null) {
      _reports.clear();
      _reportsLoading = false;
      notifyListeners();
      return;
    }

    _reportsLoading = true;
    _reports.clear();
    notifyListeners();
    try {
      final userProfile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final role = userProfile.data()?['role'] as String?;
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('reports')
          .limit(AppConfig.maximumMapReports);
      if (role == 'technician') {
        query = query.where('assignedTechnicianUid', isEqualTo: user.uid);
      } else {
        query = query.orderBy('createdAt', descending: true);
      }

      _reportsSubscription = query.snapshots().listen(
        (snapshot) {
          final reports = <ReportModel>[];
          for (final document in snapshot.docs) {
            try {
              reports.add(
                ReportModel.fromMap(document.data(), documentId: document.id),
              );
            } on Object catch (error, stackTrace) {
              debugPrint(
                '[AquaTrace] Skipping invalid report ${document.id}: '
                '$error\n$stackTrace',
              );
            }
          }
          reports.sort(
            (first, second) => second.createdAt.compareTo(first.createdAt),
          );
          _reports
            ..clear()
            ..addAll(reports);
          _reportsLoading = false;
          _reportsErrorMessage = null;
          notifyListeners();
        },
        onError: (Object error, StackTrace stackTrace) {
          _reportsLoading = false;
          _reportsErrorMessage = _reportSyncErrorMessage(error);
          debugPrint('[AquaTrace] Report sync failed: $error\n$stackTrace');
          notifyListeners();
        },
      );
    } catch (error, stackTrace) {
      _reportsLoading = false;
      _reportsErrorMessage = _reportSyncErrorMessage(error);
      debugPrint('[AquaTrace] Report query setup failed: $error\n$stackTrace');
      notifyListeners();
    }
  }

  String _reportSyncErrorMessage(Object error) {
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'You do not have permission to view reports.';
      }
      if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
        return 'Could not refresh reports. Check your internet connection.';
      }
      if (error.code == 'failed-precondition') {
        return 'Reports could not be loaded because the Firestore query needs configuration.';
      }
    }
    return 'Could not load reports. Please try again.';
  }

  void retryReportsSync() {
    if (!FirebaseService.isRealFirebase) return;
    _reportsSubscription?.cancel();
    _authSubscription?.cancel();
    _listenForReports();
  }

  void retryReportSync() => retryReportsSync();

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
        ...?note == null ? null : {'repairNotes': note},
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

  Future<void> updateTechnicianJobStatus({
    required String reportId,
    required String technicianUid,
    required String actorName,
    required FaultStatus newStatus,
    String? note,
  }) async {
    if (technicianUid.trim().isEmpty) {
      throw const PermissionException('Technician identity is required.');
    }
    final index = _reports.indexWhere((r) => r.reportId == reportId);
    if (index == -1) {
      throw const ValidationException('The assigned job could not be found.');
    }

    final current = _reports[index];
    if (current.assignedTechnicianUid != technicianUid) {
      throw const PermissionException(
        'Only the assigned technician can update this job.',
      );
    }
    if (!_isValidTechnicianTransition(current.status, newStatus)) {
      throw const ValidationException(
        'This job cannot move to the selected status.',
      );
    }
    if (newStatus == FaultStatus.completed &&
        (current.afterImageUrl == null || current.afterImageUrl!.isEmpty)) {
      throw const ValidationException(
        'Add an after-repair photo before completing the job.',
      );
    }

    final updated = current.copyWith(
      status: newStatus,
      repairNotes: note ?? current.repairNotes,
      updatedAt: DateTime.now(),
    );
    final activity = ActivityTimelineEvent(
      id: 'act-${DateTime.now().microsecondsSinceEpoch}',
      reportId: reportId,
      title: 'Job ${newStatus.displayName}',
      description:
          note ??
          'Job status changed to ${newStatus.displayName} by $actorName.',
      actorName: actorName,
      actorRole: 'Technician',
      status: newStatus,
      timestamp: DateTime.now(),
    );

    if (FirebaseService.isRealFirebase) {
      await _technicianJobGateway.updateJob(
        report: updated,
        activity: activity,
      );
    }
    _reports[index] = updated;
    _reportTimelines.putIfAbsent(reportId, () => []).add(activity);
    notifyListeners();
  }

  Future<void> uploadTechnicianAfterRepairPhoto({
    required String reportId,
    required String technicianUid,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (technicianUid.trim().isEmpty) {
      throw const PermissionException('Technician identity is required.');
    }
    final index = _reports.indexWhere((r) => r.reportId == reportId);
    if (index == -1) {
      throw const ValidationException('The assigned job could not be found.');
    }
    final report = _reports[index];
    if (report.assignedTechnicianUid != technicianUid) {
      throw const PermissionException(
        'Only the assigned technician can upload repair evidence.',
      );
    }
    if (report.status != FaultStatus.ongoing) {
      throw const ValidationException(
        'Start the job before adding repair evidence.',
      );
    }
    if (!const {
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/heic',
    }.contains(contentType)) {
      throw const ValidationException(
        'Choose a JPEG, PNG, WebP, or HEIC repair photo.',
      );
    }

    if (!FirebaseService.isRealFirebase) {
      throw const PermissionException(
        'Demo accounts cannot upload technician evidence.',
      );
    }
    final imageUrl = await _technicianJobGateway.uploadAfterRepairPhoto(
      report: report,
      bytes: bytes,
      contentType: contentType,
    );
    final updated = report.copyWith(
      afterImageUrl: imageUrl,
      updatedAt: DateTime.now(),
    );
    await _technicianJobGateway.updateRepairEvidence(report: updated);
    _reports[index] = updated;
    notifyListeners();
  }

  Future<void> saveTechnicianRepairNotes({
    required String reportId,
    required String technicianUid,
    required String actorName,
    required String notes,
  }) async {
    if (technicianUid.trim().isEmpty) {
      throw const PermissionException('Technician identity is required.');
    }
    final index = _reports.indexWhere((r) => r.reportId == reportId);
    if (index == -1) {
      throw const ValidationException('The assigned job could not be found.');
    }
    final current = _reports[index];
    if (current.assignedTechnicianUid != technicianUid) {
      throw const PermissionException(
        'Only the assigned technician can update this job.',
      );
    }
    if (current.status != FaultStatus.ongoing) {
      throw const ValidationException(
        'Start the job before adding repair notes.',
      );
    }
    final trimmedNotes = notes.trim();
    if (trimmedNotes.length < 3 || trimmedNotes.length > 2000) {
      throw const ValidationException(
        'Repair notes must be between 3 and 2000 characters.',
      );
    }

    final updated = current.copyWith(
      repairNotes: trimmedNotes,
      updatedAt: DateTime.now(),
    );
    final activity = ActivityTimelineEvent(
      id: 'act-${DateTime.now().microsecondsSinceEpoch}',
      reportId: reportId,
      title: 'Repair Notes Updated',
      description: 'Repair notes updated by $actorName.',
      actorName: actorName,
      actorRole: 'Technician',
      status: current.status,
      timestamp: DateTime.now(),
    );
    if (FirebaseService.isRealFirebase) {
      await _technicianJobGateway.updateJob(
        report: updated,
        activity: activity,
      );
    }
    _reports[index] = updated;
    _reportTimelines.putIfAbsent(reportId, () => []).add(activity);
    notifyListeners();
  }

  bool _isValidTechnicianTransition(FaultStatus current, FaultStatus next) {
    return (current == FaultStatus.assigned && next == FaultStatus.ongoing) ||
        (current == FaultStatus.ongoing && next == FaultStatus.completed);
  }

  Future<void> assignTechnician({
    required String reportId,
    required String technicianUid,
    required String technicianName,
    required String adminName,
    required String actorRole,
  }) async {
    await _requireAuthorizedActor(actorRole);
    if (actorRole.trim().toLowerCase() != 'admin') {
      throw const PermissionException('Administrator access is required.');
    }
    if (technicianUid.trim().isEmpty || technicianName.trim().isEmpty) {
      throw const ValidationException(
        'A technician identity is required for assignment.',
      );
    }
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
    required String actorRole,
  }) async {
    await _requireAuthorizedActor(actorRole);
    if (actorRole.trim().toLowerCase() != 'admin') {
      throw const PermissionException('Administrator access is required.');
    }
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

  // --- Community Verification & Disputes (Member 7) ---

  List<VerificationVoteModel> getVerificationsForReport(String reportId) {
    return List.unmodifiable(_reportVerifications[reportId] ?? const []);
  }

  List<DisputeRecordModel> getDisputesForReport(String reportId) {
    return List.unmodifiable(_reportDisputes[reportId] ?? const []);
  }

  bool hasUserVotedOnReport({
    required String reportId,
    required String userUid,
  }) {
    final normalizedUid = userUid.trim();
    final hasVerified =
        _reportVerifications[reportId]?.any(
          (v) => v.voterUid.trim() == normalizedUid,
        ) ??
        false;
    final hasDisputed =
        _reportDisputes[reportId]?.any(
          (d) => d.voterUid.trim() == normalizedUid,
        ) ??
        false;
    return hasVerified || hasDisputed;
  }

  /// Returns completed reports eligible for community verification within [radiusKm].
  List<ReportModel> getCompletedReportsNearby({
    required double latitude,
    required double longitude,
    double? radiusKm,
  }) {
    final effectiveRadiusKm =
        radiusKm ?? CommunityVerificationService.defaultRadiusKm;
    return _reports.where((report) {
      if (report.status != FaultStatus.completed) return false;
      final dist = CommunityVerificationService.calculateDistanceKm(
        startLatitude: latitude,
        startLongitude: longitude,
        endLatitude: report.latitude,
        endLongitude: report.longitude,
      );
      return dist <= effectiveRadiusKm;
    }).toList();
  }

  Future<void> submitCommunityVerification({
    required ReportModel report,
    required UserModel voter,
    String? note,
    double? userLatitude,
    double? userLongitude,
    double radiusKm = 0,
  }) async {
    final effectiveRadius = radiusKm > 0
        ? radiusKm
        : CommunityVerificationService.defaultRadiusKm;

    final submissionKey = 'verify_${report.reportId}_${voter.uid}';
    if (_submissionsInFlight.contains(submissionKey)) {
      throw const ValidationException(
        'A verification submission is already in progress.',
      );
    }
    _submissionsInFlight.add(submissionKey);

    try {
      final alreadyVoted = hasUserVotedOnReport(
        reportId: report.reportId,
        userUid: voter.uid,
      );

      final eligibility = CommunityVerificationService.checkEligibility(
        report: report,
        user: voter,
        userLatitude: userLatitude,
        userLongitude: userLongitude,
        hasAlreadyVoted: alreadyVoted,
        radiusKm: effectiveRadius,
      );

      if (!eligibility.isEligible) {
        throw ValidationException(
          eligibility.reason ?? 'You are not eligible to verify this repair.',
        );
      }

      final index = _reports.indexWhere((r) => r.reportId == report.reportId);
      if (index == -1) {
        throw const DatabaseException('Report not found.');
      }

      final currentReport = _reports[index];
      final newCount = currentReport.verificationCount + 1;
      final vote = VerificationVoteModel(
        voterUid: voter.uid,
        voterName: voter.displayName,
        reportId: report.reportId,
        createdAt: DateTime.now(),
        note: note,
      );

      final activity = ActivityTimelineEvent(
        id: 'act-${DateTime.now().millisecondsSinceEpoch}',
        reportId: report.reportId,
        title: 'Community Verification Confirmed',
        description:
            '${voter.displayName} confirmed repair completion.${note != null && note.isNotEmpty ? ' Note: "$note"' : ''}',
        actorName: voter.displayName,
        actorRole: 'Citizen Verification',
        status: FaultStatus.completed,
        timestamp: DateTime.now(),
      );

      await _communityVerificationGateway.submitVerification(
        report: currentReport,
        vote: vote,
        activity: activity,
        newVerificationCount: newCount,
      );

      // Update in-memory state
      _reportVerifications.putIfAbsent(report.reportId, () => []).add(vote);
      _reports[index] = currentReport.copyWith(
        verificationCount: newCount,
        updatedAt: DateTime.now(),
      );

      _reportTimelines.putIfAbsent(report.reportId, () => []).add(activity);

      // If threshold reached, add milestone activity and notify workflows (Member 8 coordination)
      if (newCount >= CommunityVerificationService.confirmationThreshold &&
          currentReport.verificationCount <
              CommunityVerificationService.confirmationThreshold) {
        _addTimelineEvent(
          reportId: report.reportId,
          title: 'Community Verified',
          description:
              '${CommunityVerificationService.confirmationThreshold} nearby citizens confirmed the repair is complete.',
          actorName: 'Community',
          actorRole: 'Citizen Verification',
          status: FaultStatus.completed,
        );

        // Notify Reporter
        _notifications.insert(
          0,
          NotificationItem(
            id: 'notif-${DateTime.now().millisecondsSinceEpoch}-rep-v',
            recipientUid: currentReport.reporterUid,
            title: 'Repair Verified',
            body:
                'Community confirmed resolution for your report ${report.reportId}.',
            reportId: report.reportId,
            type: 'verification',
            isRead: false,
            createdAt: DateTime.now(),
          ),
        );

        // Notify Assigned Technician
        if (currentReport.assignedTechnicianUid != null) {
          _notifications.insert(
            0,
            NotificationItem(
              id: 'notif-${DateTime.now().millisecondsSinceEpoch}-tech-v',
              recipientUid: currentReport.assignedTechnicianUid!,
              title: 'Repair Verified by Community',
              body:
                  '3 nearby citizens confirmed your repair on ${report.reportId} is complete.',
              reportId: report.reportId,
              type: 'verification',
              isRead: false,
              createdAt: DateTime.now(),
            ),
          );
        }

        // Notify Admin workflow
        _notifications.insert(
          0,
          NotificationItem(
            id: 'notif-${DateTime.now().millisecondsSinceEpoch}-adm-v',
            recipientUid: MockData.adminUser.uid,
            title: 'Repair Verified by Community',
            body:
                'Report ${report.reportId} reached the community verification threshold.',
            reportId: report.reportId,
            type: 'verification',
            isRead: false,
            createdAt: DateTime.now(),
          ),
        );
      }

      notifyListeners();
    } finally {
      _submissionsInFlight.remove(submissionKey);
    }
  }

  Future<void> submitCommunityDispute({
    required ReportModel report,
    required UserModel voter,
    required String reason,
    Uint8List? evidenceBytes,
    String? contentType,
    double? userLatitude,
    double? userLongitude,
    double radiusKm = 0,
  }) async {
    final effectiveRadius = radiusKm > 0
        ? radiusKm
        : CommunityVerificationService.defaultRadiusKm;

    final submissionKey = 'dispute_${report.reportId}_${voter.uid}';
    if (_submissionsInFlight.contains(submissionKey)) {
      throw const ValidationException(
        'A dispute submission is already in progress.',
      );
    }
    _submissionsInFlight.add(submissionKey);

    try {
      if (reason.trim().isEmpty) {
        throw const ValidationException('A dispute reason is required.');
      }

      final alreadyVoted = hasUserVotedOnReport(
        reportId: report.reportId,
        userUid: voter.uid,
      );

      final eligibility = CommunityVerificationService.checkEligibility(
        report: report,
        user: voter,
        userLatitude: userLatitude,
        userLongitude: userLongitude,
        hasAlreadyVoted: alreadyVoted,
        radiusKm: effectiveRadius,
      );

      if (!eligibility.isEligible) {
        throw ValidationException(
          eligibility.reason ?? 'You are not eligible to dispute this repair.',
        );
      }

      final index = _reports.indexWhere((r) => r.reportId == report.reportId);
      if (index == -1) {
        throw const DatabaseException('Report not found.');
      }

      final currentReport = _reports[index];
      final newDisputeCount = currentReport.disputeCount + 1;

      String? evidenceUrl;
      if (evidenceBytes != null && evidenceBytes.isNotEmpty) {
        if (evidenceBytes.length > 10 * 1024 * 1024) {
          throw const ValidationException(
            'Choose an evidence photo smaller than 10 MB.',
          );
        }
        evidenceUrl = await _communityVerificationGateway.uploadDisputePhoto(
          reportId: report.reportId,
          voterUid: voter.uid,
          bytes: evidenceBytes,
          contentType: contentType ?? 'image/jpeg',
        );
      }

      final dispute = DisputeRecordModel(
        voterUid: voter.uid,
        voterName: voter.displayName,
        reportId: report.reportId,
        reason: reason.trim(),
        evidenceImageUrl: evidenceUrl,
        createdAt: DateTime.now(),
      );

      final activity = ActivityTimelineEvent(
        id: 'act-${DateTime.now().millisecondsSinceEpoch}',
        reportId: report.reportId,
        title: 'Dispute Raised',
        description:
            'A dispute has been raised by ${voter.displayName}. Reason: "${reason.trim()}". Status reopened for Admin review.',
        actorName: voter.displayName,
        actorRole: 'Citizen Dispute',
        status: FaultStatus.disputed,
        timestamp: DateTime.now(),
      );

      await _communityVerificationGateway.submitDispute(
        report: currentReport,
        dispute: dispute,
        activity: activity,
        newDisputeCount: newDisputeCount,
      );

      // Update in-memory state: auto-reopens report to disputed
      _reportDisputes.putIfAbsent(report.reportId, () => []).add(dispute);
      _reports[index] = currentReport.copyWith(
        status: FaultStatus.disputed,
        disputeCount: newDisputeCount,
        updatedAt: DateTime.now(),
      );

      _reportTimelines.putIfAbsent(report.reportId, () => []).add(activity);

      // 1. Notify Admin workflow (Member 5 coordination)
      _notifications.insert(
        0,
        NotificationItem(
          id: 'notif-${DateTime.now().millisecondsSinceEpoch}-adm',
          recipientUid: MockData.adminUser.uid,
          title: 'Dispute Raised',
          body:
              'Dispute raised on ${report.reportId} by ${voter.displayName}. Case reopened for Admin review.',
          reportId: report.reportId,
          type: 'dispute',
          isRead: false,
          createdAt: DateTime.now(),
        ),
      );

      // 2. Notify Assigned Technician
      if (currentReport.assignedTechnicianUid != null) {
        _notifications.insert(
          0,
          NotificationItem(
            id: 'notif-${DateTime.now().millisecondsSinceEpoch}-tech',
            recipientUid: currentReport.assignedTechnicianUid!,
            title: 'Repair Disputed',
            body:
                'Completed repair on ${report.reportId} was disputed by the community and reopened for review.',
            reportId: report.reportId,
            type: 'dispute',
            isRead: false,
            createdAt: DateTime.now(),
          ),
        );
      }

      // 3. Notify Original Reporter
      if (currentReport.reporterUid.isNotEmpty &&
          currentReport.reporterUid != voter.uid) {
        _notifications.insert(
          0,
          NotificationItem(
            id: 'notif-${DateTime.now().millisecondsSinceEpoch}-rep',
            recipientUid: currentReport.reporterUid,
            title: 'Dispute Opened',
            body:
                'A community dispute has been raised on your report ${report.reportId}. Admin is reviewing.',
            reportId: report.reportId,
            type: 'dispute',
            isRead: false,
            createdAt: DateTime.now(),
          ),
        );
      }

      // 4. Confirmation for voter
      _notifications.insert(
        0,
        NotificationItem(
          id: 'notif-${DateTime.now().millisecondsSinceEpoch}-voter',
          recipientUid: voter.uid,
          title: 'Dispute Submitted',
          body:
              'Your dispute on ${report.reportId} was submitted to the Water Board.',
          reportId: report.reportId,
          type: 'dispute',
          isRead: false,
          createdAt: DateTime.now(),
        ),
      );

      notifyListeners();
    } finally {
      _submissionsInFlight.remove(submissionKey);
    }
  }
}
