import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/fault_constants.dart';
import '../../../core/models/report_model.dart';
import '../../../core/services/data_repository.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_priority_badge.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/community_verification_service.dart';
import 'widgets/verification_dialogs.dart';
import 'widgets/verification_evidence_card.dart';

/// Screen allowing nearby citizens to inspect completed repairs, verify resolution,
/// or raise disputes to reopen cases for Water Board review.
class CitizenVerificationScreen extends StatefulWidget {
  final String reportId;
  final double? initialLatitude;
  final double? initialLongitude;

  const CitizenVerificationScreen({
    super.key,
    required this.reportId,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<CitizenVerificationScreen> createState() =>
      _CitizenVerificationScreenState();
}

class _CitizenVerificationScreenState extends State<CitizenVerificationScreen> {
  double? _userLatitude;
  double? _userLongitude;
  bool _isLoadingLocation = true;
  String? _locationStatusMessage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _userLatitude = widget.initialLatitude;
      _userLongitude = widget.initialLongitude;
      _isLoadingLocation = false;
    } else {
      _resolveUserLocation();
    }
  }

  Future<void> _resolveUserLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationStatusMessage = 'Acquiring GPS location...';
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _clearLocation(
          'Location services are off. Turn on GPS to verify nearby repairs.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _clearLocation(
            'Location permission denied. Allow location access to verify nearby repairs.',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _clearLocation(
          'Location permanently denied. Enable location in settings to verify nearby repairs.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );

      if (mounted) {
        setState(() {
          _userLatitude = position.latitude;
          _userLongitude = position.longitude;
          _isLoadingLocation = false;
          _locationStatusMessage = null;
        });
      }
    } catch (_) {
      _clearLocation(
        'GPS unavailable. Move closer with location enabled to verify or dispute.',
      );
    }
  }

  void _clearLocation(String reason) {
    if (!mounted) return;
    // Fail closed: never invent coordinates that would bypass proximity checks.
    setState(() {
      _userLatitude = null;
      _userLongitude = null;
      _isLoadingLocation = false;
      _locationStatusMessage = reason;
    });
  }

  Future<void> _handleConfirmResolution(
    ReportModel report,
    DataRepository dataRepo,
  ) async {
    final note = await showConfirmResolutionSheet(
      context: context,
      reportId: report.reportId,
    );

    if (note == null || !mounted) return; // Dismissed

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);
    try {
      await dataRepo.submitCommunityVerification(
        report: report,
        voter: user,
        note: note.isNotEmpty ? note : null,
        userLatitude: _userLatitude,
        userLongitude: _userLongitude,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your verification has been recorded.'),
            backgroundColor: AppColors.statusCompleted,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: $e'),
            backgroundColor: AppColors.statusDisputed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleRaiseDispute(
    ReportModel report,
    DataRepository dataRepo,
  ) async {
    final input = await showRaiseDisputeSheet(
      context: context,
      reportId: report.reportId,
    );

    if (input == null || !mounted) return; // Dismissed

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);
    try {
      await dataRepo.submitCommunityDispute(
        report: report,
        voter: user,
        reason: input.reason,
        evidenceBytes: input.evidenceBytes,
        contentType: input.evidenceContentType,
        userLatitude: _userLatitude,
        userLongitude: _userLongitude,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Dispute submitted. Report ${report.reportId} reopened for inspection.',
            ),
            backgroundColor: AppColors.statusDisputed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dispute submission failed: $e'),
            backgroundColor: AppColors.statusDisputed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataRepo = Provider.of<DataRepository>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final report = dataRepo.getReportById(widget.reportId);
    if (report == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Verify Repair')),
        body: const AppEmptyState(
          icon: Icons.search_off_rounded,
          title: 'Report Not Found',
          description:
              'The requested repair report does not exist or has been removed.',
        ),
      );
    }

    final hasVoted =
        user != null &&
        dataRepo.hasUserVotedOnReport(
          reportId: report.reportId,
          userUid: user.uid,
        );

    final eligibility = CommunityVerificationService.checkEligibility(
      report: report,
      user: user,
      userLatitude: _userLatitude,
      userLongitude: _userLongitude,
      hasAlreadyVoted: hasVoted,
    );

    final verifications = dataRepo.getVerificationsForReport(report.reportId);
    final disputes = dataRepo.getDisputesForReport(report.reportId);
    final dateStr = DateFormat('MMM dd, yyyy · h:mm a')
        .format(report.createdAt);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Community Verification',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              report.reportId,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF93C5FD),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Overview Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        report.reportId,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryCyan,
                        ),
                      ),
                      AppStatusBadge(status: report.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    report.faultType.displayName,
                    style: const TextStyle(
                      fontSize: 19,
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
                  const SizedBox(height: 10),
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
                  if (report.assignedTechnicianName != null) ...[
                    const Divider(height: 20),
                    Row(
                      children: [
                        const Icon(
                          Icons.handyman_outlined,
                          size: 15,
                          color: AppColors.primaryCyan,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Technician: ${report.assignedTechnicianName}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Location & Proximity Pill
            _buildProximityBanner(eligibility, isDark),
            const SizedBox(height: 16),

            // Before / After Photographic Evidence Card
            VerificationEvidenceCard(
              beforeImageUrl: report.beforeImageUrl,
              afterImageUrl: report.afterImageUrl,
              repairNotes: report.repairNotes,
            ),
            const SizedBox(height: 16),

            // Community Verification Progress Card
            _buildAuditProgressCard(report, verifications, disputes, isDark),
            const SizedBox(height: 20),

            // Action / Eligibility Section
            if (_isSubmitting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (hasVoted)
              _buildVotedBanner(isDark)
            else if (!eligibility.isEligible)
              _buildIneligibleBanner(eligibility.reason ?? '', isDark)
            else
              _buildActionButtons(report, dataRepo),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProximityBanner(
    VerificationEligibility eligibility,
    bool isDark,
  ) {
    if (_isLoadingLocation) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              'Determining distance to repair site...',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      );
    }

    final isWithin = eligibility.isWithinRadius;
    final distStr = eligibility.distanceKm >= 0
        ? '${eligibility.distanceKm.toStringAsFixed(1)} km away'
        : 'Unknown distance';

    final color = isWithin
        ? AppColors.statusCompleted
        : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWithin ? Icons.near_me_rounded : Icons.location_off_outlined,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWithin
                      ? 'Within Verification Zone ($distStr)'
                      : 'Outside Verification Radius ($distStr)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isWithin
                      ? 'You are within the 5 km community radius to audit this repair.'
                      : 'Only residents within 5 km of the repair site may confirm or dispute.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                if (_locationStatusMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _locationStatusMessage!,
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 16),
            tooltip: 'Refresh location',
            onPressed: _resolveUserLocation,
          ),
        ],
      ),
    );
  }

