import 'package:flutter_test/flutter_test.dart';

import 'package:aquatrace/core/models/report_model.dart';

void main() {
  Map<String, dynamic> reportFields({
    Object? latitude = 6.9271,
    Object? longitude = 79.8612,
  }) {
    return {
      'reportId': 'map-test',
      'reporterUid': 'citizen-test',
      'reporterName': 'Citizen',
      'faultType': 'pipeLeak',
      'description': 'A test report with coordinate data.',
      'severity': 'medium',
      'status': 'pending',
      'latitude': latitude,
      'longitude': longitude,
      'address': 'Colombo',
      'createdAt': '2026-11-13T00:00:00.000Z',
    };
  }

  test('accepts valid map coordinates', () {
    final report = ReportModel.fromMap(reportFields());

    expect(report.hasValidLocation, isTrue);
    expect(report.latitude, 6.9271);
    expect(report.longitude, 79.8612);
  });

  test('marks missing coordinates as non-mappable', () {
    final report = ReportModel.fromMap(
      reportFields(latitude: null, longitude: null),
    );

    expect(report.hasValidLocation, isFalse);
  });

  test('marks out-of-range coordinates as non-mappable', () {
    final report = ReportModel.fromMap(
      reportFields(latitude: 95, longitude: 181),
    );

    expect(report.hasValidLocation, isFalse);
  });
}
