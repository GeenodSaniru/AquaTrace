import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:aquatrace/core/constants/app_roles.dart';
import 'package:aquatrace/core/constants/fault_constants.dart';
import 'package:aquatrace/core/errors/app_exception.dart';
import 'package:aquatrace/core/models/activity_timeline_event.dart';
import 'package:aquatrace/core/models/dispute_record_model.dart';
import 'package:aquatrace/core/models/notification_item.dart';
import 'package:aquatrace/core/models/report_model.dart';
import 'package:aquatrace/core/models/user_model.dart';
import 'package:aquatrace/core/models/verification_vote_model.dart';
import 'package:aquatrace/core/services/community_verification_gateway.dart';
import 'package:aquatrace/core/services/data_repository.dart';
import 'package:aquatrace/features/auth/providers/auth_provider.dart';
import 'package:aquatrace/features/verification/presentation/citizen_verification_screen.dart';
import 'package:aquatrace/features/verification/services/community_verification_service.dart';

/// Notifications are per recipient: the backend (demo mode: the repository)
/// delivers each message to its recipient's own inbox. Bind [uid] and read it.
Future<List<NotificationItem>> inboxOf(DataRepository repo, String uid) async {
  repo.bindNotificationUser(uid);
  await Future<void>.delayed(Duration.zero);
  return repo.notifications;
}

class MockCommunityVerificationGateway implements CommunityVerificationGateway {
  final List<VerificationVoteModel> recordedVotes = [];
  final List<DisputeRecordModel> recordedDisputes = [];
  final List<ActivityTimelineEvent> recordedActivities = [];
  bool throwError = false;
  Completer<void>? pendingCompleter;

  @override
  Future<void> submitVerification({
    required ReportModel report,
    required VerificationVoteModel vote,
    required ActivityTimelineEvent activity,
    required int newVerificationCount,
  }) async {
    if (throwError) {
      throw const NetworkException('Simulated network error');
    }
    if (pendingCompleter != null) {
      await pendingCompleter!.future;
    }
    recordedVotes.add(vote);
    recordedActivities.add(activity);
  }

  @override
  Future<void> submitDispute({
    required ReportModel report,
    required DisputeRecordModel dispute,
    required ActivityTimelineEvent activity,
    required int newDisputeCount,
  }) async {
    if (throwError) {
      throw const NetworkException('Simulated network error');
    }
    if (pendingCompleter != null) {
      await pendingCompleter!.future;
    }
    recordedDisputes.add(dispute);
    recordedActivities.add(activity);
  }

  @override
  Future<String> uploadDisputePhoto({
    required String reportId,
    required String voterUid,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (throwError) {
      throw const NetworkException('Simulated network upload failure');
    }
    return 'https://storage.googleapis.com/aquatrace/dispute/$voterUid/$reportId.jpg';
  }
}

class MockAuthProvider with ChangeNotifier implements AuthProvider {
  final UserModel? _mockUser;

  MockAuthProvider([this._mockUser]);

  @override
  UserModel? get currentUser => _mockUser;

  @override
  UserRole get currentRole => _mockUser?.role ?? UserRole.citizen;

