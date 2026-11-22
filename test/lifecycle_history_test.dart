import 'dart:typed_data';

import 'package:aquatrace/core/constants/app_roles.dart';
import 'package:aquatrace/core/constants/fault_constants.dart';
import 'package:aquatrace/core/models/activity_timeline_event.dart';
import 'package:aquatrace/core/models/dispute_record_model.dart';
import 'package:aquatrace/core/models/mock_data.dart';
import 'package:aquatrace/core/models/notification_item.dart';
import 'package:aquatrace/core/models/report_model.dart';
import 'package:aquatrace/core/models/user_model.dart';
import 'package:aquatrace/core/models/verification_vote_model.dart';
import 'package:aquatrace/core/services/community_verification_gateway.dart';
import 'package:aquatrace/core/services/data_repository.dart';
import 'package:aquatrace/core/services/report_submission_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/notification_fakes.dart';

class _Submission implements ReportSubmissionGateway {
  @override
  Future<String> uploadEvidence({
    required ReportModel report,
    required Uint8List bytes,
    required String contentType,
  }) async => 'https://example.invalid/before.jpg';

  @override
  Future<void> createReport(ReportModel report) async {}
}

class _Verification implements CommunityVerificationGateway {
  @override
  Future<void> submitVerification({
    required ReportModel report,
    required VerificationVoteModel vote,
    required ActivityTimelineEvent activity,
    required int newVerificationCount,
  }) async {}

  @override
  Future<void> submitDispute({
    required ReportModel report,
    required DisputeRecordModel dispute,
    required ActivityTimelineEvent activity,
    required int newDisputeCount,
  }) async {}

  @override
  Future<String> uploadDisputePhoto({
    required String reportId,
    required String voterUid,
    required Uint8List bytes,
    required String contentType,
  }) async => 'https://example.invalid/evidence.jpg';
}

UserModel citizen(String uid, {String area = 'Colombo 03'}) => UserModel(
  uid: uid,
  email: '$uid@test.lk',
  displayName: 'Citizen $uid',
  phoneNumber: '+94 77 000 0000',
  role: UserRole.citizen,
  assignedArea: area,
  createdAt: DateTime(2026, 9, 1),
);

const _reporterUid = 'reporter-lc';
const _technicianUid = 'tech-lc';

ReportModel newReport() => ReportModel(
  reportId: 'AT-LC-1',
  reporterUid: _reporterUid,
  reporterName: 'Reporter LC',
  faultType: FaultType.pipeLeak,
  description: 'Water leaking from the main pipe at the junction.',
  severity: FaultSeverity.high,
  status: FaultStatus.pending,
  latitude: 6.8912,
  longitude: 79.8554,
  address: 'Galle Road, Colombo 03',
  assignedArea: 'Colombo 03',
  // Pre-set so the demo repository allows completion (real uploads need Storage).
  afterImageUrl: 'https://example.invalid/after.jpg',
  createdAt: DateTime(2026, 9, 24, 9),
);

Future<List<NotificationItem>> inbox(DataRepository repo, String uid) async {
  repo.bindNotificationUser(uid);
  await settle();
  return repo.notifications
      .where((n) => n.reportId == 'AT-LC-1')
      .toList(growable: false);
}

