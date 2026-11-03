import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/fault_constants.dart';
import '../../../core/models/report_model.dart';
import '../../../core/services/data_repository.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_priority_badge.dart';
import '../../../core/widgets/app_status_badge.dart';

/// Interactive OpenStreetMap fault map matching the Figma prototype.
class SharedMapView extends StatefulWidget {
  const SharedMapView({super.key});

  @override
  State<SharedMapView> createState() => _SharedMapViewState();
}

class _SharedMapViewState extends State<SharedMapView> {
  final MapController _mapController = MapController();
  FaultStatus? _selectedStatusFilter;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataRepo = Provider.of<DataRepository>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredReports = _selectedStatusFilter == null
        ? dataRepo.reports
        : dataRepo.reports
              .where((r) => r.status == _selectedStatusFilter)
              .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fault Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location_rounded),
            tooltip: 'My Location',
            onPressed: () {
              _mapController.move(
                const LatLng(
                  AppConfig.defaultLatitude,
                  AppConfig.defaultLongitude,
                ),
                14.0,
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // OpenStreetMap Layer
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(
                AppConfig.defaultLatitude,
                AppConfig.defaultLongitude,
              ),
              initialZoom: AppConfig.defaultZoom,
              minZoom: 5.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: AppConfig.osmTileUrl,
                userAgentPackageName: 'com.aquatrace.aquatrace',
              ),
              MarkerLayer(
                markers: filteredReports.map((report) {
                  return Marker(
                    point: LatLng(report.latitude, report.longitude),
                    width: 44,
                    height: 44,
                    child: GestureDetector(
                      onTap: () => _showReportDetailsModal(context, report),
                      child: Container(
                        decoration: BoxDecoration(
                          color: report.status.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: report.status.color.withValues(alpha: 0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          report.faultType.icon,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // Top Search Bar & Filters
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search location...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.filter_list_rounded, size: 20),
                          onPressed: () {
                            setState(() {
                              _selectedStatusFilter = null;
                            });
                          },
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Filter Pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: 'All',
                          isSelected: _selectedStatusFilter == null,
                          onSelected: () =>
                              setState(() => _selectedStatusFilter = null),
                        ),
                        ...FaultStatus.values.map(
                          (status) => _buildFilterChip(
                            label: status.displayName,
                            color: status.color,
                            isSelected: _selectedStatusFilter == status,
                            onSelected: () =>
                                setState(() => _selectedStatusFilter = status),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Zoom Controls (+ / -)
          Positioned(
            right: 16,
            bottom: 60,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'map_zoom_in',
                  backgroundColor: isDark
                      ? AppColors.darkSurface
                      : Colors.white,
                  foregroundColor: isDark
                      ? Colors.white
                      : AppColors.primaryNavy,
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      currentZoom + 1,
                    );
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'map_zoom_out',
                  backgroundColor: isDark
                      ? AppColors.darkSurface
                      : Colors.white,
                  foregroundColor: isDark
                      ? Colors.white
                      : AppColors.primaryNavy,
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      currentZoom - 1,
                    );
                  },
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),

          // Bottom Status Legend Bar matching Figma
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkSurface : Colors.white)
                    .withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: FaultStatus.values.map((status) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: status.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    Color? color,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onSelected(),
        selectedColor: (color ?? AppColors.primaryNavy).withValues(alpha: 0.2),
        checkmarkColor: color ?? AppColors.primaryNavy,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? (color ?? AppColors.primaryNavy) : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      ),
    );
  }

  void _showReportDetailsModal(BuildContext context, ReportModel report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  report.reportId,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryCyan,
                  ),
                ),
                AppStatusBadge(status: report.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              report.faultType.displayName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.lightTextMuted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    report.address,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                AppPriorityBadge(severity: report.severity),
                const SizedBox(width: 10),
                Text(
                  'Reported by ${report.reporterName}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(report.description, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 18),
            AppButton(label: 'Close', onPressed: () => Navigator.of(ctx).pop()),
          ],
        ),
      ),
    );
  }
}