  Widget _buildAuditProgressCard(
    ReportModel report,
    List verifications,
    List disputes,
    bool isDark,
  ) {
    final threshold = CommunityVerificationService.confirmationThreshold;
    final isVerified = report.verificationCount >= threshold;
    final progress = (report.verificationCount / threshold).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Community Verification Audit',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isVerified
                      ? AppColors.statusCompleted.withValues(alpha: 0.15)
                      : (isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${report.verificationCount} / $threshold Confirmed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isVerified
                        ? AppColors.statusCompleted
                        : (isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                isVerified ? AppColors.statusCompleted : AppColors.primaryCyan,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (isVerified)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.statusCompleted.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.statusCompleted.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.verified_rounded,
                    color: AppColors.statusCompleted,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Community Verified ✓ — 3 nearby citizens confirmed this repair is complete.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.statusCompleted,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (report.status == FaultStatus.disputed)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.statusDisputed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.statusDisputed.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.statusDisputed,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Status: Disputed (${report.disputeCount} dispute${report.disputeCount > 1 ? 's' : ''} recorded). Awaiting Water Board inspection.',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.statusDisputed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (verifications.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Resident Confirmations',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ...verifications.map(
              (v) => Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check,
                      size: 14,
                      color: AppColors.statusCompleted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${v.voterName}${v.note != null && v.note!.isNotEmpty ? ': "${v.note}"' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVotedBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryNavy.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryNavy.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: AppColors.primaryNavy,
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'You have already submitted your response for this repair. Thank you for keeping your community infrastructure monitored!',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIneligibleBanner(String reason, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 18,
            color: AppColors.lightTextMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              reason,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ReportModel report, DataRepository dataRepo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          label: 'Confirm Repair Resolution',
          backgroundColor: AppColors.statusCompleted,
          onPressed: () => _handleConfirmResolution(report, dataRepo),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: AppColors.statusDisputed,
          ),
          label: const Text(
            'Raise Dispute (Report Ongoing Issue)',
            style: TextStyle(
              color: AppColors.statusDisputed,
              fontWeight: FontWeight.w700,
            ),
          ),
          onPressed: () => _handleRaiseDispute(report, dataRepo),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.statusDisputed),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}
