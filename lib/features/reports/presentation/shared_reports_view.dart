import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/fault_constants.dart';
import '../../../core/models/report_model.dart';
import '../../../core/services/data_repository.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_priority_badge.dart';
import '../../../core/widgets/app_report_card_tile.dart';
import '../../../core/widgets/app_status_badge.dart';

/// Reports listing screen with status filtering tabs matching the AquaTrace Figma UI.
class SharedReportsView extends StatefulWidget {
  const SharedReportsView({super.key});

  @override
  State<SharedReportsView> createState() => _SharedReportsViewState();
}

class _SharedReportsViewState extends State<SharedReportsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = [
    'All',
    'Pending',
    'Ongoing',
    'Completed',
    'Disputed',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataRepo = Provider.of<DataRepository>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Water Pipe Reports'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.primaryCyan,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF93C5FD),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) {
          final reports = _filterReports(dataRepo.reports, tab);
          if (reports.isEmpty) {
            return AppEmptyState(
              title: 'No $tab Reports',
              description: 'There are currently no reports with $tab status.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: reports.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final report = reports[index];
              return AppReportCardTile(
                report: report,
                onTap: () => _showReportDetailsModal(context, report),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  List<ReportModel> _filterReports(List<ReportModel> all, String tab) {
    if (tab == 'All') return all;
    final status = FaultStatus.fromString(tab);
    return all.where((r) => r.status == status).toList();
  }

  void _showReportDetailsModal(BuildContext context, ReportModel report) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = DateFormat('MMMM d, yyyy – h:mm a')
        .format(report.createdAt);

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
        child: SingleChildScrollView(
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
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryCyan,
                    ),
                  ),
                  AppStatusBadge(status: report.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                report.faultType.displayName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
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
                      report.address,
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
              const SizedBox(height: 12),
              Row(
                children: [
                  AppPriorityBadge(severity: report.severity),
                  const SizedBox(width: 10),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Description',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                report.description,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Repair Progress',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              _buildProgressSteps(report.status),
              const SizedBox(height: 20),
              AppButton(
                label: 'Close',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSteps(FaultStatus current) {
    final steps = [
      'Reported',
      'Verified',
      'Assigned',
      'Repairing',
      'Completed',
    ];
    int activeIndex = 0;
    switch (current) {
      case FaultStatus.pending:
        activeIndex = 0;
        break;
      case FaultStatus.assigned:
        activeIndex = 2;
        break;
      case FaultStatus.ongoing:
        activeIndex = 3;
        break;
      case FaultStatus.completed:
        activeIndex = 4;
        break;
      case FaultStatus.disputed:
        activeIndex = 3;
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(steps.length, (i) {
        final isDone = i <= activeIndex;
        return Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isDone ? AppColors.primaryCyan : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              steps[i],
              style: TextStyle(
                fontSize: 10,
                fontWeight: isDone ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        );
      }),
    );
  }
}
