import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/fault_constants.dart';
import '../../../core/services/data_repository.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_header_bar.dart';
import '../../../core/widgets/app_metric_card.dart';
import '../../../core/widgets/app_priority_badge.dart';
import '../../../core/widgets/app_report_card_tile.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/models/report_model.dart';
import '../../auth/providers/auth_provider.dart';

/// Technician dashboard view conforming to the AquaTrace design specifications.
class TechnicianHomeView extends StatelessWidget {
  final void Function(int, [ReportModel?])? onNavigateTab;

  const TechnicianHomeView({super.key, this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final dataRepo = Provider.of<DataRepository>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final user = authProvider.currentUser;
    final displayName = user?.displayName ?? 'Kasun Jayawardena';
    final employeeId = user?.employeeId ?? 'WB-2024-087';
    final area = user?.assignedArea ?? 'Colombo North';

    final assignedJobs = dataRepo.getReportsForTechnician(user?.uid ?? '');
    final newCount = assignedJobs
        .where((j) => j.status == FaultStatus.assigned)
        .length;
    final ongoingCount = assignedJobs
        .where((j) => j.status == FaultStatus.ongoing)
        .length;
    final completedCount = assignedJobs
        .where((j) => j.status == FaultStatus.completed)
        .length;

    // Next Job
    final nextJob = assignedJobs.isNotEmpty ? assignedJobs.first : null;

    return Scaffold(
      appBar: AppHeaderBar(
        title: displayName,
        subtitle: 'Technician · $employeeId',
        secondarySubtitle: area,
        onNotificationTap: () => onNavigateTab?.call(3),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Metrics (New, Ongoing, Completed)
            Row(
              children: [
                Expanded(
                  child: AppMetricCard(
                    value: '$newCount',
                    label: 'New Jobs',
                    icon: Icons.assignment_outlined,
                    color: AppColors.statusAssigned,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppMetricCard(
                    value: '$ongoingCount',
                    label: 'Ongoing',
                    icon: Icons.build_circle_outlined,
                    color: AppColors.statusOngoing,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppMetricCard(
                    value: '$completedCount',
                    label: 'Completed',
                    icon: Icons.check_circle_outline_rounded,
                    color: AppColors.statusCompleted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Next Job Card
            if (nextJob != null) ...[
              Text(
                'Next Job',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              AppCard(
                borderColor: AppColors.primaryCyan.withValues(alpha: 0.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          nextJob.reportId,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryCyan,
                          ),
                        ),
                        AppStatusBadge(status: nextJob.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      nextJob.faultType.displayName,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
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
                            nextJob.address,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        AppPriorityBadge(severity: nextJob.severity),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.directions_car_outlined,
                          size: 14,
                          color: AppColors.primaryCyan,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '3.4 km · ~12 min ETA',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _showJobDetailModal(context, nextJob);
                            },
                            child: const Text('View Job'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppButton(
                            label: 'Navigate',
                            icon: Icons.navigation_rounded,
                            onPressed: () => onNavigateTab?.call(2, nextJob),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Active Jobs Queue
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Assigned Job Queue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () => onNavigateTab?.call(1),
                  child: const Text(
                    'View all',
                    style: TextStyle(
                      color: AppColors.primaryCyan,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ...assignedJobs.map(
              (job) => Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: AppReportCardTile(
                  report: job,
                  onTap: () => _showJobDetailModal(context, job),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showJobDetailModal(BuildContext context, dynamic job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
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
                  'Job ${job.reportId}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${job.faultType.displayName} · ${job.address}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              job.description,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Technician job workflow (accepting, ongoing repair, and after-repair photo upload) is assigned to Member 6.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            AppButton(label: 'Close', onPressed: () => Navigator.of(ctx).pop()),
          ],
        ),
      ),
    );
  }
}
