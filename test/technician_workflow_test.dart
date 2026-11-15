import 'package:flutter_test/flutter_test.dart';

import 'package:aquatrace/core/constants/fault_constants.dart';
import 'package:aquatrace/core/errors/app_exception.dart';
import 'package:aquatrace/core/models/mock_data.dart';
import 'package:aquatrace/core/services/data_repository.dart';

void main() {
  test('technician queue contains only jobs assigned to that technician', () {
    final repository = DataRepository();

    final jobs = repository.getReportsForTechnician(
      MockData.technicianUser.uid,
    );

    expect(jobs, isNotEmpty);
    expect(
      jobs.every(
        (report) => report.assignedTechnicianUid == MockData.technicianUser.uid,
      ),
      isTrue,
    );
    expect(
      jobs.any((report) => report.assignedTechnicianUid == 'tech-nimal-007'),
      isFalse,
    );
  });

  test('technician can start only their assigned job', () async {
    final repository = DataRepository();

    await repository.updateTechnicianJobStatus(
      reportId: 'AT-2026-00128',
      technicianUid: MockData.technicianUser.uid,
      actorName: MockData.technicianUser.displayName,
      newStatus: FaultStatus.ongoing,
    );

    expect(
      repository.getReportById('AT-2026-00128')?.status,
      FaultStatus.ongoing,
    );
  });

  test('technician cannot mutate another technician job', () {
    final repository = DataRepository();

    expect(
      () => repository.updateTechnicianJobStatus(
        reportId: 'AT-2026-00128',
        technicianUid: 'different-technician',
        actorName: 'Other Technician',
        newStatus: FaultStatus.ongoing,
      ),
      throwsA(isA<PermissionException>()),
    );
  });

  test('completion requires after-repair evidence', () async {
    final repository = DataRepository();

    await repository.updateTechnicianJobStatus(
      reportId: 'AT-2026-00128',
      technicianUid: MockData.technicianUser.uid,
      actorName: MockData.technicianUser.displayName,
      newStatus: FaultStatus.ongoing,
    );

    expect(
      () => repository.updateTechnicianJobStatus(
        reportId: 'AT-2026-00128',
        technicianUid: MockData.technicianUser.uid,
        actorName: MockData.technicianUser.displayName,
        newStatus: FaultStatus.completed,
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('technician cannot skip the ongoing status', () {
    final repository = DataRepository();

    expect(
      () => repository.updateTechnicianJobStatus(
        reportId: 'AT-2026-00128',
        technicianUid: MockData.technicianUser.uid,
        actorName: MockData.technicianUser.displayName,
        newStatus: FaultStatus.completed,
      ),
      throwsA(isA<ValidationException>()),
    );
  });
}
