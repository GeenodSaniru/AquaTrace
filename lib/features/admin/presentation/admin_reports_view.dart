import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_roles.dart';
import '../../../core/constants/fault_constants.dart';
import '../../../core/models/report_model.dart';
import '../../../core/services/data_repository.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_priority_badge.dart';
import '../../../core/widgets/app_report_card_tile.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../auth/providers/auth_provider.dart';

class AdminReportsView extends StatefulWidget {
  const AdminReportsView({super.key});

  @override
  State<AdminReportsView> createState() => _AdminReportsViewState();
}

class _AdminReportsViewState extends State<AdminReportsView> {
  final _searchController = TextEditingController();
  FaultStatus? _status;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.currentRole != UserRole.admin) {
      return const Scaffold(
        body: Center(child: Text('Administrator access is required.')),
      );
    }

    final reports = context
        .watch<DataRepository>()
        .reports
        .where(_matches)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Report Review')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search ID, address, reporter or fault type',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              scrollDirection: Axis.horizontal,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _status == null,
                  onSelected: (_) => setState(() => _status = null),
                ),
                ...FaultStatus.values.map(
                  (status) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FilterChip(
                      label: Text(status.displayName),
                      selected: _status == status,
                      onSelected: (_) => setState(() => _status = status),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _error = null),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          Expanded(
            child: reports.isEmpty
                ? const AppEmptyState(
                    title: 'No matching reports',
                    description: 'Try another status or search term.',
                  )
                : RefreshIndicator(
                    onRefresh: () async => setState(() {}),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: reports.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) => AppReportCardTile(
                        report: reports[index],
                        onTap: () => _showDetails(reports[index]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  bool _matches(ReportModel report) {
    if (_status != null && report.status != _status) return false;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return '${report.reportId} ${report.address} ${report.reporterName} ${report.faultType.displayName}'
        .toLowerCase()
        .contains(query);
  }

  Future<void> _showDetails(ReportModel report) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ReportReviewSheet(
        report: report,
        onError: (message) => setState(() => _error = message),
      ),
    );
  }
}

class _ReportReviewSheet extends StatefulWidget {
  final ReportModel report;
  final ValueChanged<String> onError;

  const _ReportReviewSheet({required this.report, required this.onError});

  @override
  State<_ReportReviewSheet> createState() => _ReportReviewSheetState();
}

class _ReportReviewSheetState extends State<_ReportReviewSheet> {
  bool _saving = false;

  Future<void> _requestCorrection() async {
    await _run(() async {
      final admin = context.read<AuthProvider>().currentUser!;
      await context.read<DataRepository>().updateReportStatus(
        reportId: widget.report.reportId,
        newStatus: FaultStatus.pending,
        actorName: admin.displayName,
        actorRole: 'Admin',
        note: 'Correction requested before approval.',
      );
    });
  }

  Future<void> _assign() async {
    final repo = context.read<DataRepository>();
    final technicians = <String, String>{};
    for (final report in repo.reports) {
      if (report.assignedTechnicianUid != null &&
          report.assignedTechnicianName != null) {
        technicians[report.assignedTechnicianUid!] =
            report.assignedTechnicianName!;
      }
    }
    if (technicians.isEmpty) {
      widget.onError('No technician records are available for assignment.');
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Assign technician'),
        children: technicians.entries
            .map(
              (entry) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, entry.key),
                child: Text(entry.value),
              ),
            )
            .toList(),
      ),
    );
    if (selected == null || !mounted) return;
    await _run(() async {
      final admin = context.read<AuthProvider>().currentUser!;
      await repo.assignTechnician(
        reportId: widget.report.reportId,
        technicianUid: selected,
        technicianName: technicians[selected]!,
        adminName: admin.displayName,
      );
    });
  }

  Future<void> _changeSeverity(FaultSeverity severity) async {
    await _run(() async {
      final admin = context.read<AuthProvider>().currentUser!;
      await context.read<DataRepository>().updateReportSeverity(
        reportId: widget.report.reportId,
        severity: severity,
        adminName: admin.displayName,
      );
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _saving = true);
    try {
      await action();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      widget.onError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report =
        context.watch<DataRepository>().getReportById(widget.report.reportId) ??
        widget.report;
    final timeline = context
        .watch<DataRepository>()
        .getTimelineForReport(report.reportId)
        .reversed;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  report.reportId,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.teal,
                  ),
                ),
                AppStatusBadge(status: report.status),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              report.faultType.displayName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(report.address),
            const SizedBox(height: 8),
            Row(
              children: [
                AppPriorityBadge(severity: report.severity),
                const SizedBox(width: 10),
                Text(DateFormat.yMMMd().add_jm().format(report.createdAt)),
              ],
            ),
            const SizedBox(height: 16),
            Text(report.description),
            const SizedBox(height: 12),
            Text('Reported by ${report.reporterName}'),
            if (report.beforeImageUrl != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  report.beforeImageUrl!,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 80,
                    child: Center(child: Text('Evidence unavailable')),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            DropdownButtonFormField<FaultSeverity>(
              initialValue: report.severity,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: FaultSeverity.values
                  .map(
                    (severity) => DropdownMenuItem(
                      value: severity,
                      child: Text(severity.displayName),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => value == null ? null : _changeSeverity(value),
            ),
            if (report.status == FaultStatus.pending ||
                report.status == FaultStatus.disputed) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _saving ? null : _assign,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Approve and assign'),
              ),
              OutlinedButton.icon(
                onPressed: _saving ? null : _requestCorrection,
                icon: const Icon(Icons.edit_note),
                label: const Text('Request correction'),
              ),
            ],
            const SizedBox(height: 18),
            const Text(
              'Activity history',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (timeline.isEmpty)
              const Text('No activity has been recorded yet.'),
            ...timeline.map(
              (event) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 16,
                  child: Icon(event.status.icon, size: 16),
                ),
                title: Text(event.title),
                subtitle: Text(
                  '${event.description}\n${DateFormat.yMMMd().add_jm().format(event.timestamp)}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
