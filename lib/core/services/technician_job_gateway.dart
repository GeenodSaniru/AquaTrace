import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../errors/app_exception.dart';
import '../models/activity_timeline_event.dart';
import '../models/report_model.dart';
import 'firebase_service.dart';

abstract interface class TechnicianJobGateway {
  Future<void> updateRepairEvidence({required ReportModel report});

  Future<void> updateJob({
    required ReportModel report,
    required ActivityTimelineEvent activity,
  });

  Future<String> uploadAfterRepairPhoto({
    required ReportModel report,
    required Uint8List bytes,
    required String contentType,
  });
}

class FirebaseTechnicianJobGateway implements TechnicianJobGateway {
  @override
  Future<void> updateRepairEvidence({required ReportModel report}) async {
    _requireTechnician(report.assignedTechnicianUid);
    await FirebaseFirestore.instance
        .collection('reports')
        .doc(report.reportId)
        .update({
          'afterImageUrl': report.afterImageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  @override
  Future<void> updateJob({
    required ReportModel report,
    required ActivityTimelineEvent activity,
  }) async {
    _requireTechnician(report.assignedTechnicianUid);

    final reportReference = FirebaseFirestore.instance
        .collection('reports')
        .doc(report.reportId);
    final activityReference = reportReference
        .collection('activity')
        .doc(activity.id);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(reportReference);
      if (!snapshot.exists) {
        throw const DatabaseException('The assigned report no longer exists.');
      }
      transaction.update(reportReference, {
        'status': report.status.name,
        'repairNotes': report.repairNotes,
        'afterImageUrl': report.afterImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(activityReference, {
        ...activity.toMap(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<String> uploadAfterRepairPhoto({
    required ReportModel report,
    required Uint8List bytes,
    required String contentType,
  }) async {
    _requireTechnician(report.assignedTechnicianUid);
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw const ValidationException(
        'Choose an after-repair photo smaller than 10 MB.',
      );
    }

    final extension = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/heic' => 'heic',
      _ => 'jpg',
    };
    final reference = FirebaseStorage.instance.ref().child(
      'repairEvidence/${report.assignedTechnicianUid}/${report.reportId}/after.$extension',
    );
    await reference.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'reportId': report.reportId,
          'technicianUid': report.assignedTechnicianUid!,
        },
      ),
    );
    return reference.getDownloadURL();
  }

  void _requireTechnician(String? assignedTechnicianUid) {
    if (!FirebaseService.isRealFirebase) {
      throw const PermissionException(
        'Demo accounts cannot persist technician updates.',
      );
    }
    final authenticatedUid = FirebaseAuth.instance.currentUser?.uid;
    if (authenticatedUid == null ||
        assignedTechnicianUid == null ||
        authenticatedUid != assignedTechnicianUid) {
      throw const PermissionException(
        'Only the assigned technician can update this job.',
      );
    }
  }
}
