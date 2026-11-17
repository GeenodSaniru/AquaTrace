import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/fault_constants.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/models/report_model.dart';
import '../../../core/services/data_repository.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_priority_badge.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../auth/providers/auth_provider.dart';

class TechnicianJobDetailScreen extends StatefulWidget {
  final ReportModel report;
  final VoidCallback? onNavigate;

  const TechnicianJobDetailScreen({
    super.key,
    required this.report,
    this.onNavigate,
  });

  @override
  State<TechnicianJobDetailScreen> createState() =>
      _TechnicianJobDetailScreenState();
}

class _TechnicianJobDetailScreenState extends State<TechnicianJobDetailScreen> {
  late ReportModel _report;
  late final TextEditingController _notesController;
  final FocusNode _notesFocusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isSaving = false;
  bool _isPickingPhoto = false;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
    _notesController = TextEditingController(text: _report.repairNotes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authUser = context.watch<AuthProvider>().currentUser;
    final currentReport = context.watch<DataRepository>().getReportById(
      _report.reportId,
    );
    final report = currentReport;
    final isAssignedToCurrentUser =
        authUser?.uid.isNotEmpty == true &&
        report?.assignedTechnicianUid == authUser!.uid;

    if (report == null || !isAssignedToCurrentUser) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job Details')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This job is no longer assigned to your technician account.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        actions: [
          if (widget.onNavigate != null)
            IconButton(
              tooltip: 'Open map',
              icon: const Icon(Icons.navigation_rounded),
              onPressed: widget.onNavigate,
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
                if (widget.onNavigate != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: widget.onNavigate,
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
          _buildActionCard(context, report),
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
                ...context
                    .read<DataRepository>()
                    .getTimelineForReport(report.reportId)
                    .map(
                      (event) => _HistoryRow(
                        label: event.title,
                        value: _formatDate(event.timestamp),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, ReportModel report) {
    final isAssigned = report.status == FaultStatus.assigned;
    final isOngoing = report.status == FaultStatus.ongoing;
    if (!isAssigned && !isOngoing) {
      return const SizedBox.shrink();
    }

    return _DetailCard(
      title: 'Technician actions',
      icon: Icons.build_circle_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isAssigned)
            AppButton(
              label: 'Accept & Start Job',
              icon: Icons.play_arrow_rounded,
              isLoading: _isSaving,
              onPressed: _startJob,
            ),
          if (isOngoing) ...[
            TextField(
              controller: _notesController,
              focusNode: _notesFocusNode,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Repair notes',
                hintText: 'Describe the repair work and materials used.',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _saveNotes,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save repair notes'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isPickingPhoto || _isSaving ? null : _pickAfterPhoto,
              icon: _isPickingPhoto
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_a_photo_outlined),
              label: Text(
                report.afterImageUrl == null
                    ? 'Upload after-repair photo'
                    : 'Replace after-repair photo',
              ),
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Mark Job Completed',
              icon: Icons.check_circle_outline_rounded,
              isLoading: _isSaving,
              onPressed: report.afterImageUrl == null ? null : _completeJob,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _startJob() async {
    await _runAction(() async {
      await _updateStatus(FaultStatus.ongoing);
    });
  }

  Future<void> _completeJob() async {
    await _runAction(() async {
      await _updateStatus(
        FaultStatus.completed,
        note: _notesController.text.trim(),
      );
    });
  }

  Future<void> _saveNotes() async {
    await _runAction(() async {
      final auth = context.read<AuthProvider>().currentUser;
      await context.read<DataRepository>().saveTechnicianRepairNotes(
        reportId: _report.reportId,
        technicianUid: auth?.uid ?? '',
        actorName: auth?.displayName ?? 'Technician',
        notes: _notesController.text,
      );
      _refreshReport();
    });
  }

  Future<void> _updateStatus(FaultStatus status, {String? note}) async {
    final auth = context.read<AuthProvider>().currentUser;
    await context.read<DataRepository>().updateTechnicianJobStatus(
      reportId: _report.reportId,
      technicianUid: auth?.uid ?? '',
      actorName: auth?.displayName ?? 'Technician',
      newStatus: status,
      note: note,
    );
    _refreshReport();
  }

  Future<void> _pickAfterPhoto() async {
    setState(() => _isPickingPhoto = true);
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        imageQuality: 88,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final contentType = _contentTypeFor(image.name);
      if (contentType == null) {
        throw const FormatException('Choose a JPEG, PNG, WebP, or HEIC image.');
      }
      if (!mounted) return;
      final auth = context.read<AuthProvider>().currentUser;
      final repository = context.read<DataRepository>();
      await repository.uploadTechnicianAfterRepairPhoto(
        reportId: _report.reportId,
        technicianUid: auth?.uid ?? '',
        bytes: bytes,
        contentType: contentType,
      );
      _refreshReport();
      if (mounted) _showMessage('After-repair photo uploaded.');
    } catch (error, stackTrace) {
      ErrorHandler.logError(error, stackTrace);
      _showMessage(ErrorHandler.getUserMessage(error), isError: true);
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await action();
      if (mounted) _showMessage('Job updated.');
    } catch (error, stackTrace) {
      ErrorHandler.logError(error, stackTrace);
      if (mounted) {
        _showMessage(ErrorHandler.getUserMessage(error), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _refreshReport() {
    final current = context.read<DataRepository>().getReportById(
      _report.reportId,
    );
    if (current != null && mounted) {
      setState(() {
        _report = current;
        if (!_notesFocusNode.hasFocus) {
          _notesController.text = current.repairNotes ?? '';
        }
      });
    }
  }

  String? _contentTypeFor(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      _ => null,
    };
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
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
