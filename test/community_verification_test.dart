import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:aquatrace/core/constants/app_roles.dart';
import 'package:aquatrace/core/constants/fault_constants.dart';
import 'package:aquatrace/core/errors/app_exception.dart';
import 'package:aquatrace/core/models/activity_timeline_event.dart';
import 'package:aquatrace/core/models/dispute_record_model.dart';
import 'package:aquatrace/core/models/report_model.dart';
import 'package:aquatrace/core/models/user_model.dart';
import 'package:aquatrace/core/models/verification_vote_model.dart';
import 'package:aquatrace/core/services/community_verification_gateway.dart';
import 'package:aquatrace/core/services/data_repository.dart';
import 'package:aquatrace/features/auth/providers/auth_provider.dart';
import 'package:aquatrace/features/verification/presentation/citizen_verification_screen.dart';
import 'package:aquatrace/features/verification/services/community_verification_service.dart';

class MockCommunityVerificationGateway implements CommunityVerificationGateway {
  final List<VerificationVoteModel> recordedVotes = [];
  final List<DisputeRecordModel> recordedDisputes = [];
  final List<ActivityTimelineEvent> recordedActivities = [];

  @override
  Future<void> submitVerification({
    required ReportModel report,
    required VerificationVoteModel vote,
    required ActivityTimelineEvent activity,
    required int newVerificationCount,
  }) async {
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

      // Dispute notification generated
      expect(repository.notifications, isNotEmpty);
      expect(repository.notifications.any((n) => n.type == 'dispute'), isTrue);

      // Timeline has dispute event
      final timeline = repository.getTimelineForReport('AT-TEST-002');
      expect(timeline.any((e) => e.title == 'Dispute Raised'), isTrue);
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
  });
}