  @override
  bool get isAuthenticated => _mockUser != null;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  void clearError() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('CommunityVerificationService Unit Tests', () {
    final testReport = ReportModel(
      reportId: 'AT-TEST-001',
      reporterUid: 'reporter-uid-001',
      reporterName: 'Original Reporter',
      faultType: FaultType.pipeLeak,
      description: 'Underground leak',
      severity: FaultSeverity.high,
      status: FaultStatus.completed,
      latitude: 6.8912,
      longitude: 79.8554,
      address: 'Galle Road, Colombo 03',
      assignedTechnicianUid: 'tech-uid-002',
      assignedTechnicianName: 'Kasun Technician',
      createdAt: DateTime(2026, 9, 24, 10, 0),
    );

    final eligibleCitizen = UserModel(
      uid: 'citizen-auditor-003',
      email: 'citizen@test.lk',
      displayName: 'Auditor Citizen',
      phoneNumber: '+94 77 123 4567',
      role: UserRole.citizen,
      assignedArea: 'Colombo 03',
      createdAt: DateTime(2026, 9, 24, 10, 0),
    );

    test('calculates accurate distance with Haversine formula', () {
      // Short distance within Colombo (Galle Rd to Duplication Rd ~ 0.93 km)
      final distanceNearby = CommunityVerificationService.calculateDistanceKm(
        startLatitude: 6.8912,
        startLongitude: 79.8554,
        endLatitude: 6.8995,
        endLongitude: 79.8542,
      );
      expect(distanceNearby, greaterThan(0.5));
      expect(distanceNearby, lessThan(2.0));

      // Far distance (Colombo to Kandy ~ 95-115 km)
      final distanceFar = CommunityVerificationService.calculateDistanceKm(
        startLatitude: 6.8912,
        startLongitude: 79.8554,
        endLatitude: 7.2906,
        endLongitude: 80.6337,
      );
      expect(distanceFar, greaterThan(80.0));
    });

    test('approves eligible citizen within radius for completed report', () {
      final eligibility = CommunityVerificationService.checkEligibility(
        report: testReport,
        user: eligibleCitizen,
        userLatitude: 6.8920,
        userLongitude: 79.8560,
        hasAlreadyVoted: false,
      );

      expect(eligibility.isEligible, isTrue);
      expect(eligibility.isWithinRadius, isTrue);
      expect(eligibility.hasAlreadyVoted, isFalse);
      expect(eligibility.distanceKm, lessThan(1.0));
    });

    test('rejects non-citizen roles from community verification', () {
      final adminUser = UserModel(
        uid: 'admin-001',
        email: 'admin@test.lk',
        displayName: 'Admin User',
        phoneNumber: '+94 11 234 5678',
        role: UserRole.admin,
        assignedArea: 'Colombo',
        createdAt: DateTime(2026, 9, 24, 10, 0),
      );

      final eligibility = CommunityVerificationService.checkEligibility(
        report: testReport,
        user: adminUser,
        userLatitude: 6.8912,
        userLongitude: 79.8554,
        hasAlreadyVoted: false,
      );

      expect(eligibility.isEligible, isFalse);
      expect(
        eligibility.reason,
        contains('Only community citizens can participate'),
      );
    });

    test('rejects the original reporter (conflict-of-interest prevention)', () {
      final reporterUser = UserModel(
        uid: 'reporter-uid-001',
        email: 'reporter@test.lk',
        displayName: 'Original Reporter',
        phoneNumber: '+94 77 987 6543',
        role: UserRole.citizen,
        assignedArea: 'Colombo 03',
        createdAt: DateTime(2026, 9, 24, 10, 0),
      );

      final eligibility = CommunityVerificationService.checkEligibility(
        report: testReport,
        user: reporterUser,
        userLatitude: 6.8912,
        userLongitude: 79.8554,
        hasAlreadyVoted: false,
      );

      expect(eligibility.isEligible, isFalse);
      expect(
        eligibility.reason,
        contains('As the original reporter, you cannot submit'),
      );
    });

    test(
      'rejects the assigned technician (conflict-of-interest prevention)',
      () {
        final technicianUser = UserModel(
          uid: 'tech-uid-002',
          email: 'tech@test.lk',
          displayName: 'Kasun Technician',
          phoneNumber: '+94 71 555 4321',
          role: UserRole.citizen, // even if role says citizen in test
          assignedArea: 'Colombo 03',
          createdAt: DateTime(2026, 9, 24, 10, 0),
        );

        final eligibility = CommunityVerificationService.checkEligibility(
          report: testReport,
          user: technicianUser,
          userLatitude: 6.8912,
          userLongitude: 79.8554,
          hasAlreadyVoted: false,
        );

        expect(eligibility.isEligible, isFalse);
        expect(
          eligibility.reason,
          contains('cannot audit or verify their own repair work'),
        );
      },
    );

    test('rejects reports that are not in completed status', () {
      final ongoingReport = testReport.copyWith(status: FaultStatus.ongoing);

      final eligibility = CommunityVerificationService.checkEligibility(
        report: ongoingReport,
        user: eligibleCitizen,
        userLatitude: 6.8912,
        userLongitude: 79.8554,
        hasAlreadyVoted: false,
      );

      expect(eligibility.isEligible, isFalse);
      expect(
        eligibility.reason,
        contains('Only repairs marked as completed can be verified'),
      );
    });

    test('rejects duplicate voting', () {
      final eligibility = CommunityVerificationService.checkEligibility(
        report: testReport,
        user: eligibleCitizen,
        userLatitude: 6.8912,
        userLongitude: 79.8554,
        hasAlreadyVoted: true,
      );

      expect(eligibility.isEligible, isFalse);
      expect(
        eligibility.reason,
        contains('You have already submitted your response'),
      );
    });

    test('rejects citizens outside the 5 km radius', () {
      // 95 km away in Kandy
      final eligibility = CommunityVerificationService.checkEligibility(
        report: testReport,
        user: eligibleCitizen,
        userLatitude: 7.2906,
        userLongitude: 80.6337,
        hasAlreadyVoted: false,
      );

      expect(eligibility.isEligible, isFalse);
      expect(eligibility.isWithinRadius, isFalse);
      expect(
        eligibility.reason,
        contains('Verification is only allowed within 5 km'),
      );
    });

    test('rejects unauthenticated user (null user)', () {
      final eligibility = CommunityVerificationService.checkEligibility(
        report: testReport,
        user: null,
        userLatitude: 6.8912,
        userLongitude: 79.8554,
        hasAlreadyVoted: false,
      );

      expect(eligibility.isEligible, isFalse);
      expect(
        eligibility.reason,
        contains('You must be signed in to verify repairs'),
      );
      expect(eligibility.isWithinRadius, isFalse);
    });

    test('rejects when GPS or location coordinates are unavailable (null)', () {
      final eligibility = CommunityVerificationService.checkEligibility(
        report: testReport,
        user: eligibleCitizen,
        userLatitude: null,
        userLongitude: null,
        hasAlreadyVoted: false,
      );

      expect(eligibility.isEligible, isFalse);
      expect(
        eligibility.reason,
        contains('Location access is required to confirm proximity'),
      );
    });
  });

