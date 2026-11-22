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
import 'package:aquatrace/features/notifications/services/notification_gateway.dart';
import 'package:aquatrace/features/notifications/services/push_messaging_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/notification_fakes.dart';

class _NoopVerificationGateway implements CommunityVerificationGateway {
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

/// Stands in for the real (Firestore) gateway: records any attempt to write.
class _SpyGateway implements NotificationGateway {
  int writeCalls = 0;

  @override
  Stream<List<NotificationItem>> watchNotifications(
    String uid, {
    int limit = NotificationGateway.defaultNotificationLimit,
  }) => Stream.value(const <NotificationItem>[]);

  @override
  Future<void> markRead(String uid, String notificationId) async =>
      writeCalls++;

  @override
  Future<void> markAllRead(
    String uid,
    Iterable<String> notificationIds,
  ) async => writeCalls++;

  @override
  Stream<List<ActivityTimelineEvent>> watchActivity(
    String reportId, {
    int limit = NotificationGateway.defaultActivityLimit,
  }) => const Stream.empty();
}

UserModel citizen(String uid) => UserModel(
  uid: uid,
  email: '$uid@test.lk',
  displayName: 'Citizen $uid',
  phoneNumber: '+94 77 000 0000',
  role: UserRole.citizen,
  assignedArea: 'Colombo 03',
  createdAt: DateTime(2026, 9, 1),
);

ReportModel completedReport({int verifications = 0}) => ReportModel(
  reportId: 'AT-EVT-1',
  reporterUid: 'reporter-1',
  reporterName: 'Reporter',
  faultType: FaultType.pipeLeak,
  description: 'Leak near the junction on the main road.',
  severity: FaultSeverity.high,
  status: FaultStatus.completed,
  latitude: 6.8912,
  longitude: 79.8554,
  address: 'Galle Road, Colombo 03',
  assignedTechnicianUid: 'tech-1',
  assignedTechnicianName: 'Tech One',
  verificationCount: verifications,
  createdAt: DateTime(2026, 9, 24, 9),
);

Future<List<NotificationItem>> inbox(DataRepository repo, String uid) async {
  repo.bindNotificationUser(uid);
  await settle();
  return repo.notifications;
}

void main() {
  group('Push payload type', () {
    test('is parsed; unknown values degrade; absent is null', () {
      expect(
        const PushMessage(data: {'type': 'dispute'}).type,
        NotificationType.dispute,
      );
      expect(
        const PushMessage(data: {'type': ' verification '}).type,
        NotificationType.verification,
      );
      expect(
        const PushMessage(data: {'type': 'something-new'}).type,
        NotificationType.update,
      );
      expect(const PushMessage(data: {}).type, isNull);
      expect(const PushMessage(data: {'type': ''}).type, isNull);
    });
  });

  group('Workflow events deliver to the right recipient (demo backend)', () {
    test(
      'a dispute reaches reporter, technician, admin and voter once each',
      () async {
        final repo = DataRepository(
          initialReports: [completedReport()],
          communityVerificationGateway: _NoopVerificationGateway(),
        );
        await repo.submitCommunityDispute(
          report: completedReport(),
          voter: citizen('voter-1'),
          reason: 'Still leaking after the repair.',
          userLatitude: 6.8912,
          userLongitude: 79.8554,
        );

        for (final uid in [
          'reporter-1',
          'tech-1',
          MockData.adminUser.uid,
          'voter-1',
        ]) {
          final forReport = (await inbox(
            repo,
            uid,
          )).where((n) => n.reportId == 'AT-EVT-1').toList();
          expect(forReport, hasLength(1), reason: uid);
          expect(forReport.single.type, 'dispute');
          expect(forReport.single.recipientUid, uid);
          expect(forReport.single.isRead, isFalse);
        }
        // Bystanders are not notified.
        final bystander = await inbox(repo, 'someone-else');
        expect(bystander.where((n) => n.reportId == 'AT-EVT-1'), isEmpty);
      },
    );

    test(
      'the community milestone is announced once, not on later votes',
      () async {
        final repo = DataRepository(
          initialReports: [completedReport(verifications: 2)],
          communityVerificationGateway: _NoopVerificationGateway(),
        );
        for (final voter in ['voter-a', 'voter-b']) {
          await repo.submitCommunityVerification(
            report: repo.getReportById('AT-EVT-1')!,
            voter: citizen(voter),
            userLatitude: 6.8912,
            userLongitude: 79.8554,
          );
        }
        // voter-a was the 3rd confirmation (milestone); voter-b the 4th.
        final reporter = (await inbox(repo, 'reporter-1'))
            .where((n) => n.reportId == 'AT-EVT-1' && n.type == 'verification')
            .toList();
        expect(reporter, hasLength(1));
        final milestones = repo
            .getTimelineForReport('AT-EVT-1')
            .where((e) => e.title == 'Community Verified');
        expect(milestones, hasLength(1));
      },
    );

    test('activity ids never collide within one tick', () async {
      final repo = DataRepository(
        initialReports: [completedReport()],
        communityVerificationGateway: _NoopVerificationGateway(),
      );
      for (var i = 0; i < 4; i++) {
        await repo.submitCommunityVerification(
          report: repo.getReportById('AT-EVT-1')!,
          voter: citizen('v$i'),
          userLatitude: 6.8912,
          userLongitude: 79.8554,
        );
      }
      final ids = repo.getTimelineForReport('AT-EVT-1').map((e) => e.id);
      expect(ids.toSet(), hasLength(ids.length));
    });

    test(
      'with a real gateway the client never creates notifications',
      () async {
        final spy = _SpyGateway();
        final repo = DataRepository(
          initialReports: [completedReport()],
          communityVerificationGateway: _NoopVerificationGateway(),
          notificationGateway: spy,
        );
        await repo.submitCommunityDispute(
          report: completedReport(),
          voter: citizen('voter-1'),
          reason: 'Still leaking after the repair.',
          userLatitude: 6.8912,
          userLongitude: 79.8554,
        );
        for (final uid in ['reporter-1', 'tech-1', 'voter-1']) {
          expect(await inbox(repo, uid), isEmpty, reason: uid);
        }
        expect(spy.writeCalls, 0);
      },
    );
  });
}
