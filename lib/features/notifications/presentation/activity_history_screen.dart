import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/fault_constants.dart';
import '../../../core/models/activity_timeline_event.dart';
import '../../../core/models/report_model.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/services/data_repository.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_widget.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_status_badge.dart';
import 'notification_formatters.dart';

/// Chronological audit trail of one report: submitted, verified, assigned,
/// repair started / completed, community verified, dispute opened.
///
/// Events are shown oldest first, exactly as recorded; the screen never
/// invents or reorders entries.
class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key, required this.reportId});

  final String reportId;

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  late Stream<List<ActivityTimelineEvent>> _history;
  bool _created = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_created) {
      _created = true;
      _history = context.read<DataRepository>().watchReportHistory(
        widget.reportId,
      );
    }
  }

  void _retry() {
    setState(() {
      _history = context.read<DataRepository>().watchReportHistory(
        widget.reportId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = context.watch<DataRepository>().getReportById(
      widget.reportId,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Activity History')),
      body: StreamBuilder<List<ActivityTimelineEvent>>(
        stream: _history,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AppErrorWidget(
              message:
                  'The activity history could not be loaded. Check your '
                  'connection and access, then try again.',
              onRetry: _retry,
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const AppLoadingIndicator(message: 'Loading history…');
          }
          final events = snapshot.data ?? const <ActivityTimelineEvent>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              _ReportHeader(reportId: widget.reportId, report: report),
              const SizedBox(height: 18),
              if (events.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: AppEmptyState(
                    icon: Icons.history_rounded,
                    title: 'No activity yet',
                    description:
                        'Updates for this report will appear here as they '
                        'happen.',
                  ),
                )
              else
                for (var i = 0; i < events.length; i++)
                  _TimelineRow(
                    event: events[i],
                    isLast: i == events.length - 1,
                  ),
              if (report != null &&
                  report.verificationCount > 0 &&
                  report.status != FaultStatus.disputed) ...[
                const SizedBox(height: 12),
                _CommunityVerifiedCard(count: report.verificationCount),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({required this.reportId, required this.report});

  final String reportId;
  final ReportModel? report;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final summary = report == null
        ? 'Report details are not available.'
        : '${report!.faultType.displayName} · ${report!.address}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report',
                  style: TextStyle(fontSize: 12, color: secondary),
                ),
                const SizedBox(height: 2),
                Text(
                  reportId,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryCyan,
                  ),
                ),
                const SizedBox(height: 4),
                Text(summary, style: TextStyle(fontSize: 13, color: secondary)),
              ],
            ),
          ),
          if (report != null) AppStatusBadge(status: report!.status),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.isLast});

  final ActivityTimelineEvent event;
  final bool isLast;

  static IconData _iconFor(ActivityTimelineEvent event) {
    final title = event.title.toLowerCase();
    if (title.contains('submitted')) return Icons.description_outlined;
    if (title.contains('community')) return Icons.groups_outlined;
    if (title.contains('dispute')) return Icons.error_outline_rounded;
    if (title.contains('verified') || title.contains('approved')) {
      return Icons.verified_user_outlined;
    }
    if (title.contains('assigned')) return Icons.person_add_alt_1_outlined;
    if (title.contains('started')) return Icons.build_outlined;
    if (title.contains('completed')) return Icons.check_circle_outline_rounded;
    return event.status.icon;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = event.status.color;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final muted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final when = NotificationFormatters.absoluteTime(event.timestamp);

    return Semantics(
      container: true,
      label: '${event.title}. $when. ${event.description}. ${event.actorName}.',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withValues(alpha: 0.5)),
                    ),
                    child: Icon(_iconFor(event), size: 18, color: color),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(when, style: TextStyle(fontSize: 11, color: muted)),
                    const SizedBox(height: 2),
                    Text(
                      event.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.description,
                      style: TextStyle(fontSize: 12, color: secondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.actorName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityVerifiedCard extends StatelessWidget {
  const _CommunityVerifiedCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final citizens = count == 1 ? '1 nearby citizen' : '$count nearby citizens';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.statusCompleted.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.statusCompleted),
      ),
      child: Column(
        children: [
          const Icon(Icons.groups_outlined, color: AppColors.statusCompleted),
          const SizedBox(height: 6),
          const Text(
            'Community Verified ✓',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.statusCompleted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$citizens confirmed this repair is complete.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Admin "Activity" tab: pick a report to inspect its history.
class ActivityHubView extends StatelessWidget {
  const ActivityHubView({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<DataRepository>();
    final reports = [...repository.reports]
      ..sort(
        (a, b) =>
            (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt),
      );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget body;
    if (repository.reportsLoading && reports.isEmpty) {
      body = const AppLoadingIndicator(message: 'Loading reports…');
    } else if (repository.reportsErrorMessage != null && reports.isEmpty) {
      body = AppErrorWidget(
        message: repository.reportsErrorMessage!,
        onRetry: repository.retryReportsSync,
      );
    } else if (reports.isEmpty) {
      body = const AppEmptyState(
        icon: Icons.history_rounded,
        title: 'No activity yet',
        description: 'Report activity will appear here once reports exist.',
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: reports.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final report = reports[index];
          final updated = NotificationFormatters.relativeTime(
            report.updatedAt ?? report.createdAt,
          );
          return Material(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => unawaited(
                Navigator.of(context).pushNamed(
                  AppRouter.reportActivity,
                  arguments: report.reportId,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.reportId,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryCyan,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${report.faultType.displayName} · ${report.address}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Updated $updated',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppStatusBadge(status: report.status),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Activity History')),
      body: body,
    );
  }
}
