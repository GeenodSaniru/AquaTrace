import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../constants/fault_constants.dart';
import '../errors/app_exception.dart';
import '../models/activity_timeline_event.dart';
import '../models/dispute_record_model.dart';
import '../models/report_model.dart';
import '../models/verification_vote_model.dart';
import 'firebase_service.dart';

abstract interface class CommunityVerificationGateway {
  Future<void> submitVerification({
    required ReportModel report,
    required VerificationVoteModel vote,
    required ActivityTimelineEvent activity,
    required int newVerificationCount,
  });

  Future<void> submitDispute({
    required ReportModel report,
    required DisputeRecordModel dispute,
    required ActivityTimelineEvent activity,
    required int newDisputeCount,
  });

  Future<String> uploadDisputePhoto({
    required String reportId,
    required String voterUid,
    required Uint8List bytes,
    required String contentType,
  });
}

class FirebaseCommunityVerificationGateway
    implements CommunityVerificationGateway {
  @override
  Future<void> submitVerification({
    required ReportModel report,
    required VerificationVoteModel vote,
    required ActivityTimelineEvent activity,
    required int newVerificationCount,
  }) async {
    _requireCitizen(vote.voterUid);

    final reportRef = FirebaseFirestore.instance
        .collection('reports')
        .doc(report.reportId);
    final voteRef = reportRef.collection('verifications').doc(vote.voterUid);
    final activityRef = reportRef.collection('activity').doc(activity.id);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(reportRef);
      if (!snapshot.exists) {
        throw const DatabaseException('The report no longer exists.');
      }
      final currentStatus = snapshot.data()?['status'] as String?;
      if (currentStatus != FaultStatus.completed.name) {
        throw const ValidationException(
          'Only completed repairs can be verified by the community.',
        );
      }

      final existingVote = await transaction.get(voteRef);
      if (existingVote.exists) {
        throw const ValidationException(
          'You have already submitted a verification vote for this repair.',
        );
      }

      transaction.set(voteRef, {
        ...vote.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.update(reportRef, {
        'verificationCount': newVerificationCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(activityRef, {
        ...activity.toMap(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> submitDispute({
    required ReportModel report,
    required DisputeRecordModel dispute,
    required ActivityTimelineEvent activity,
    required int newDisputeCount,
  }) async {
    _requireCitizen(dispute.voterUid);

    final reportRef = FirebaseFirestore.instance
        .collection('reports')
        .doc(report.reportId);
    final disputeRef = reportRef.collection('disputes').doc(dispute.voterUid);
    final activityRef = reportRef.collection('activity').doc(activity.id);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(reportRef);
      if (!snapshot.exists) {
        throw const DatabaseException('The report no longer exists.');
      }
      final currentStatus = snapshot.data()?['status'] as String?;
      if (currentStatus != FaultStatus.completed.name &&
          currentStatus != FaultStatus.disputed.name) {
        throw const ValidationException(
          'Only completed repairs can be disputed.',
        );
      }

      final existingDispute = await transaction.get(disputeRef);
      if (existingDispute.exists) {
        throw const ValidationException(
          'You have already raised a dispute for this repair.',
        );
      }

      transaction.set(disputeRef, {
        ...dispute.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Community dispute automatically transitions status to disputed
      transaction.update(reportRef, {
        'status': FaultStatus.disputed.name,
        'disputeCount': newDisputeCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(activityRef, {
        ...activity.toMap(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<String> uploadDisputePhoto({
    required String reportId,
    required String voterUid,
    required Uint8List bytes,
    required String contentType,
  }) async {
    _requireCitizen(voterUid);
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw const ValidationException(
        'Choose a dispute photo smaller than 10 MB.',
      );
    }

    final extension = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/heic' => 'heic',
      _ => 'jpg',
    };

    final ref = FirebaseStorage.instance.ref().child(
      'disputeEvidence/$voterUid/$reportId/evidence.$extension',
    );
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: {'reportId': reportId, 'voterUid': voterUid},
      ),
    );
    return ref.getDownloadURL();
  }

  void _requireCitizen(String voterUid) {
    if (!FirebaseService.isRealFirebase) return;
    final current = FirebaseAuth.instance.currentUser;
    if (current == null || current.uid != voterUid) {
      throw const AuthException(
        'You must be signed in as a citizen to verify repairs.',
      );
    }
  }
}
