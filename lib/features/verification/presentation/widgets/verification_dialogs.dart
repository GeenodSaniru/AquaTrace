import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';

/// Bottom sheet dialog allowing an eligible citizen to confirm repair resolution.
Future<String?> showConfirmResolutionSheet({
  required BuildContext context,
  required String reportId,
}) async {
  final noteController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;

      return Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.statusCompleted.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.statusCompleted,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Confirm Repair Resolution',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'By confirming, you verify as a community resident that the water leak or pipe issue at $reportId is properly fixed.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Verification Note (Optional)',
                  hintText:
                      'e.g. Water flow stopped, road surface dry and restored.',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'Confirm Repair Resolution',
                backgroundColor: AppColors.statusCompleted,
                onPressed: () {
                  Navigator.of(ctx).pop(noteController.text.trim());
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Data class holding dispute submission inputs.
class DisputeSubmissionInput {
  final String reason;
  final String details;
  final Uint8List? evidenceBytes;
  final String? evidenceContentType;

  const DisputeSubmissionInput({
    required this.reason,
    required this.details,
    this.evidenceBytes,
    this.evidenceContentType,
  });
}

/// Bottom sheet allowing a citizen to raise a dispute with reason and evidence photo.
Future<DisputeSubmissionInput?> showRaiseDisputeSheet({
  required BuildContext context,
  required String reportId,
}) async {
  return showModalBottomSheet<DisputeSubmissionInput>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _DisputeSheetContent(reportId: reportId),
  );
}

class _DisputeSheetContent extends StatefulWidget {
  final String reportId;

  const _DisputeSheetContent({required this.reportId});

  @override
  State<_DisputeSheetContent> createState() => _DisputeSheetContentState();
}

class _DisputeSheetContentState extends State<_DisputeSheetContent> {
  final _formKey = GlobalKey<FormState>();
  final _detailsController = TextEditingController();
  final _picker = ImagePicker();

  final List<String> _commonReasons = [
    'Water leak is still ongoing',
    'Incomplete or shoddy repair work',
    'Road/pavement left excavated or damaged',
    'Water pressure remains abnormal or dirty',
    'Other municipal pipe fault issue',
  ];

  late String _selectedReason;
  Uint8List? _pickedPhotoBytes;
  String? _pickedContentType;
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    _selectedReason = _commonReasons.first;
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _pickEvidence() async {
    setState(() => _isPicking = true);
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        final ext = photo.name.split('.').last.toLowerCase();
        final contentType = switch (ext) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          _ => 'image/jpeg',
        };
        setState(() {
          _pickedPhotoBytes = bytes;
          _pickedContentType = contentType;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not access image: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.statusDisputed.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.statusDisputed,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Raise Repair Dispute',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.statusDisputed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.statusDisputed.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.statusDisputed,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Submitting a dispute immediately reopens ${widget.reportId} to "Disputed" status for Water Board investigation.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.statusDisputed,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Dispute Reason',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedReason,
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                items: _commonReasons
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(r, style: const TextStyle(fontSize: 13)),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedReason = val);
                },
              ),
              const SizedBox(height: 14),
              const Text(
                'Additional Details (Required)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _detailsController,
                maxLines: 3,
                validator: (val) {
                  if (val == null || val.trim().length < 5) {
                    return 'Please provide at least 5 characters explaining the issue.';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'Describe why this repair is unresolved or what issues remain...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Photo Evidence (Recommended)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (_pickedPhotoBytes != null) ...[
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _pickedPhotoBytes!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    IconButton(
                      icon: const CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                      onPressed: () {
                        setState(() {
                          _pickedPhotoBytes = null;
                          _pickedContentType = null;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ] else ...[
                OutlinedButton.icon(
                  icon: _isPicking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: const Text('Attach Evidence Photo'),
                  onPressed: _isPicking ? null : _pickEvidence,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              AppButton(
                label: 'Submit Dispute to Water Board',
                backgroundColor: AppColors.statusDisputed,
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    final combinedReason =
                        '$_selectedReason: ${_detailsController.text.trim()}';
                    Navigator.of(context).pop(
                      DisputeSubmissionInput(
                        reason: combinedReason,
                        details: _detailsController.text.trim(),
                        evidenceBytes: _pickedPhotoBytes,
                        evidenceContentType: _pickedContentType,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
