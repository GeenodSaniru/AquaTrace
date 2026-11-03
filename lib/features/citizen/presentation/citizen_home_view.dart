import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/fault_constants.dart';
import '../../../core/services/data_repository.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_header_bar.dart';
import '../../../core/widgets/app_metric_card.dart';
import '../../../core/widgets/app_report_card_tile.dart';
import '../../auth/providers/auth_provider.dart';

/// Citizen home dashboard matching the Figma prototype.
class CitizenHomeView extends StatelessWidget {
  final Function(int)? onNavigateTab;

  const CitizenHomeView({super.key, this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final dataRepo = Provider.of<DataRepository>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final user = authProvider.currentUser;
    final displayName = user?.displayName ?? 'Amal Perera';
    final area = user?.assignedArea ?? 'Colombo 03';

    final citizenReports = dataRepo.getReportsForCitizen(user?.uid ?? '');
    final activeCount = dataRepo.reports
        .where(
          (r) =>
              r.status == FaultStatus.ongoing ||
              r.status == FaultStatus.assigned ||
              r.status == FaultStatus.pending,
        )
        .length;
    final completedCount = dataRepo.reports
        .where((r) => r.status == FaultStatus.completed)
        .length;
    final nearbyCount = dataRepo.reports.length;

    return Scaffold(
      appBar: AppHeaderBar(
        title: displayName,
        subtitle: 'Good afternoon,',
        secondarySubtitle: area,
        onNotificationTap: () => onNavigateTab?.call(3),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Quick Stat Cards (Active, Completed, Nearby)
            Row(
              children: [
                Expanded(
                  child: AppMetricCard(
                    value: '$activeCount',
                    label: 'Active',
                    color: AppColors.statusOngoing,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppMetricCard(
                    value: '$completedCount',
                    label: 'Completed',
                    color: AppColors.statusCompleted,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppMetricCard(
                    value: '$nearbyCount',
                    label: 'Nearby',
                    color: AppColors.primaryNavy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Report Water Fault Primary CTA
            AppButton(
              label: '+ Report Water Fault',
              height: 52,
              onPressed: () {
                _showReportFaultBottomSheet(context);
              },
            ),
            const SizedBox(height: 12),

            // Secondary Quick Actions (View Map / My Reports)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('View Map'),
                    onPressed: () => onNavigateTab?.call(1),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.assignment_outlined, size: 18),
                    label: const Text('My Reports'),
                    onPressed: () => onNavigateTab?.call(2),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // My Reports Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Reports',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () => onNavigateTab?.call(2),
                  child: const Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryCyan,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // My Reports List
            if (citizenReports.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'No reports submitted yet.',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
              )
            else
              ...citizenReports
                  .take(2)
                  .map(
                    (report) => Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: AppReportCardTile(report: report),
                    ),
                  ),

            const SizedBox(height: 18),

            // Nearby Active Repairs Header
            Row(
              children: [
                const Icon(
                  Icons.near_me_outlined,
                  size: 18,
                  color: AppColors.primaryCyan,
                ),
                const SizedBox(width: 6),
                Text(
                  'Nearby Active Repairs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Nearby List
            ...dataRepo.reports
                .where(
                  (r) =>
                      r.status == FaultStatus.ongoing ||
                      r.status == FaultStatus.assigned,
                )
                .take(3)
                .map(
                  (report) => Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: AppReportCardTile(report: report),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  void _showReportFaultBottomSheet(BuildContext context) {
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
                const Text(
                  'Report Water Fault',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Detailed fault submission with GPS, photo evidence, and severity rating is assigned to Member 3. Member 1 foundation provides this integrated modal interface.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Proceed to Report Form',
              onPressed: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Member 3 fault reporting module ready for implementation.',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
