import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../errors/app_exception.dart';
import '../models/report_model.dart';
import 'firebase_service.dart';

abstract interface class ReportSubmissionGateway {
  Future<String> uploadEvidence({
    required ReportModel report,
    required Uint8List bytes,
    required String contentType,
  });

  Future<void> createReport(ReportModel report);
}

class FirebaseReportSubmissionGateway implements ReportSubmissionGateway {
  @override
  Future<String> uploadEvidence({
    required ReportModel report,
    required Uint8List bytes,
    required String contentType,
  }) async {
    _requireReporter(report.reporterUid);

    final extension = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/heic' => 'heic',
      _ => 'jpg',
    };
    final reference = FirebaseStorage.instance.ref().child(
      'reportEvidence/${report.reporterUid}/${report.reportId}/before.$extension',
    );

    await reference.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'reportId': report.reportId,
          'reporterUid': report.reporterUid,
        },
      ),
    );
    return reference.getDownloadURL();
  }

  @override
  Future<void> createReport(ReportModel report) async {
    _requireReporter(report.reporterUid);
    if (report.beforeImageUrl == null || report.beforeImageUrl!.isEmpty) {
      throw const ValidationException(
        'An uploaded evidence photo is required before submitting.',
      );
    }

    final reportReference = FirebaseFirestore.instance
        .collection('reports')
        .doc(report.reportId);
    final reportData = report.toMap();
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final existing = await transaction.get(reportReference);
      if (existing.exists) {
        final existingData = existing.data();
        final isSameSubmission =
            existingData?['reporterUid'] == report.reporterUid &&
            existingData?['reportId'] == report.reportId &&
            existingData?['createdAt'] == reportData['createdAt'] &&
            existingData?['beforeImageUrl'] == report.beforeImageUrl;
        if (isSameSubmission) return;
        throw const ValidationException(
          'A different report already uses this report ID.',
        );
      }
      transaction.set(reportReference, reportData);
    });
  }

  void _requireReporter(String reporterUid) {
    if (!FirebaseService.isRealFirebase) {
      throw const PermissionException(
        'Demo accounts cannot submit reports. Sign in with a Firebase citizen account.',
      );
    }
    final authenticatedUid = FirebaseAuth.instance.currentUser?.uid;
    if (authenticatedUid == null || authenticatedUid != reporterUid) {
      throw const PermissionException(
        'Sign in with your citizen account before submitting a report.',
      );
    }
  }
}
