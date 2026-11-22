import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_roles.dart';
import '../../../core/constants/fault_constants.dart';
import '../../../core/models/notification_item.dart';
import '../../../core/services/data_repository.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../../technician/presentation/technician_job_detail_screen.dart';
import '../../verification/presentation/citizen_verification_screen.dart';
import '../services/push_messaging_service.dart';
import 'activity_history_screen.dart';

/// Arguments for the `/reports/detail` route.
///
/// [type] is the kind of notification that led here (if known); it lets a
/// "Verify Repair" request open the community verification screen.
class ReportLinkArgs {
  const ReportLinkArgs(this.reportId, {this.type});

  final String reportId;
  final NotificationType? type;
}

/// Destination for notification taps and push deep links.
///
/// Resolves the report **from the signed-in user's own data**, so a link can
/// never reveal a report the user is not allowed to read:
/// * the assigned technician is taken to the job detail screen;
/// * a nearby citizen opening a *verification* notification for a completed
///   repair is taken to the community verification screen (which re-checks
///   eligibility itself);
/// * everyone else sees the report's activity history.
/// Unknown, deleted or inaccessible reports show a clear "unavailable" state.
class ReportLinkScreen extends StatefulWidget {
  const ReportLinkScreen({
    super.key,
    required this.reportId,
    this.type,
    this.loadGrace = const Duration(seconds: 3),
  });

  final String reportId;

  /// Notification type that triggered the link, if known.
  final NotificationType? type;

  /// How long to wait for the live report list before declaring the report
  /// unavailable (reports stream in after sign-in).
  final Duration loadGrace;

  @override
  State<ReportLinkScreen> createState() => _ReportLinkScreenState();
}

class _ReportLinkScreenState extends State<ReportLinkScreen> {
  Timer? _graceTimer;
  bool _graceOver = false;

  @override
  void initState() {
    super.initState();
    _graceTimer = Timer(widget.loadGrace, () {
      if (mounted) setState(() => _graceOver = true);
    });
  }

  @override
  void dispose() {
    _graceTimer?.cancel();
    super.dispose();
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: AppEmptyState(icon: icon, title: title, description: description),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final repository = context.watch<DataRepository>();

    final reportId = sanitizeReportId(widget.reportId);
    if (reportId == null) {
      return _message(
        icon: Icons.link_off_rounded,
        title: 'Report unavailable',
        description: 'This link does not point to a valid report.',
      );
    }
    if (!auth.isAuthenticated) {
      return _message(
        icon: Icons.lock_outline_rounded,
        title: 'Sign in required',
        description: 'Sign in to view this report.',
      );
    }

    final report = repository.getReportById(reportId);
    if (report != null) {
      final isAssignedTechnician =
          auth.currentRole == UserRole.technician &&
          report.assignedTechnicianUid == auth.currentUser?.uid;
      if (isAssignedTechnician) {
        return TechnicianJobDetailScreen(report: report);
      }
      final userUid = auth.currentUser?.uid;
      final canBeAskedToVerify =
          widget.type == NotificationType.verification &&
          auth.currentRole == UserRole.citizen &&
          report.status == FaultStatus.completed &&
          report.reporterUid != userUid &&
          report.assignedTechnicianUid != userUid;
      return canBeAskedToVerify
          ? CitizenVerificationScreen(reportId: report.reportId)
          : ActivityHistoryScreen(reportId: report.reportId);
    }

    if (repository.reportsLoading || !_graceOver) {
      return Scaffold(
        appBar: AppBar(title: const Text('Report')),
        body: const AppLoadingIndicator(message: 'Opening report…'),
      );
    }
    return _message(
      icon: Icons.report_gmailerrorred_outlined,
      title: 'Report unavailable',
      description:
          'This report may have been removed, or you may not have access to '
          'it.',
    );
  }
}
