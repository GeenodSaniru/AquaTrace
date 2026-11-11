import 'package:flutter_test/flutter_test.dart';

import 'package:aquatrace/core/constants/fault_constants.dart';
import 'package:aquatrace/core/errors/app_exception.dart';
import 'package:aquatrace/core/services/data_repository.dart';

void main() {
  late DataRepository repository;

  setUp(() {
    repository = DataRepository();
  });

  test('rejects report mutations without a role', () async {
    expect(
      () => repository.updateReportStatus(
        reportId: 'AT-2026-00125',
        newStatus: FaultStatus.assigned,
        actorName: 'Unknown',
        actorRole: '',
      ),
      throwsA(isA<PermissionException>()),
    );
  });

  test('rejects invalid admin status transitions', () async {
    expect(
      () => repository.updateReportStatus(
        reportId: 'AT-2026-00125',
        newStatus: FaultStatus.ongoing,
        actorName: 'Admin',
        actorRole: 'Admin',
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('keeps correction requests pending with an audit note', () async {
    await repository.updateReportStatus(
      reportId: 'AT-2026-00125',
      newStatus: FaultStatus.pending,
      actorName: 'Admin',
      actorRole: 'Admin',
      note: 'Correction requested before approval.',
    );

    final report = repository.getReportById('AT-2026-00125');
    expect(report?.status, FaultStatus.pending);
    expect(report?.repairNotes, 'Correction requested before approval.');
  });

  test(
    'assigns a pending report with technician and assignment time',
    () async {
      await repository.assignTechnician(
        reportId: 'AT-2026-00125',
        technicianUid: 'tech-001',
        technicianName: 'Verified Technician',
        adminName: 'Admin',
      );

      final report = repository.getReportById('AT-2026-00125');
      expect(report?.status, FaultStatus.assigned);
      expect(report?.assignedTechnicianUid, 'tech-001');
      expect(report?.assignedTechnicianName, 'Verified Technician');
      expect(report?.assignedAt, isNotNull);
    },
  );
}