void main() {
  group('Complete report lifecycle (demo backend)', () {
    late DataRepository repo;

    setUp(() async {
      repo = DataRepository(
        initialReports: const [],
        reportSubmissionGateway: _Submission(),
        communityVerificationGateway: _Verification(),
      );

      // 1. Citizen submits.
      await repo.addReport(
        newReport(),
        evidenceBytes: Uint8List.fromList([1, 2, 3]),
        contentType: 'image/jpeg',
      );
      // 2-3. Admin verifies and assigns.
      await repo.assignTechnician(
        reportId: 'AT-LC-1',
        technicianUid: _technicianUid,
        technicianName: 'Tech LC',
        adminName: 'Admin LC',
        actorRole: 'admin',
      );
      // 4-5. Technician starts and completes the repair.
      await repo.updateTechnicianJobStatus(
        reportId: 'AT-LC-1',
        technicianUid: _technicianUid,
        actorName: 'Tech LC',
        newStatus: FaultStatus.ongoing,
      );
      await repo.updateTechnicianJobStatus(
        reportId: 'AT-LC-1',
        technicianUid: _technicianUid,
        actorName: 'Tech LC',
        newStatus: FaultStatus.completed,
      );
      // 6. Three neighbours confirm.
      for (final voter in ['voter-1', 'voter-2', 'voter-3']) {
        await repo.submitCommunityVerification(
          report: repo.getReportById('AT-LC-1')!,
          voter: citizen(voter),
          userLatitude: 6.8912,
          userLongitude: 79.8554,
        );
      }
      // 7. A resident disputes the repair.
      await repo.submitCommunityDispute(
        report: repo.getReportById('AT-LC-1')!,
        voter: citizen('disputer'),
        reason: 'The leak is back after two days.',
        userLatitude: 6.8912,
        userLongitude: 79.8554,
      );
    });

    test(
      'history lists every lifecycle step once, in the right order',
      () async {
        final events = await repo.watchReportHistory('AT-LC-1').first;
        expect(events.map((e) => e.title).toList(), [
          'Report Submitted',
          'Report Verified',
          'Technician Assigned',
          'Repair Started',
          'Repair Completed',
          'Community Verification Confirmed',
          'Community Verification Confirmed',
          'Community Verification Confirmed',
          'Community Verified',
          'Dispute Raised',
        ]);
      },
    );

    test(
      'history is chronological, ids are unique and each step has an actor',
      () async {
        final events = await repo.watchReportHistory('AT-LC-1').first;
        for (var i = 1; i < events.length; i++) {
          expect(
            events[i].timestamp.isBefore(events[i - 1].timestamp),
            isFalse,
            reason: '${events[i - 1].title} -> ${events[i].title}',
          );
        }
        expect(events.map((e) => e.id).toSet(), hasLength(events.length));
        expect(events.every((e) => e.actorName.trim().isNotEmpty), isTrue);
        expect(events.every((e) => e.hasKnownTime), isTrue);
        // Statuses follow the workflow.
        expect(events.first.status, FaultStatus.pending);
        expect(events.last.status, FaultStatus.disputed);
      },
    );

    test('actors and roles match who performed each step', () async {
      final byTitle = {
        for (final e in await repo.watchReportHistory('AT-LC-1').first)
          e.title: e,
      };
      expect(byTitle['Report Submitted']!.actorRole, 'Citizen');
      expect(byTitle['Report Verified']!.actorRole, 'Admin');
      expect(byTitle['Technician Assigned']!.actorRole, 'Admin');
      expect(byTitle['Repair Started']!.actorRole, 'Technician');
      expect(byTitle['Repair Completed']!.actorRole, 'Technician');
      expect(byTitle['Community Verified']!.actorRole, 'Citizen Verification');
      expect(byTitle['Dispute Raised']!.actorRole, 'Citizen Dispute');
    });

    test('the reporter is told about each step, oldest event last, never asked to verify', () async {
      final mine = await inbox(repo, _reporterUid);
      final titles = mine.map((n) => n.title).toList();
      // Newest first.
      expect(titles, [
        'Dispute Opened',
        'Repair Verified',
        'Repair Completed',
        'Repair Started',
        'Technician Assigned',
        'Report Approved',
      ]);
      expect(mine.every((n) => n.recipientUid == _reporterUid), isTrue);
      expect(mine.any((n) => n.title == 'Verify Repair'), isFalse);
    });

    test(
      'the technician gets the job, the verified milestone and the dispute',
      () async {
        final titles = (await inbox(
          repo,
          _technicianUid,
        )).map((n) => n.title).toList();
        expect(titles, [
          'Repair Disputed',
          'Repair Verified by Community',
          'New Job Assigned',
        ]);
      },
    );

    test('the admin is alerted to the submission, completion, milestone and dispute', () async {
      final titles = (await inbox(
        repo,
        MockData.adminUser.uid,
      )).map((n) => n.title).toList();
      expect(titles, [
        'Dispute Raised',
        'Repair Verified by Community',
        'Repair Completed',
        'New Report Submitted',
      ]);
    });

    test(
      'a neighbour is asked to verify once the repair is completed',
      () async {
        // The demo citizen lives in the same service area and is not involved.
        final titles = (await inbox(
          repo,
          MockData.citizenUser.uid,
        )).map((n) => n.title).toList();
        expect(titles, ['Verify Repair']);
      },
    );

    test('the disputing resident gets exactly one confirmation; uninvolved users get nothing', () async {
      final voter = await inbox(repo, 'disputer');
      expect(voter.map((n) => n.title), ['Dispute Submitted']);
      expect(await inbox(repo, 'bystander'), isEmpty);
    });

    test('every notification references this report and is unread', () async {
      for (final uid in [
        _reporterUid,
        _technicianUid,
        MockData.adminUser.uid,
        'disputer',
      ]) {
        final items = await inbox(repo, uid);
        expect(items, isNotEmpty, reason: uid);
        expect(
          items.every((n) => n.reportId == 'AT-LC-1' && !n.isRead),
          isTrue,
        );
      }
    });
  });

  group('Audit ids', () {
    test('events created in one tick keep creation order across id-width boundaries', () async {
      final repo = DataRepository(
        initialReports: [newReport().copyWith(status: FaultStatus.completed)],
        communityVerificationGateway: _Verification(),
      );
      // Enough events to cross the 9 -> 10 sequence boundary in one session.
      for (var i = 0; i < 14; i++) {
        await repo.submitCommunityVerification(
          report: repo.getReportById('AT-LC-1')!,
          voter: citizen('v$i'),
          userLatitude: 6.8912,
          userLongitude: 79.8554,
        );
      }
      final created = repo.getTimelineForReport('AT-LC-1');
      final sorted = await repo.watchReportHistory('AT-LC-1').first;
      expect(
        sorted.map((e) => e.id).toList(),
        created.map((e) => e.id).toList(),
        reason: 'sorted history must equal creation order',
      );
    });
  });
}
