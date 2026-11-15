import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/report_model.dart';
import '../../../core/widgets/app_priority_badge.dart';
import '../../../core/widgets/app_status_badge.dart';

class TechnicianJobDetailScreen extends StatelessWidget {
  final ReportModel report;
  final VoidCallback? onNavigate;

  const TechnicianJobDetailScreen({
    super.key,
    required this.report,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        actions: [
          if (onNavigate != null)
            IconButton(
              tooltip: 'Open map',
              icon: const Icon(Icons.navigation_rounded),
              onPressed: onNavigate,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                report.reportId,
                style: const TextStyle(
                  color: AppColors.primaryCyan,
                  fontWeight: FontWeight.w700,
                ),
              ),
              AppStatusBadge(status: report.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            report.faultType.displayName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              AppPriorityBadge(severity: report.severity),
              const SizedBox(width: 10),
              if (report.isEmergency)
                const Chip(
                  avatar: Icon(Icons.warning_amber_rounded, size: 16),
                  label: Text('Emergency'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _DetailCard(
            title: 'Location',
            icon: Icons.location_on_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.address,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${report.latitude.toStringAsFixed(5)}, '
                  '${report.longitude.toStringAsFixed(5)}',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                if (onNavigate != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onNavigate,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Open in map'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _DetailCard(
            title: 'Fault description',
            icon: Icons.description_outlined,
            child: Text(report.description),
          ),
          const SizedBox(height: 14),
          _EvidenceCard(
            title: 'Before-repair evidence',
            imageUrl: report.beforeImageUrl,
          ),
          if (report.afterImageUrl != null &&
              report.afterImageUrl!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _EvidenceCard(
              title: 'After-repair evidence',
              imageUrl: report.afterImageUrl,
            ),
          ],
          const SizedBox(height: 14),
          _DetailCard(
            title: 'Job history',
            icon: Icons.history_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HistoryRow(
                  label: 'Reported',
                  value: _formatDate(report.createdAt),
                ),
                if (report.updatedAt != null)
                  _HistoryRow(
                    label: 'Last updated',
                    value: _formatDate(report.updatedAt!),
                  ),
                if (report.repairNotes != null &&
                    report.repairNotes!.trim().isNotEmpty)
                  _HistoryRow(
                    label: 'Repair notes',
                    value: report.repairNotes!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day}/${local.month}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _DetailCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primaryCyan),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  final String title;
  final String? imageUrl;

  const _EvidenceCard({required this.title, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      title: title,
      icon: Icons.photo_camera_outlined,
      child: imageUrl == null || imageUrl!.isEmpty
          ? const Text('No photo available.')
          : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl!,
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Text('Photo could not be loaded.'),
              ),
            ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final String label;
  final String value;

  const _HistoryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.lightTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
