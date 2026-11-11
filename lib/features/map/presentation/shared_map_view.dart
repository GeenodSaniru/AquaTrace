import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/fault_constants.dart';
import '../../../core/models/report_model.dart';
import '../../../core/services/data_repository.dart';
import '../../../core/widgets/app_priority_badge.dart';
import '../../../core/widgets/app_status_badge.dart';

/// Shared citizen, technician, and admin OpenStreetMap fault map.
class SharedMapView extends StatefulWidget {
  final ReportModel? initialReport;

  const SharedMapView({super.key, this.initialReport});

  @override
  State<SharedMapView> createState() => _SharedMapViewState();
}

class _SharedMapViewState extends State<SharedMapView> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final StreamController<void> _tileResetController =
      StreamController<void>.broadcast();

  Set<FaultStatus>? _selectedStatuses;
  LatLng? _currentLocation;
  String _searchQuery = '';
  bool _isLocating = false;
  bool _mapReady = false;
  bool _tileLoadFailed = false;

  @override
  void initState() {
    super.initState();
    final initialReport = widget.initialReport;
    if (initialReport != null) {
      _selectedStatuses = {initialReport.status};
    }
  }

  @override
  void didUpdateWidget(covariant SharedMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newReport = widget.initialReport;
    if (newReport != null && newReport != oldWidget.initialReport) {
      setState(() => _selectedStatuses = {newReport.status});
      _focusReport(newReport, showDetails: true);
    } else if (newReport == null && oldWidget.initialReport != null) {
      setState(() => _selectedStatuses = null);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    _tileResetController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<DataRepository>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reportsWithLocations = repository.reports
        .where((report) => report.hasValidLocation)
        .toList(growable: false);
    final reportsWithoutLocations =
        repository.reports.length - reportsWithLocations.length;
    final visibleReports = reportsWithLocations
        .where((report) {
          final matchesStatus =
              _selectedStatuses == null ||
              _selectedStatuses!.contains(report.status);
          final matchesSearch =
              _searchQuery.isEmpty ||
              <String>[
                report.reportId,
                report.address,
                report.faultType.displayName,
                report.description,
                report.reporterName,
                report.assignedTechnicianName ?? '',
              ].any((value) => value.toLowerCase().contains(_searchQuery));
          return matchesStatus && matchesSearch;
        })
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fault Map'),
        actions: [
          IconButton(
            tooltip: 'Show my location',
            onPressed: _isLocating ? null : _centerOnCurrentLocation,
            icon: _isLocating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(
                AppConfig.defaultLatitude,
                AppConfig.defaultLongitude,
              ),
              initialZoom: AppConfig.defaultZoom,
              minZoom: 5,
              maxZoom: 19,
              onMapReady: () {
                _mapReady = true;
                final report = widget.initialReport;
                if (report != null) _focusReport(report, showDetails: true);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: AppConfig.osmTileUrl,
                userAgentPackageName: 'com.aquatrace.aquatrace',
                maxNativeZoom: 19,
                keepBuffer: 1,
                panBuffer: 0,
                reset: _tileResetController.stream,
                errorTileCallback: (tile, error, stackTrace) {
                  if (mounted && !_tileLoadFailed) {
                    setState(() => _tileLoadFailed = true);
                    debugPrint(
                      '[AquaTrace] Map tile ${tile.coordinates} failed: $error',
                    );
                  }
                },
              ),
              MarkerLayer(
                markers: [
                  for (final report in visibleReports)
                    Marker(
                      point: LatLng(report.latitude, report.longitude),
                      width: 46,
                      height: 46,
                      child: Semantics(
                        button: true,
                        label:
                            '${report.status.displayName} ${report.faultType.displayName}, '
                            '${report.address}',
                        child: GestureDetector(
                          onTap: () => _showReportDetails(context, report),
                          child: _ReportMapMarker(report: report),
                        ),
                      ),
                    ),
                  if (_currentLocation case final location?)
                    Marker(
                      point: location,
                      width: 38,
                      height: 38,
                      child: const _CurrentLocationMarker(),
                    ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Material(
                          elevation: 3,
                          color: isDark
                              ? AppColors.darkSurface
                              : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(14),
                          child: TextField(
                            controller: _searchController,
                            textInputAction: TextInputAction.search,
                            onChanged: (value) => setState(
                              () => _searchQuery = value.trim().toLowerCase(),
                            ),
                            onSubmitted: (_) =>
                                _focusFirstSearchResult(visibleReports),
                            decoration: InputDecoration(
                              hintText: 'Search location or report',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _searchQuery.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        elevation: 3,
                        color: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(14),
                        child: OutlinedButton.icon(
                          onPressed: _showStatusFilters,
                          icon: const Icon(Icons.filter_list_rounded, size: 19),
                          label: Text(
                            _selectedStatuses == null ||
                                    _selectedStatuses!.length ==
                                        FaultStatus.values.length
                                ? 'Filter'
                                : 'Filter (${_selectedStatuses!.length})',
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: const BorderSide(
                              color: AppColors.primaryCyan,
                            ),
                            foregroundColor: AppColors.primaryCyan,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Material(
                      color:
                          (isDark
                                  ? AppColors.darkSurface
                                  : AppColors.lightSurface)
                              .withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _openMapAttribution,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            '© ${AppConfig.mapTileAttribution}',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 126,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (repository.reportsLoading)
                  const _MapMessage(
                    icon: null,
                    message: 'Loading fault reports…',
                    showProgress: true,
                  ),
                if (reportsWithoutLocations > 0 &&
                    reportsWithLocations.isNotEmpty)
                  _MapMessage(
                    icon: Icons.location_off_outlined,
                    message:
                        '$reportsWithoutLocations ${reportsWithoutLocations == 1 ? 'report' : 'reports'} hidden because their coordinates are invalid.',
                  ),
                if (repository.reportsErrorMessage case final error?)
                  _RetryMessage(
                    message: error,
                    onRetry: repository.retryReportSync,
                  ),
                if (_tileLoadFailed)
                  _RetryMessage(
                    message: 'Map tiles unavailable. Check your connection.',
                    onRetry: _retryMapTiles,
                  ),
              ],
            ),
          ),
          if (!repository.reportsLoading &&
              repository.reportsErrorMessage == null &&
              visibleReports.isEmpty)
            Center(
              child: _MapMessage(
                icon: Icons.location_off_outlined,
                message: repository.reports.isEmpty
                    ? 'No fault reports yet.'
                    : reportsWithLocations.isEmpty
                    ? 'No reports with a valid location to display.'
                    : 'No reports match your search and filters.',
              ),
            ),
          Positioned(
            right: 14,
            bottom: 76,
            child: Column(
              children: [
                _MapControl(
                  tooltip: 'Zoom in',
                  icon: Icons.add_rounded,
                  onPressed: () => _changeZoom(1),
                ),
                const SizedBox(height: 8),
                _MapControl(
                  tooltip: 'Zoom out',
                  icon: Icons.remove_rounded,
                  onPressed: () => _changeZoom(-1),
                ),
                const SizedBox(height: 8),
                _MapControl(
                  tooltip: 'Show my location',
                  icon: _isLocating
                      ? Icons.hourglass_top_rounded
                      : Icons.my_location_rounded,
                  onPressed: _isLocating ? null : _centerOnCurrentLocation,
                ),
              ],
            ),
          ),
          Positioned(
            left: 12,
            right: 68,
            bottom: 8,
            child: _StatusLegend(isDark: isDark),
          ),
        ],
      ),
    );
  }

  void _changeZoom(double delta) {
    if (!_mapReady) return;
    final camera = _mapController.camera;
    _mapController.move(camera.center, (camera.zoom + delta).clamp(5.0, 19.0));
    if (_tileLoadFailed) setState(() => _tileLoadFailed = false);
  }

  void _retryMapTiles() {
    setState(() => _tileLoadFailed = false);
    _tileResetController.add(null);
  }

  void _focusFirstSearchResult(List<ReportModel> reports) {
    if (reports.isNotEmpty) _focusReport(reports.first);
  }

  void _focusReport(ReportModel report, {bool showDetails = false}) {
    if (!report.hasValidLocation) {
      if (showDetails && mounted) {
        _showMessage('This report does not have a valid map location.');
      }
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReady) return;
      _mapController.move(LatLng(report.latitude, report.longitude), 16);
      if (showDetails) _showReportDetails(context, report);
    });
  }

  Future<void> _centerOnCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showMessage(
          'Location services are turned off. Enable them to find your position.',
          actionLabel: 'Location settings',
          onAction: Geolocator.openLocationSettings,
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _showMessage(
          'Location permission is blocked. Allow it in app settings to use your location.',
          actionLabel: 'App settings',
          onAction: Geolocator.openAppSettings,
        );
        return;
      }
      if (permission == LocationPermission.denied) {
        _showMessage(
          'Location permission was denied. Allow it to show your position.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      if (_mapReady) {
        _mapController.move(_currentLocation!, 16);
      }
    } on LocationServiceDisabledException {
      _showMessage(
        'Location services are turned off. Enable them to find your position.',
        actionLabel: 'Location settings',
        onAction: Geolocator.openLocationSettings,
      );
    } on PermissionDeniedException {
      _showMessage(
        'Location permission was denied. Allow it in app settings to use your location.',
        actionLabel: 'App settings',
        onAction: Geolocator.openAppSettings,
      );
    } on TimeoutException {
      _showMessage(
        'Your location could not be found in time. Check GPS and try again.',
      );
    } on Exception catch (error, stackTrace) {
      debugPrint(
        '[AquaTrace] Could not get current location: $error\n$stackTrace',
      );
      _showMessage('Could not get your location. Please try again.');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _openMapAttribution() async {
    try {
      final launched = await launchUrl(
        Uri.parse(AppConfig.mapTileAttributionUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) _showMessage('Could not open map attribution.');
    } on Exception catch (error, stackTrace) {
      debugPrint(
        '[AquaTrace] Could not open map attribution: $error\n$stackTrace',
      );
      _showMessage('Could not open map attribution.');
    }
  }

  void _showMessage(
    String message, {
    String? actionLabel,
    Future<bool> Function()? onAction,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: actionLabel == null || onAction == null
              ? null
              : SnackBarAction(
                  label: actionLabel,
                  onPressed: () => _openSettings(onAction),
                ),
        ),
      );
  }

  Future<void> _openSettings(Future<bool> Function() openSettings) async {
    if (kIsWeb) {
      _showMessage('Change location permission in your browser settings.');
      return;
    }

    try {
      final opened = await openSettings();
      if (!opened) {
        _showMessage(
          'Could not open settings. Change the location permission in device settings.',
        );
      }
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint(
        '[AquaTrace] Could not open location settings: $error\n$stackTrace',
      );
      _showMessage(
        'Could not open settings. Change the location permission in device settings.',
      );
    } on Exception catch (error, stackTrace) {
      debugPrint(
        '[AquaTrace] Could not open location settings: $error\n$stackTrace',
      );
      _showMessage(
        'Could not open settings. Change the location permission in device settings.',
      );
    }
  }

  Future<void> _showStatusFilters() async {
    final initial = _selectedStatuses == null
        ? FaultStatus.values.toSet()
        : Set<FaultStatus>.from(_selectedStatuses!);
    final selection = await showModalBottomSheet<Set<FaultStatus>>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        var selected = Set<FaultStatus>.from(initial);
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Filter by status',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final status in FaultStatus.values)
                        FilterChip(
                          label: Text(status.displayName),
                          selected: selected.contains(status),
                          selectedColor: status.color.withValues(alpha: 0.18),
                          checkmarkColor: status.color,
                          labelStyle: TextStyle(
                            color: selected.contains(status)
                                ? Theme.of(context).colorScheme.onSurface
                                : status.color,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (isSelected) {
                            setSheetState(() {
                              if (isSelected) {
                                selected.add(status);
                              } else {
                                selected.remove(status);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context, FaultStatus.values.toSet()),
                        child: const Text('Reset'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, selected),
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (!mounted || selection == null) return;
    setState(() {
      _selectedStatuses = selection.length == FaultStatus.values.length
          ? null
          : selection;
    });
  }

  void _showReportDetails(BuildContext context, ReportModel report) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      report.reportId,
                      style: const TextStyle(
                        color: AppColors.primaryCyan,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AppStatusBadge(status: report.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                report.faultType.displayName,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              _ReportDetailLine(
                icon: Icons.location_on_outlined,
                text: report.address,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppPriorityBadge(severity: report.severity),
                  Text('Reported by ${report.reporterName}'),
                ],
              ),
              if (report.assignedTechnicianName != null) ...[
                const SizedBox(height: 8),
                _ReportDetailLine(
                  icon: Icons.engineering_outlined,
                  text: 'Technician: ${report.assignedTechnicianName}',
                ),
              ],
              const SizedBox(height: 12),
              Text(report.description),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: report.hasValidLocation
                          ? () {
                              Navigator.pop(sheetContext);
                              _openDirections(report);
                            }
                          : null,
                      icon: const Icon(Icons.directions_rounded),
                      label: const Text('Open directions'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Directions open in an external maps app.',
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDirections(ReportModel report) async {
    if (!report.hasValidLocation) {
      _showMessage('This report does not have a valid map location.');
      return;
    }
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${report.latitude},${report.longitude}',
      'travelmode': 'driving',
    });
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showMessage('Could not open an external maps app on this device.');
      }
    } on Exception catch (error, stackTrace) {
      debugPrint(
        '[AquaTrace] Could not open report directions: $error\n$stackTrace',
      );
      _showMessage('Could not open an external maps app on this device.');
    }
  }
}

class _ReportMapMarker extends StatelessWidget {
  final ReportModel report;

  const _ReportMapMarker({required this.report});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${report.status.displayName}: ${report.address}',
      child: Container(
        decoration: BoxDecoration(
          color: report.status.color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: report.status.color.withValues(alpha: 0.4),
              blurRadius: 7,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(report.faultType.icon, size: 20, color: Colors.white),
      ),
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryCyan,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: const Icon(
        Icons.my_location_rounded,
        color: Colors.white,
        size: 18,
      ),
    );
  }
}

class _MapControl extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _MapControl({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      color: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
        color: AppColors.primaryNavy,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      ),
    );
  }
}

class _StatusLegend extends StatelessWidget {
  final bool isDark;

  const _StatusLegend({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      color: (isDark ? AppColors.darkSurface : Colors.white).withValues(
        alpha: 0.96,
      ),
      borderRadius: BorderRadius.circular(20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            for (final status in FaultStatus.values) ...[
              if (status != FaultStatus.pending) const SizedBox(width: 12),
              Icon(status.icon, size: 14, color: status.color),
              const SizedBox(width: 4),
              Text(
                status.displayName,
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MapMessage extends StatelessWidget {
  final IconData? icon;
  final String message;
  final bool showProgress;

  const _MapMessage({
    required this.icon,
    required this.message,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showProgress) ...[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
            ] else if (icon != null) ...[
              Icon(icon, size: 20, color: AppColors.primaryCyan),
              const SizedBox(width: 8),
            ],
            Flexible(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _RetryMessage extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _RetryMessage({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        elevation: 3,
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          child: Row(
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                color: AppColors.statusDisputed,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportDetailLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ReportDetailLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primaryCyan),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}