  group('DataRepository Verification Workflow Tests', () {
    late DataRepository repository;
    late MockCommunityVerificationGateway mockGateway;

    final completedReport = ReportModel(
      reportId: 'AT-TEST-002',
      reporterUid: 'reporter-111',
      reporterName: 'Ruwan',
      faultType: FaultType.damagedPipe,
      description: 'Leak in pipe',
      severity: FaultSeverity.medium,
      status: FaultStatus.completed,
      latitude: 6.8912,
      longitude: 79.8554,
      address: 'Colombo 03',
      verificationCount: 2, // 2 existing votes
      disputeCount: 0,
      createdAt: DateTime(2026, 9, 24, 10, 0),
    );

    final voter1 = UserModel(
      uid: 'citizen-voter-1',
      email: 'voter1@test.lk',
      displayName: 'Voter One',
      phoneNumber: '+94 77 123 4567',
      role: UserRole.citizen,
      assignedArea: 'Colombo 03',
      createdAt: DateTime(2026, 9, 24, 10, 0),
    );

    setUp(() {
      mockGateway = MockCommunityVerificationGateway();
      repository = DataRepository(
        initialReports: [completedReport],
        communityVerificationGateway: mockGateway,
      );
    });

    test('submitting 3rd verification triggers community verified threshold milestone', () async {
      expect(completedReport.verificationCount, 2);

      await repository.submitCommunityVerification(
        report: completedReport,
        voter: voter1,
        note: 'Water pipe is fully fixed and road is dry.',
        userLatitude: 6.8912,
        userLongitude: 79.8554,
      );

      final updatedReport = repository.getReportById('AT-TEST-002')!;
      expect(updatedReport.verificationCount, 3);
      expect(mockGateway.recordedVotes, hasLength(1));
      expect(mockGateway.recordedVotes.first.voterUid, 'citizen-voter-1');

      // Check hasUserVotedOnReport
      expect(
        repository.hasUserVotedOnReport(
          reportId: 'AT-TEST-002',
          userUid: 'citizen-voter-1',
        ),
        isTrue,
      );

      // Check milestone event in timeline
      final timeline = repository.getTimelineForReport('AT-TEST-002');
      expect(
        timeline.any((event) => event.title == 'Community Verified'),
        isTrue,
      );
    });

    test('duplicate verification by same citizen is rejected', () async {
      await repository.submitCommunityVerification(
        report: completedReport,
        voter: voter1,
        userLatitude: 6.8912,
        userLongitude: 79.8554,
      );

      expect(
        () => repository.submitCommunityVerification(
          report: completedReport,
          voter: voter1,
          userLatitude: 6.8912,
          userLongitude: 79.8554,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('submitting dispute reopens report to disputed status and creates notification', () async {
      await repository.submitCommunityDispute(
        report: completedReport,
        voter: voter1,
        reason: 'Water leak persists along pavement curb.',
        userLatitude: 6.8912,
        userLongitude: 79.8554,
      );

      final updatedReport = repository.getReportById('AT-TEST-002')!;
      // Status must transition to disputed
      expect(updatedReport.status, FaultStatus.disputed);
      expect(updatedReport.disputeCount, 1);
      expect(mockGateway.recordedDisputes, hasLength(1));
      expect(
        mockGateway.recordedDisputes.first.reason,
        'Water leak persists along pavement curb.',
      );

      // Dispute notification generated for the recipients (here: the admin).
      final adminInbox = await inboxOf(repository, 'demo-admin-003');
      expect(adminInbox, isNotEmpty);
      expect(adminInbox.any((n) => n.type == 'dispute'), isTrue);

      // Timeline has dispute event
      final timeline = repository.getTimelineForReport('AT-TEST-002');
      expect(timeline.any((e) => e.title == 'Dispute Raised'), isTrue);
    });

    test('submitting dispute dispatches notifications across admin, technician, reporter, and voter', () async {
      final reportWithTech = completedReport.copyWith(
        assignedTechnicianUid: 'tech-kasun-999',
        assignedTechnicianName: 'Kasun Technician',
      );
      final testRepo = DataRepository(
        initialReports: [reportWithTech],
        communityVerificationGateway: mockGateway,
      );

      await testRepo.submitCommunityDispute(
        report: reportWithTech,
        voter: voter1,
        reason: 'Water is still leaking after repair.',
        userLatitude: 6.8912,
        userLongitude: 79.8554,
      );

      // Each recipient finds the dispute in their own inbox, referencing the
      // right report, and nobody else's.
      for (final uid in [
        'demo-admin-003', // 1. Admin notified
        'tech-kasun-999', // 2. Assigned technician notified
        'reporter-111', // 3. Original reporter notified
        voter1.uid, // 4. Voter received submission confirmation
      ]) {
        final inbox = await inboxOf(testRepo, uid);
        final dispute = inbox
            .where(
              (n) =>
                  n.type == 'dispute' && n.reportId == reportWithTech.reportId,
            )
            .toList();
        expect(dispute, hasLength(1), reason: uid);
        expect(dispute.single.recipientUid, uid);
        expect(dispute.single.reportId, reportWithTech.reportId);
      }
    });

    test('reaching verification threshold dispatches milestone notifications to reporter, technician, and admin', () async {
      final reportWithTech = completedReport.copyWith(
        assignedTechnicianUid: 'tech-kasun-999',
        verificationCount: 2,
      );
      final testRepo = DataRepository(
        initialReports: [reportWithTech],
        communityVerificationGateway: mockGateway,
      );

      await testRepo.submitCommunityVerification(
        report: reportWithTech,
        voter: voter1,
        note: 'Pavement is clean and dry.',
        userLatitude: 6.8912,
        userLongitude: 79.8554,
      );

      for (final uid in ['reporter-111', 'tech-kasun-999', 'demo-admin-003']) {
        final inbox = await inboxOf(testRepo, uid);
        final milestone = inbox
            .where(
              (n) =>
                  n.type == 'verification' &&
                  n.reportId == reportWithTech.reportId,
            )
            .toList();
        expect(milestone, hasLength(1), reason: uid);
        expect(milestone.single.reportId, reportWithTech.reportId);
      }
      // The voter is not notified about the milestone.
      final voterInbox = await inboxOf(testRepo, voter1.uid);
      expect(voterInbox.where((n) => n.type == 'verification'), isEmpty);
    });

    test(
      'admin can reassign a disputed report moving it into assigned status',
      () async {
        final disputedReport = completedReport.copyWith(
          status: FaultStatus.disputed,
        );
        final testRepo = DataRepository(
          initialReports: [disputedReport],
          communityVerificationGateway: mockGateway,
        );

        await testRepo.assignTechnician(
          reportId: disputedReport.reportId,
          technicianUid: 'tech-new-007',
          technicianName: 'Nimal Fernando',
          adminName: 'Dilani Admin',
          actorRole: 'admin',
        );

        final updated = testRepo.getReportById(disputedReport.reportId)!;
        expect(updated.status, FaultStatus.assigned);
        expect(updated.assignedTechnicianUid, 'tech-new-007');
        expect(updated.assignedTechnicianName, 'Nimal Fernando');
      },
    );

    test('verification radius and threshold can be configured and reset', () {
      addTearDown(CommunityVerificationService.resetDefaults);

      CommunityVerificationService.configure(radiusKm: 2.0, threshold: 5);
      expect(CommunityVerificationService.defaultRadiusKm, 2.0);
      expect(CommunityVerificationService.confirmationThreshold, 5);

      // Check distance 3.5 km is rejected under 2.0 km radius
      final eligibility = CommunityVerificationService.checkEligibility(
        report: completedReport,
        user: voter1,
        userLatitude: 6.8912,
        userLongitude: 79.8854, // ~3.3 km away
        hasAlreadyVoted: false,
      );
      expect(eligibility.isEligible, isFalse);
      expect(eligibility.isWithinRadius, isFalse);

      CommunityVerificationService.resetDefaults();
      expect(CommunityVerificationService.defaultRadiusKm, 5.0);
      expect(CommunityVerificationService.confirmationThreshold, 3);
    });

    test('submitCommunityDispute rejects empty or whitespace reason', () async {
      expect(
        () => repository.submitCommunityDispute(
          report: completedReport,
          voter: voter1,
          reason: '   ',
          userLatitude: 6.8912,
          userLongitude: 79.8554,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test(
      'submitCommunityDispute rejects oversized evidence image (>10MB)',
      () async {
        final oversizedBytes = Uint8List(11 * 1024 * 1024);
        expect(
          () => repository.submitCommunityDispute(
            report: completedReport,
            voter: voter1,
            reason: 'Water is gushing out under pressure.',
            evidenceBytes: oversizedBytes,
            userLatitude: 6.8912,
            userLongitude: 79.8554,
          ),
          throwsA(isA<ValidationException>()),
        );
      },
    );

    test('submitting verification or dispute on non-existent report throws DatabaseException', () async {
      final nonExistentReport = completedReport.copyWith(
        reportId: 'AT-NON-EXISTENT',
      );
      expect(
        () => repository.submitCommunityVerification(
          report: nonExistentReport,
          voter: voter1,
          userLatitude: 6.8912,
          userLongitude: 79.8554,
        ),
        throwsA(isA<DatabaseException>()),
      );

      expect(
        () => repository.submitCommunityDispute(
          report: nonExistentReport,
          voter: voter1,
          reason: 'Pipe leaking again.',
          userLatitude: 6.8912,
          userLongitude: 79.8554,
        ),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('handles gateway and network errors safely without mutating report state or leaking locks', () async {
      mockGateway.throwError = true;

      // Verification failure
      await expectLater(
        repository.submitCommunityVerification(
          report: completedReport,
          voter: voter1,
          userLatitude: 6.8912,
          userLongitude: 79.8554,
        ),
        throwsA(isA<NetworkException>()),
      );

      // Verify count did not increment and voter was not recorded as having voted
      expect(
        repository.getReportById(completedReport.reportId)!.verificationCount,
        2,
      );
      expect(
        repository.hasUserVotedOnReport(
          reportId: completedReport.reportId,
          userUid: voter1.uid,
        ),
        isFalse,
      );

      // Dispute failure
      await expectLater(
        repository.submitCommunityDispute(
          report: completedReport,
          voter: voter1,
          reason: 'Water leak persists.',
          userLatitude: 6.8912,
          userLongitude: 79.8554,
        ),
        throwsA(isA<NetworkException>()),
      );

      // Verify report status did not change to disputed
      expect(
        repository.getReportById(completedReport.reportId)!.status,
        FaultStatus.completed,
      );

      // Reset error and verify lock was released so voter can successfully submit now
      mockGateway.throwError = false;
      await repository.submitCommunityVerification(
        report: completedReport,
        voter: voter1,
        userLatitude: 6.8912,
        userLongitude: 79.8554,
      );
      expect(
        repository.getReportById(completedReport.reportId)!.verificationCount,
        3,
      );
    });

    test(
      'concurrent in-flight submissions are blocked by concurrency lock',
      () async {
        final completer = Completer<void>();
        mockGateway.pendingCompleter = completer;

        // Start first async verification
        final future1 = repository.submitCommunityVerification(
          report: completedReport,
          voter: voter1,
          userLatitude: 6.8912,
          userLongitude: 79.8554,
        );

        // Second immediate submission while first is still pending must throw
        expect(
          () => repository.submitCommunityVerification(
            report: completedReport,
            voter: voter1,
            userLatitude: 6.8912,
            userLongitude: 79.8554,
          ),
          throwsA(isA<ValidationException>()),
        );

        // Complete first submission
        completer.complete();
        await future1;
        expect(
          repository.getReportById(completedReport.reportId)!.verificationCount,
          3,
        );
      },
    );

    test('full end-to-end lifecycle: completed repair -> community confirmations -> threshold milestone -> citizen dispute reopening -> admin review and reassignment', () async {
      final initialReport = ReportModel(
        reportId: 'AT-LIFECYCLE-100',
        reporterUid: 'citizen-reporter-99',
        reporterName: 'Reporter Citizen',
        faultType: FaultType.pipeLeak,
        description: 'Underground main burst',
        severity: FaultSeverity.high,
        status: FaultStatus.completed,
        latitude: 6.8912,
        longitude: 79.8554,
        address: 'Bambalapitiya Junction',
        assignedTechnicianUid: 'tech-kasun-10',
        assignedTechnicianName: 'Kasun Jayawardena',
        verificationCount: 0,
        disputeCount: 0,
        createdAt: DateTime(2026, 9, 24, 8, 0),
      );

      final lifecycleGateway = MockCommunityVerificationGateway();
      final lifecycleRepo = DataRepository(
        initialReports: [initialReport],
        communityVerificationGateway: lifecycleGateway,
      );

      // 1. Citizen A confirms
      final citizenA = UserModel(
        uid: 'citizen-a',
        email: 'a@test.lk',
        displayName: 'Citizen A',
        phoneNumber: '+94 77 111 2222',
        role: UserRole.citizen,
        assignedArea: 'Colombo 04',
        createdAt: DateTime(2026, 9, 24, 8, 0),
      );
      await lifecycleRepo.submitCommunityVerification(
        report: initialReport,
        voter: citizenA,
        note: 'Pavement is dry now.',
        userLatitude: 6.8915,
        userLongitude: 79.8555,
      );
      expect(
        lifecycleRepo.getReportById('AT-LIFECYCLE-100')!.verificationCount,
        1,
      );

      // 2. Citizen B confirms
      final citizenB = UserModel(
        uid: 'citizen-b',
        email: 'b@test.lk',
        displayName: 'Citizen B',
        phoneNumber: '+94 77 333 4444',
        role: UserRole.citizen,
        assignedArea: 'Colombo 04',
        createdAt: DateTime(2026, 9, 24, 8, 0),
      );
      await lifecycleRepo.submitCommunityVerification(
        report: initialReport,
        voter: citizenB,
        userLatitude: 6.8920,
        userLongitude: 79.8550,
      );
      expect(
        lifecycleRepo.getReportById('AT-LIFECYCLE-100')!.verificationCount,
        2,
      );

      // 3. Citizen C confirms -> Reaches threshold of 3!
      final citizenC = UserModel(
        uid: 'citizen-c',
        email: 'c@test.lk',
        displayName: 'Citizen C',
        phoneNumber: '+94 77 555 6666',
        role: UserRole.citizen,
        assignedArea: 'Colombo 04',
        createdAt: DateTime(2026, 9, 24, 8, 0),
      );
      await lifecycleRepo.submitCommunityVerification(
        report: initialReport,
        voter: citizenC,
        userLatitude: 6.8910,
        userLongitude: 79.8558,
      );
      final verifiedReport = lifecycleRepo.getReportById('AT-LIFECYCLE-100')!;
      expect(verifiedReport.verificationCount, 3);
      final timelineAfterVerify = lifecycleRepo.getTimelineForReport(
        'AT-LIFECYCLE-100',
      );
      expect(
        timelineAfterVerify.any((e) => e.title == 'Community Verified'),
        isTrue,
      );

      // 4. Resident D disputes the repair
      final citizenD = UserModel(
        uid: 'citizen-d',
        email: 'd@test.lk',
        displayName: 'Citizen D',
        phoneNumber: '+94 77 777 8888',
        role: UserRole.citizen,
        assignedArea: 'Colombo 04',
        createdAt: DateTime(2026, 9, 24, 8, 0),
      );
      await lifecycleRepo.submitCommunityDispute(
        report: verifiedReport,
        voter: citizenD,
        reason: 'Water pressure drops rapidly and leak re-emerged on curb.',
        userLatitude: 6.8912,
        userLongitude: 79.8554,
      );

      final disputedReport = lifecycleRepo.getReportById('AT-LIFECYCLE-100')!;
      expect(disputedReport.status, FaultStatus.disputed);
      expect(disputedReport.disputeCount, 1);
      final timelineAfterDispute = lifecycleRepo.getTimelineForReport(
        'AT-LIFECYCLE-100',
      );
      expect(
        timelineAfterDispute.any((e) => e.title == 'Dispute Raised'),
        isTrue,
      );

      // 5. Admin reviews and reassigns report to a senior technician
      await lifecycleRepo.assignTechnician(
        reportId: 'AT-LIFECYCLE-100',
        technicianUid: 'tech-senior-99',
        technicianName: 'Saman Senior Technician',
        adminName: 'Dilani Admin',
        actorRole: 'admin',
      );

      final reassignedReport = lifecycleRepo.getReportById('AT-LIFECYCLE-100')!;
      expect(reassignedReport.status, FaultStatus.assigned);
      expect(reassignedReport.assignedTechnicianUid, 'tech-senior-99');
      expect(
        reassignedReport.assignedTechnicianName,
        'Saman Senior Technician',
      );
    });
  });

  group('CitizenVerificationScreen Widget Tests', () {
    testWidgets('renders report details and audit progress', (tester) async {
      final sampleReport = ReportModel(
        reportId: 'AT-2026-00126',
        reporterUid: 'reporter-abc',
        reporterName: 'Ruwan',
        faultType: FaultType.roadWaterFlow,
        description: 'Water overflow on road',
        severity: FaultSeverity.medium,
        status: FaultStatus.completed,
        latitude: 6.8912,
        longitude: 79.8554,
        address: 'Highlevel Road, Kottawa',
        assignedTechnicianName: 'Kasun Jayawardena',
        verificationCount: 2,
        disputeCount: 0,
        createdAt: DateTime(2026, 9, 24, 10, 0),
      );

      final mockGateway = MockCommunityVerificationGateway();
      final repository = DataRepository(
        initialReports: [sampleReport],
        communityVerificationGateway: mockGateway,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: repository),
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => MockAuthProvider(
                UserModel(
                  uid: 'citizen-auditor',
                  email: 'auditor@test.lk',
                  displayName: 'Amal Citizen',
                  phoneNumber: '+94 77 123 4567',
                  role: UserRole.citizen,
                  assignedArea: 'Colombo 03',
                  createdAt: DateTime(2026, 9, 24, 10, 0),
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: CitizenVerificationScreen(
              reportId: 'AT-2026-00126',
              initialLatitude: 6.8912,
              initialLongitude: 79.8554,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('AT-2026-00126'), findsWidgets);
      expect(find.text('Road Water Flow'), findsOneWidget);
      expect(find.text('Highlevel Road, Kottawa'), findsOneWidget);
      expect(find.text('Community Verification Audit'), findsOneWidget);
      expect(find.text('2 / 3 Confirmed'), findsOneWidget);
      expect(find.text('Repair Evidence'), findsOneWidget);
    });

    testWidgets(
      'renders Community Verified celebration badge when threshold is reached',
      (tester) async {
        final verifiedReport = ReportModel(
          reportId: 'AT-2026-00127',
          reporterUid: 'reporter-xyz',
          reporterName: 'Sunil',
          faultType: FaultType.pipeLeak,
          description: 'Fixed underground main',
          severity: FaultSeverity.high,
          status: FaultStatus.completed,
          latitude: 6.8912,
          longitude: 79.8554,
          address: 'Galle Road, Colombo 03',
          verificationCount: 3, // Meets threshold
          disputeCount: 0,
          createdAt: DateTime(2026, 9, 24, 10, 0),
        );

        final mockGateway = MockCommunityVerificationGateway();
        final repository = DataRepository(
          initialReports: [verifiedReport],
          communityVerificationGateway: mockGateway,
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: repository),
              ChangeNotifierProvider<AuthProvider>(
                create: (_) => MockAuthProvider(
                  UserModel(
                    uid: 'citizen-auditor',
                    email: 'auditor@test.lk',
                    displayName: 'Amal Citizen',
                    phoneNumber: '+94 77 123 4567',
                    role: UserRole.citizen,
                    assignedArea: 'Colombo 03',
                    createdAt: DateTime(2026, 9, 24, 10, 0),
                  ),
                ),
              ),
            ],
            child: const MaterialApp(
              home: CitizenVerificationScreen(
                reportId: 'AT-2026-00127',
                initialLatitude: 6.8912,
                initialLongitude: 79.8554,
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.textContaining('Community Verified ✓'), findsOneWidget);
        expect(find.text('3 / 3 Confirmed'), findsOneWidget);
      },
    );

    testWidgets(
      'renders Confirm Resolution and Raise Dispute buttons for completed repairs',
      (tester) async {
        final sampleReport = ReportModel(
          reportId: 'AT-2026-00128',
          reporterUid: 'reporter-xyz',
          reporterName: 'Sunil',
          faultType: FaultType.pipeLeak,
          description: 'Fixed underground main',
          severity: FaultSeverity.high,
          status: FaultStatus.completed,
          latitude: 6.8912,
          longitude: 79.8554,
          address: 'Galle Road, Colombo 03',
          verificationCount: 1,
          disputeCount: 0,
          createdAt: DateTime(2026, 9, 24, 10, 0),
        );

        final mockGateway = MockCommunityVerificationGateway();
        final repository = DataRepository(
          initialReports: [sampleReport],
          communityVerificationGateway: mockGateway,
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: repository),
              ChangeNotifierProvider<AuthProvider>(
                create: (_) => MockAuthProvider(
                  UserModel(
                    uid: 'citizen-auditor',
                    email: 'auditor@test.lk',
                    displayName: 'Amal Citizen',
                    phoneNumber: '+94 77 123 4567',
                    role: UserRole.citizen,
                    assignedArea: 'Colombo 03',
                    createdAt: DateTime(2026, 9, 24, 10, 0),
                  ),
                ),
              ),
            ],
            child: const MaterialApp(
              home: CitizenVerificationScreen(
                reportId: 'AT-2026-00128',
                initialLatitude: 6.8912,
                initialLongitude: 79.8554,
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Confirm Repair Resolution'), findsOneWidget);
        expect(find.textContaining('Raise Dispute'), findsOneWidget);
      },
    );
  });
}
