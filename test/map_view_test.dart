import 'package:aquatrace/core/constants/fault_constants.dart';
import 'package:aquatrace/core/models/mock_data.dart';
import 'package:aquatrace/core/models/report_model.dart';
import 'package:aquatrace/core/services/data_repository.dart';
import 'package:aquatrace/features/map/presentation/shared_map_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Report map locations', () {
    test(
      'missing, malformed, and out-of-range coordinates are not mappable',
      () {
        final report = MockData.initialReports.first;
        final missing = Map<String, dynamic>.from(report.toMap())
          ..remove('latitude')
          ..remove('longitude');
        final malformed = Map<String, dynamic>.from(report.toMap())
          ..['latitude'] = 'not-a-number';
        final outOfRange = Map<String, dynamic>.from(report.toMap())
          ..['longitude'] = 181;

        expect(ReportModel.fromMap(missing).hasValidLocation, isFalse);
        expect(ReportModel.fromMap(malformed).hasValidLocation, isFalse);
        expect(ReportModel.fromMap(outOfRange).hasValidLocation, isFalse);
      },
    );

    testWidgets('renders all five statuses and filters report markers', (
      tester,
    ) async {
      final repository = DataRepository();
      await _pumpMap(tester, repository);

      expect(_mapMarkers(tester), hasLength(FaultStatus.values.length));
      final labels = _mapMarkers(tester)
          .map((marker) => (marker.child as Semantics).properties.label!)
          .toList();
      for (final status in FaultStatus.values) {
        expect(
          labels.any((label) => label.startsWith(status.displayName)),
          isTrue,
        );
      }

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Pending'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(_mapMarkers(tester), hasLength(FaultStatus.values.length - 1));
      expect(
        _mapMarkers(tester).any(
          (marker) => (marker.child as Semantics).properties.label!.startsWith(
            'Pending',
          ),
        ),
        isFalse,
      );
      repository.dispose();
    });

    testWidgets('search matches report addresses and displays empty results', (
      tester,
    ) async {
      final repository = DataRepository();
      await _pumpMap(tester, repository);

      await tester.enterText(find.byType(TextField), 'Maharagama');
      await tester.pump();
      expect(_mapMarkers(tester), hasLength(1));
      expect(
        (_mapMarkers(tester).single.child as Semantics).properties.label,
        contains('Main Street, Maharagama'),
      );

      await tester.enterText(find.byType(TextField), 'no matching address');
      await tester.pump();
      expect(_mapMarkers(tester), isEmpty);
      expect(
        find.text('No reports match your search and filters.'),
        findsOneWidget,
      );
      repository.dispose();
    });

    testWidgets('skips reports that do not have valid coordinates', (
      tester,
    ) async {
      final invalidReport = MockData.initialReports.first.copyWith(
        latitude: double.nan,
      );
      final repository = DataRepository(initialReports: [invalidReport]);
      await _pumpMap(tester, repository);

      expect(_mapMarkers(tester), isEmpty);
      expect(
        find.text('No reports with a valid location to display.'),
        findsOneWidget,
      );
      repository.dispose();
    });

    testWidgets(
      'explains when invalid reports are hidden beside valid markers',
      (tester) async {
        final invalidReport = MockData.initialReports.first.copyWith(
          longitude: double.infinity,
        );
        final repository = DataRepository(
          initialReports: [invalidReport, MockData.initialReports[1]],
        );
        await _pumpMap(tester, repository);

        expect(_mapMarkers(tester), hasLength(1));
        expect(
          find.text('1 report hidden because their coordinates are invalid.'),
          findsOneWidget,
        );
        repository.dispose();
      },
    );

    testWidgets(
      'technician report selection opens the external directions handoff',
      (tester) async {
        final report = MockData.initialReports.first;
        final repository = DataRepository(initialReports: [report]);
        await tester.pumpWidget(
          ChangeNotifierProvider<DataRepository>.value(
            value: repository,
            child: MaterialApp(home: SharedMapView(initialReport: report)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Open directions'), findsOneWidget);
        expect(
          find.text('Directions open in an external maps app.'),
          findsOneWidget,
        );
        expect(_mapMarkers(tester), hasLength(1));
        repository.dispose();
      },
    );

    testWidgets(
      'shows an explicit message when location permission is denied',
      (tester) async {
        final previousPlatform = GeolocatorPlatform.instance;
        GeolocatorPlatform.instance = _DeniedLocationPlatform();
        addTearDown(() => GeolocatorPlatform.instance = previousPlatform);

        final repository = DataRepository(initialReports: const []);
        await _pumpMap(tester, repository);
        expect(find.text('No fault reports yet.'), findsOneWidget);

        await tester.tap(find.byTooltip('Show my location').first);
        await tester.pump();
        await tester.pump();

        expect(
          find.text(
            'Location permission was denied. Allow it to show your position.',
          ),
          findsOneWidget,
        );
        repository.dispose();
      },
    );

    testWidgets('explains when blocked-permission settings cannot be opened', (
      tester,
    ) async {
      final previousPlatform = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = _BlockedLocationPlatform();
      addTearDown(() => GeolocatorPlatform.instance = previousPlatform);

      final repository = DataRepository(initialReports: const []);
      await _pumpMap(tester, repository);
      await tester.tap(find.byTooltip('Show my location').first);
      await tester.pump();

      expect(
        find.textContaining('Location permission is blocked.'),
        findsOneWidget,
      );
      tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
          'Could not open settings. Change the location permission in device settings.',
        ),
        findsOneWidget,
      );
      repository.dispose();
    });

    testWidgets('handles unavailable native location settings plugin', (
      tester,
    ) async {
      final previousPlatform = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = _UnavailableSettingsPlatform();
      addTearDown(() => GeolocatorPlatform.instance = previousPlatform);

      final repository = DataRepository(initialReports: const []);
      await _pumpMap(tester, repository);
      await tester.tap(find.byTooltip('Show my location').first);
      await tester.pump();

      tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
          'Could not open settings. Change the location permission in device settings.',
        ),
        findsOneWidget,
      );
      repository.dispose();
    });

    testWidgets('provides accessible map zoom controls', (tester) async {
      final repository = DataRepository(initialReports: const []);
      await _pumpMap(tester, repository);

      expect(find.byTooltip('Zoom in'), findsOneWidget);
      expect(find.byTooltip('Zoom out'), findsOneWidget);
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pump();
      await tester.tap(find.byTooltip('Zoom out'));
      await tester.pump();
      repository.dispose();
    });

    testWidgets('shows current location after permission is granted', (
      tester,
    ) async {
      final previousPlatform = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = _GrantedLocationPlatform();
      addTearDown(() => GeolocatorPlatform.instance = previousPlatform);

      final repository = DataRepository(initialReports: const []);
      await _pumpMap(tester, repository);
      await tester.tap(find.byTooltip('Show my location').first);
      await tester.pump();
      await tester.pump();

      expect(_mapMarkers(tester), hasLength(1));
      repository.dispose();
    });
  });
}

Future<void> _pumpMap(WidgetTester tester, DataRepository repository) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<DataRepository>.value(
      value: repository,
      child: const MaterialApp(home: SharedMapView()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

List<Marker> _mapMarkers(WidgetTester tester) {
  return tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers;
}

class _DeniedLocationPlatform extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.denied;
}

class _GrantedLocationPlatform extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    return Position(
      latitude: 6.9271,
      longitude: 79.8612,
      timestamp: DateTime(2026, 11, 11),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

class _BlockedLocationPlatform extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.deniedForever;

  @override
  Future<bool> openAppSettings() async => false;
}

class _UnavailableSettingsPlatform extends _BlockedLocationPlatform {
  @override
  Future<bool> openAppSettings() async {
    throw MissingPluginException('Location settings are unavailable.');
  }
}
