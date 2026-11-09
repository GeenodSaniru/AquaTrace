import 'dart:async';

import 'package:aquatrace/core/constants/fault_constants.dart';
import 'package:aquatrace/core/errors/app_exception.dart';
import 'package:aquatrace/core/models/report_model.dart';
import 'package:aquatrace/core/services/data_repository.dart';
import 'package:aquatrace/core/services/report_submission_gateway.dart';
import 'package:aquatrace/features/reports/presentation/citizen_report_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:aquatrace/features/reports/services/citizen_report_input_provider.dart';

void main() {
  group('Citizen report persistence', () {
    test('uploads evidence before saving the pending report', () async {
      final gateway = FakeReportSubmissionGateway();
      final repository = DataRepository(reportSubmissionGateway: gateway);
      final report = buildReport();

      await repository.addReport(
        report,
        evidenceBytes: Uint8List.fromList([1, 2, 3]),
        contentType: 'image/jpeg',
      );

      expect(gateway.calls, ['upload', 'create']);
      final saved = repository.getReportById(report.reportId)!;
      expect(saved.reporterUid, 'citizen-test-uid');
      expect(saved.latitude, 6.912345);
      expect(saved.longitude, 79.812345);
      expect(saved.beforeImageUrl, 'https://storage.example/evidence.jpg');
      expect(saved.status, FaultStatus.pending);
      expect(saved.createdAt, report.createdAt);
      expect(saved.updatedAt, isNull);
    });

    test(
      'does not save or expose a report when evidence upload fails',
      () async {
        final gateway = FakeReportSubmissionGateway()
          ..uploadError = const DatabaseException('upload failed');
        final repository = DataRepository(reportSubmissionGateway: gateway);
        final report = buildReport();

        await expectLater(
          repository.addReport(
            report,
            evidenceBytes: Uint8List.fromList([1]),
            contentType: 'image/jpeg',
          ),
          throwsA(isA<DatabaseException>()),
        );

        expect(gateway.calls, ['upload']);
        expect(repository.getReportById(report.reportId), isNull);
      },
    );

    test('does not expose a report when Firestore creation fails', () async {
      final gateway = FakeReportSubmissionGateway()
        ..createError = const DatabaseException('firestore failed');
      final repository = DataRepository(reportSubmissionGateway: gateway);
      final report = buildReport();

      await expectLater(
        repository.addReport(
          report,
          evidenceBytes: Uint8List.fromList([1]),
          contentType: 'image/jpeg',
        ),
        throwsA(isA<DatabaseException>()),
      );

      expect(gateway.calls, ['upload', 'create']);
      expect(repository.getReportById(report.reportId), isNull);
    });

    test(
      'rejects duplicate in-flight submissions with the same report ID',
      () async {
        final gateway = FakeReportSubmissionGateway()
          ..uploadCompleter = Completer<String>();
        final repository = DataRepository(reportSubmissionGateway: gateway);
        final report = buildReport();
        final submission = repository.addReport(
          report,
          evidenceBytes: Uint8List.fromList([1]),
          contentType: 'image/jpeg',
        );

        await Future<void>.delayed(Duration.zero);
        await expectLater(
          repository.addReport(
            report,
            evidenceBytes: Uint8List.fromList([1]),
            contentType: 'image/jpeg',
          ),
          throwsA(isA<ValidationException>()),
        );

        gateway.uploadCompleter!.complete(
          'https://storage.example/evidence.jpg',
        );
        await submission;
        expect(gateway.calls, ['upload', 'create']);
      },
    );

    test('rejects invalid photo data before any backend call', () async {
      final gateway = FakeReportSubmissionGateway();
      final repository = DataRepository(reportSubmissionGateway: gateway);

      await expectLater(
        repository.addReport(
          buildReport(),
          evidenceBytes: Uint8List(0),
          contentType: 'image/jpeg',
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(gateway.calls, isEmpty);
    });

    test('rejects invalid coordinates before uploading evidence', () async {
      final gateway = FakeReportSubmissionGateway();
      final repository = DataRepository(reportSubmissionGateway: gateway);

      await expectLater(
        repository.addReport(
          buildReport().copyWith(latitude: double.nan),
          evidenceBytes: Uint8List.fromList([1]),
          contentType: 'image/jpeg',
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(gateway.calls, isEmpty);
    });

    test('rejects resubmitting an already saved report ID', () async {
      final gateway = FakeReportSubmissionGateway();
      final repository = DataRepository(reportSubmissionGateway: gateway);
      final report = buildReport();

      await repository.addReport(
        report,
        evidenceBytes: Uint8List.fromList([1]),
        contentType: 'image/jpeg',
      );
      await expectLater(
        repository.addReport(
          report,
          evidenceBytes: Uint8List.fromList([1]),
          contentType: 'image/jpeg',
        ),
        throwsA(isA<ValidationException>()),
      );

      expect(gateway.calls, ['upload', 'create']);
    });
  });

  testWidgets('form shows required location and evidence errors', (
    tester,
  ) async {
    await pumpReportForm(tester, FakeCitizenReportInputProvider());
    await tester.scrollUntilVisible(
      find.text('Submit Report'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Submit Report'));
    await tester.pumpAndSettle();

    expect(
      find.text('Get your current GPS location to continue.'),
      findsOneWidget,
    );
    expect(find.text('Add a photo of the fault to continue.'), findsOneWidget);
    expect(find.text('Choose a fault type.'), findsOneWidget);
    expect(find.text('Choose a severity.'), findsOneWidget);
    expect(find.text('Enter at least 10 characters.'), findsOneWidget);
    expect(find.text('Enter a nearby street or landmark.'), findsOneWidget);
  });

  testWidgets('denied location permission is explained and settings offered', (
    tester,
  ) async {
    final input = FakeCitizenReportInputProvider()
      ..locationError = const PermissionException('Location permission denied.')
      ..locationPermissionPermanentlyDenied = true;
    await pumpReportForm(tester, input);

    await tapFormAction(tester, 'Get current location');

    expect(find.text('Location permission denied.'), findsOneWidget);
    expect(find.text('Open location settings'), findsOneWidget);
  });

  testWidgets('unavailable GPS gives a retryable explanation', (tester) async {
    final input = FakeCitizenReportInputProvider()
      ..locationError = const LocationServiceDisabledException();
    await pumpReportForm(tester, input);

    await tapFormAction(tester, 'Get current location');

    expect(
      find.text('Location services are turned off. Enable GPS and try again.'),
      findsOneWidget,
    );
    expect(find.text('Confirm this location'), findsNothing);
  });

  testWidgets('gallery cancellation leaves evidence required', (tester) async {
    final input = FakeCitizenReportInputProvider();
    await pumpReportForm(tester, input);

    await tapFormAction(tester, 'Choose photo');

    expect(
      find.text('No photo selected. Add a photo to continue.'),
      findsOneWidget,
    );
    expect(input.selectedSources, [ImageSource.gallery]);
  });

  testWidgets('camera permission failure offers the gallery fallback', (
    tester,
  ) async {
    final input = FakeCitizenReportInputProvider()
      ..photoError = PlatformException(code: 'camera-denied');
    await pumpReportForm(tester, input);

    await tapFormAction(tester, 'Take photo');

    expect(
      find.text(
        'Camera access failed. Check camera permission or choose a photo from your library.',
      ),
      findsOneWidget,
    );
    expect(find.text('Choose photo'), findsOneWidget);
  });
}

Future<void> pumpReportForm(
  WidgetTester tester,
  FakeCitizenReportInputProvider input,
) async {
  final repository = DataRepository(
    reportSubmissionGateway: FakeReportSubmissionGateway(),
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [ChangeNotifierProvider.value(value: repository)],
      child: MaterialApp(home: CitizenReportFormScreen(inputProvider: input)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapFormAction(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

ReportModel buildReport() {
  return ReportModel(
    reportId: 'AT-2026-test-report-001',
    reporterUid: 'citizen-test-uid',
    reporterName: 'Test Citizen',
    faultType: FaultType.pipeLeak,
    description: 'Water is leaking from a pipe near the road.',
    severity: FaultSeverity.high,
    status: FaultStatus.pending,
    latitude: 6.912345,
    longitude: 79.812345,
    address: 'Test Street, Colombo',
    createdAt: DateTime.utc(2026, 11, 9, 6),
  );
}

class FakeReportSubmissionGateway implements ReportSubmissionGateway {
  final List<String> calls = [];
  Object? uploadError;
  Object? createError;
  Completer<String>? uploadCompleter;
  ReportModel? createdReport;

  @override
  Future<String> uploadEvidence({
    required ReportModel report,
    required Uint8List bytes,
    required String contentType,
  }) async {
    calls.add('upload');
    if (uploadError case final error?) throw error;
    if (uploadCompleter case final completer?) return completer.future;
    return 'https://storage.example/evidence.jpg';
  }

  @override
  Future<void> createReport(ReportModel report) async {
    calls.add('create');
    if (createError case final error?) throw error;
    createdReport = report;
  }
}

class FakeCitizenReportInputProvider implements CitizenReportInputProvider {
  Object? locationError;
  Object? photoError;
  @override
  bool locationPermissionPermanentlyDenied = false;
  final List<ImageSource> selectedSources = [];

  @override
  Future<Position> getCurrentPosition() async {
    if (locationError case final error?) throw error;
    throw StateError('No test position configured.');
  }

  @override
  Future<XFile?> pickPhoto(ImageSource source) async {
    selectedSources.add(source);
    if (photoError case final error?) throw error;
    return null;
  }
}
