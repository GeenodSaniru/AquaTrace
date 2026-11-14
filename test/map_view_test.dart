import 'dart:async';

import 'package:aquatrace/core/constants/fault_constants.dart';
import 'package:aquatrace/core/models/mock_data.dart';
import 'package:aquatrace/core/models/report_model.dart';
import 'package:aquatrace/core/services/data_repository.dart';
import 'package:aquatrace/core/services/report_submission_gateway.dart';
import 'package:aquatrace/features/map/presentation/shared_map_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
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
        final missingLatitude = Map<String, dynamic>.from(report.toMap())
          ..remove('latitude');
        final missingLongitude = Map<String, dynamic>.from(report.toMap())
          ..remove('longitude');
        final malformed = Map<String, dynamic>.from(report.toMap())
          ..['latitude'] = 'not-a-number';
        final invalidLatitude = Map<String, dynamic>.from(report.toMap())
          ..['latitude'] = 90.01;
        final invalidLongitude = Map<String, dynamic>.from(report.toMap())
          ..['longitude'] = -180.01;

        expect(ReportModel.fromMap(missing).hasValidLocation, isFalse);
        expect(ReportModel.fromMap(missingLatitude).hasValidLocation, isFalse);
        expect(ReportModel.fromMap(missingLongitude).hasValidLocation, isFalse);
        expect(ReportModel.fromMap(malformed).hasValidLocation, isFalse);
        expect(ReportModel.fromMap(invalidLatitude).hasValidLocation, isFalse);
        expect(ReportModel.fromMap(invalidLongitude).hasValidLocation, isFalse);
        expect(
          ReportModel.fromMap(
            Map<String, dynamic>.from(report.toMap())
              ..['latitude'] = -90
              ..['longitude'] = 180,
          ).hasValidLocation,
          isTrue,
        );
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
      for (final marker in _reportMarkerTooltips(tester)) {
        final status = FaultStatus.fromString(marker.message!.split(':').first);
        final markerContainer = marker.child as Container;
        expect(
          (markerContainer.decoration! as BoxDecoration).color,
          status.color,
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

    testWidgets('hides reports with missing and out-of-range map coordinates', (
      tester,
    ) async {
      final reportData = MockData.initialReports.first.toMap();
      final missingLatitude = Map<String, dynamic>.from(reportData)
        ..remove('latitude');
      final outOfRangeLongitude = Map<String, dynamic>.from(reportData)
        ..['reportId'] = 'AT-map-invalid-longitude'
        ..['longitude'] = 180.1;
      final repository = DataRepository(
        initialReports: [
          ReportModel.fromMap(missingLatitude),
          ReportModel.fromMap(outOfRangeLongitude),
          MockData.initialReports[1],
        ],
      );
      await _pumpMap(tester, repository);

      expect(_mapMarkers(tester), hasLength(1));
      expect(
        find.text('2 reports hidden because their coordinates are invalid.'),
        findsOneWidget,
      );
      repository.dispose();
    });

    testWidgets('plots report latitude and longitude in the correct order', (
      tester,
    ) async {
      final report = MockData.initialReports.first;
      final repository = DataRepository(initialReports: [report]);
      await _pumpMap(tester, repository);

      expect(
        _mapMarkers(tester).single.point,
        LatLng(report.latitude, report.longitude),
      );
      repository.dispose();
    });

    testWidgets('opens report details when a marker is selected', (
      tester,
    ) async {
      final report = MockData.initialReports.first;
      final repository = DataRepository(initialReports: [report]);
      await _pumpMap(tester, repository);

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(find.text(report.reportId), findsOneWidget);
      expect(find.text(report.address), findsOneWidget);
      expect(find.text(report.description), findsOneWidget);
      repository.dispose();
    });

    testWidgets('renders the capped report workload without dropping markers', (
      tester,
    ) async {
      final reports = List.generate(
        500,
        (index) => MockData
            .initialReports[index % MockData.initialReports.length]
            .copyWith(
              reportId: 'AT-map-$index',
              latitude: 6.8 + index / 10000,
              longitude: 79.8 + index / 10000,
            ),
      );
      final repository = DataRepository(initialReports: reports);
      await _pumpMap(tester, repository);

      expect(_mapMarkers(tester), hasLength(500));
      repository.dispose();
    });

    testWidgets('shows tile failures and clears the banner on retry', (
      tester,
    ) async {
      final repository = DataRepository(initialReports: const []);
      await _pumpMap(tester, repository);

      final tileLayer = tester.widget<TileLayer>(find.byType(TileLayer));
      expect(tileLayer.errorTileCallback, isNotNull);
      final tile = TileImage(
        coordinates: const TileCoordinates(0, 0, 0),
        vsync: const TestVSync(),
        imageProvider: const NetworkImage('https://tiles.invalid/0/0/0.png'),
        onLoadComplete: (_) {},
        onLoadError: (_, _, _) {},
        tileDisplay: const TileDisplay.instantaneous(),
        errorImage: null,
        cancelLoading: Completer<void>(),
      );
      tileLayer.errorTileCallback!(tile, Exception('offline'), null);
      await tester.pump();

      expect(
        find.text('Map tiles unavailable. Check your connection.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(
        find.text('Map tiles unavailable. Check your connection.'),
        findsNothing,
      );
      tile.dispose();
      repository.dispose();
    });

    testWidgets('updates markers when repository reports change', (
      tester,
    ) async {
      final repository = DataRepository(
        initialReports: const [],
        reportSubmissionGateway: _FakeReportSubmissionGateway(),
      );
      await _pumpMap(tester, repository);
      expect(_mapMarkers(tester), isEmpty);

      final report = MockData.initialReports.first.copyWith(
        reportId: 'AT-map-live-update',
        status: FaultStatus.pending,
        latitude: 6.912345,
        longitude: 79.812345,
      );
      await repository.addReport(
        report,
        evidenceBytes: Uint8List.fromList([1]),
        contentType: 'image/jpeg',
      );
      await tester.pump();

      expect(_mapMarkers(tester), hasLength(1));
      expect(_mapMarkers(tester).single.point, LatLng(6.912345, 79.812345));
      expect(
        (_mapMarkers(tester).single.child as Semantics).properties.label,
        startsWith('Pending'),
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
      'opens the selected report coordinates in external directions',
      (tester) async {
        final report = MockData.initialReports.first;
        final repository = DataRepository(initialReports: [report]);
        const urlLauncherChannel = MethodChannel(
          'plugins.flutter.io/url_launcher',
        );
        final launchedUrls = <String>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(urlLauncherChannel, (call) async {
              if (call.method == 'launch') {
                launchedUrls.add(
                  (call.arguments as Map<Object?, Object?>)['url']! as String,
                );
                return true;
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(urlLauncherChannel, null),
        );
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
        await tester.tap(find.text('Open directions'));
        await tester.pumpAndSettle();

        expect(launchedUrls, hasLength(1));
        expect(
          Uri.parse(launchedUrls.single).queryParameters['destination'],
          '${report.latitude},${report.longitude}',
        );
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
      double currentZoom() =>
          MapCamera.of(tester.element(find.byType(MarkerLayer))).zoom;

      final initialZoom = currentZoom();
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pump();
      expect(currentZoom(), initialZoom + 1);
      await tester.tap(find.byTooltip('Zoom out'));
      await tester.pump();
      expect(currentZoom(), initialZoom);
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

    testWidgets('does not request a fix when permission is indeterminate', (
      tester,
    ) async {
      final previousPlatform = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = _IndeterminateLocationPermissionPlatform();
      addTearDown(() => GeolocatorPlatform.instance = previousPlatform);

      final repository = DataRepository(initialReports: const []);
      await _pumpMap(tester, repository);
      await tester.tap(find.byTooltip('Show my location').first);
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
          'Location permission is unavailable. Check your device or browser settings.',
        ),
        findsOneWidget,
      );
      expect(_mapMarkers(tester), isEmpty);
      repository.dispose();
    });

    testWidgets('does not plot an invalid GPS fix', (tester) async {
      final previousPlatform = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = _InvalidPositionPlatform();
      addTearDown(() => GeolocatorPlatform.instance = previousPlatform);

      final repository = DataRepository(initialReports: const []);
      await _pumpMap(tester, repository);
      await tester.tap(find.byTooltip('Show my location').first);
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Your device returned an invalid location. Try again.'),
        findsOneWidget,
      );
      expect(_mapMarkers(tester), isEmpty);
      repository.dispose();
    });

    testWidgets('explains unavailable location services', (tester) async {
      final previousPlatform = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = _LocationServicesDisabledPlatform();
      addTearDown(() => GeolocatorPlatform.instance = previousPlatform);

      final repository = DataRepository(initialReports: const []);
      await _pumpMap(tester, repository);
      await tester.tap(find.byTooltip('Show my location').first);
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
          'Location services are turned off. Enable them to find your position.',
        ),
        findsOneWidget,
      );
      repository.dispose();
    });

    testWidgets('explains location lookup timeout', (tester) async {
      final previousPlatform = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = _TimedOutLocationPlatform();
      addTearDown(() => GeolocatorPlatform.instance = previousPlatform);

      final repository = DataRepository(initialReports: const []);
      await _pumpMap(tester, repository);
      await tester.tap(find.byTooltip('Show my location').first);
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
          'Your location could not be found in time. Check GPS and try again.',
        ),
        findsOneWidget,
      );
      repository.dispose();
    });
  });
}

class _FakeReportSubmissionGateway implements ReportSubmissionGateway {
  @override
  Future<String> uploadEvidence({
    required ReportModel report,
    required Uint8List bytes,
    required String contentType,
  }) async => 'https://storage.example/evidence.jpg';

  @override
  Future<void> createReport(ReportModel report) async {}
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

List<Tooltip> _reportMarkerTooltips(WidgetTester tester) {
  return tester
      .widgetList<Tooltip>(
        find.descendant(
          of: find.byType(MarkerLayer),
          matching: find.byType(Tooltip),
        ),
      )
      .toList();
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

class _LocationServicesDisabledPlatform extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => false;
}

class _TimedOutLocationPlatform extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    throw TimeoutException('Location lookup timed out.');
  }
}

class _IndeterminateLocationPermissionPlatform extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.unableToDetermine;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    throw StateError(
      'A location fix must not be requested without permission.',
    );
  }
}

class _InvalidPositionPlatform extends _GrantedLocationPlatform {
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
    latitude: 91,
    longitude: 79.8612,
    timestamp: DateTime(2026, 11, 14),
    accuracy: 10,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
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
