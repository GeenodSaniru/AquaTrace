import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_roles.dart';
import '../../../core/constants/fault_constants.dart';
import '../../../core/models/report_model.dart';
import '../../../core/services/data_repository.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_header_bar.dart';
import '../../../core/widgets/app_metric_card.dart';
import '../../auth/providers/auth_provider.dart';

/// Admin dashboard view matching the Figma specifications.
class AdminDashboardView extends StatelessWidget {
  final Function(int)? onNavigateTab;

  const AdminDashboardView({super.key, this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    if (authProvider.currentRole != UserRole.admin) {
      return const Scaffold(
        body: Center(child: Text('Administrator access is required.')),
      );
    }
    final dataRepo = Provider.of<DataRepository>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final user = authProvider.currentUser;
    final displayName = user?.displayName ?? 'Dilani Wickramasinghe';
    final dateFormatted = DateFormat('EEEE, MMMM d, yyyy')
        .format(DateTime.now());

    final totalReports = dataRepo.reports.length;
    final pendingCount = dataRepo.reports
        .where((r) => r.status == FaultStatus.pending)
        .length;
    final assignedCount = dataRepo.reports
        .where((r) => r.status == FaultStatus.assigned)
        .length;
    final ongoingCount = dataRepo.reports
        .where((r) => r.status == FaultStatus.ongoing)
        .length;
    final completedCount = dataRepo.reports
        .where((r) => r.status == FaultStatus.completed)
        .length;
    final disputedCount = dataRepo.reports
        .where((r) => r.status == FaultStatus.disputed)
        .length;
    final trend = _buildTrend(dataRepo.reports);
    final trendTotal = trend.fold<int>(
      0,
      (total, bucket) => total + bucket.count,
    );

    return Scaffold(
      appBar: AppHeaderBar(
        title: displayName,
        subtitle: 'Admin · Water Board',
        secondarySubtitle: dateFormatted,
        onNotificationTap: () => onNavigateTab?.call(3),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 3x2 Metric Cards Grid
            Row(
              children: [
                Expanded(
                  child: AppMetricCard(
                    value: '$totalReports',
                    label: 'Total',
                    icon: Icons.bar_chart_rounded,
                    color: AppColors.primaryNavy,
                    onTap: () => onNavigateTab?.call(1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppMetricCard(
                    value: '$pendingCount',
                    label: 'Pending',
                    icon: Icons.schedule_rounded,
                    color: AppColors.statusPending,
                    onTap: () => onNavigateTab?.call(1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppMetricCard(
                    value: '$assignedCount',
                    label: 'Assigned',
                    icon: Icons.assignment_outlined,
                    color: AppColors.statusAssigned,
                    onTap: () => onNavigateTab?.call(1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppMetricCard(
                    value: '$ongoingCount',
                    label: 'Ongoing',
                    icon: Icons.build_circle_outlined,
                    color: AppColors.statusOngoing,
                    onTap: () => onNavigateTab?.call(1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppMetricCard(
                    value: '$completedCount',
                    label: 'Completed',
                    icon: Icons.check_circle_outline_rounded,
                    color: AppColors.statusCompleted,
                    onTap: () => onNavigateTab?.call(1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppMetricCard(
                    value: '$disputedCount',
                    label: 'Disputed',
                    icon: Icons.error_outline_rounded,
                    color: AppColors.statusDisputed,
                    onTap: () => onNavigateTab?.call(1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (dataRepo.reportsError != null)
              MaterialBanner(
                content: Text(dataRepo.reportsError!),
                actions: [
                  TextButton(
                    onPressed: dataRepo.retryReportsSync,
                    child: const Text('Retry'),
                  ),
                ],
              ),

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Report trend · ${trend.first.label} - ${trend.last.label}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      Text(
                        '$trendTotal total',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryCyan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 90,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: trend
                          .map(
                            (bucket) => _buildTrendBar(
                              label: bucket.label,
                              heightPercent: trendTotal == 0
                                  ? 0
                                  : bucket.count /
                                        trend
                                            .map((b) => b.count)
                                            .reduce((a, b) => a > b ? a : b),
                              count: bucket.count,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick Actions List
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 10),

            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildQuickActionTile(
                    context: context,
                    icon: Icons.assignment_turned_in_outlined,
                    title: 'Review Reports',
                    subtitle: '$pendingCount pending review',
                    onTap: () => onNavigateTab?.call(1),
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                  _buildQuickActionTile(
                    context: context,
                    icon: Icons.person_add_alt_1_outlined,
                    title: 'Assign Technician',
                    subtitle: 'Assign verified reports to active technicians',
                    onTap: () => onNavigateTab?.call(1),
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                  _buildQuickActionTile(
                    context: context,
                    icon: Icons.map_outlined,
                    title: 'View Map',
                    subtitle: 'All faults and municipal status on map',
                    onTap: () => onNavigateTab?.call(2),
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                  _buildQuickActionTile(
                    context: context,
                    icon: Icons.gavel_rounded,
                    title: 'Manage Disputes',
                    subtitle: '$disputedCount active community disputes',
                    onTap: () => onNavigateTab?.call(1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendBar({
    required String label,
    required double heightPercent,
    required int count,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 24,
          height: 60 * heightPercent,
          decoration: BoxDecoration(
            color: count > 0 ? AppColors.primaryNavy : AppColors.lightBorder,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.lightTextMuted),
        ),
      ],
    );
  }

  List<_TrendBucket> _buildTrend(List<ReportModel> reports) {
    final latest =
        reports.fold<DateTime?>(
          null,
          (current, report) =>
              current == null || report.createdAt.isAfter(current)
              ? report.createdAt
              : current,
        ) ??
        DateTime.now();
    final start = DateTime(
      latest.year,
      latest.month,
      latest.day,
    ).subtract(const Duration(days: 28));
    return List.generate(5, (index) {
      final bucketStart = start.add(Duration(days: index * 7));
      final bucketEnd = bucketStart.add(const Duration(days: 7));
      final count = reports.where((report) {
        return !report.createdAt.isBefore(bucketStart) &&
            report.createdAt.isBefore(bucketEnd);
      }).length;
      return _TrendBucket(DateFormat('MMM d').format(bucketStart), count);
    });
  }

  Widget _buildQuickActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryNavy.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primaryNavy, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: AppColors.lightTextMuted,
      ),
      onTap: onTap,
    );
  }
}

class _TrendBucket {
  final String label;
  final int count;

  const _TrendBucket(this.label, this.count);
}
