import 'dart:math' as math;

import '../../../core/constants/app_roles.dart';
import '../../../core/constants/fault_constants.dart';
import '../../../core/models/report_model.dart';
import '../../../core/models/user_model.dart';

/// Result of evaluating a citizen's eligibility to verify or dispute a completed repair.
class VerificationEligibility {
  final bool isEligible;
  final String? reason;
  final double distanceKm;
  final bool isWithinRadius;
  final bool hasAlreadyVoted;

  const VerificationEligibility({
    required this.isEligible,
    this.reason,
    required this.distanceKm,
    required this.isWithinRadius,
    required this.hasAlreadyVoted,
  });
}

/// Core domain logic and validation rules for Community Repair Verification.
///
/// **Verification & Dispute Assumptions:**
/// 1. Proximity Radius (default: 5.0 km):
///    Citizens must be within this geographic radius of the reported pipe coordinates
///    to audit or dispute. In Sri Lanka municipal contexts (e.g. Colombo Municipal Council),
///    5.0 km covers the neighborhood and contiguous water distribution segment.
/// 2. Verification Threshold (default: 3 confirmations):
///    A completed repair is marked "Community Verified" once 3 independent citizens
///    confirm resolution.
/// 3. Conflict of Interest:
///    The original reporter and the assigned technician cannot submit community audit votes.
/// 4. Lifecycle Reopening:
///    A community dispute automatically reopens the report to [FaultStatus.disputed],
///    creates an audit timeline event, and notifies admin, technician, and reporter workflows.
class CommunityVerificationService {
  static double _configuredRadiusKm = 5.0;
  static int _configuredThreshold = 3;

  /// Default radius in kilometers within which citizens can verify completed repairs.
  static double get defaultRadiusKm => _configuredRadiusKm;

  /// Required number of community confirmations to reach "Community Verified" milestone.
  static int get confirmationThreshold => _configuredThreshold;

  /// Allows runtime configuration of verification assumptions (e.g., from settings or tests).
  static void configure({double? radiusKm, int? threshold}) {
    if (radiusKm != null && radiusKm > 0) _configuredRadiusKm = radiusKm;
    if (threshold != null && threshold > 0) _configuredThreshold = threshold;
  }

  /// Resets verification parameters to project defaults (5.0 km radius, 3 confirmations threshold).
  static void resetDefaults() {
    _configuredRadiusKm = 5.0;
    _configuredThreshold = 3;
  }

  /// Calculates the great-circle distance between two GPS coordinates using the Haversine formula.
  static double calculateDistanceKm({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    const earthRadiusKm = 6371.0;

    final dLat = _degreesToRadians(endLatitude - startLatitude);
    final dLon = _degreesToRadians(endLongitude - startLongitude);

    final lat1Rad = _degreesToRadians(startLatitude);
    final lat2Rad = _degreesToRadians(endLatitude);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) *
            math.sin(dLon / 2) *
            math.cos(lat1Rad) *
            math.cos(lat2Rad);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

  /// Evaluates whether [user] is eligible to verify or dispute [report].
  static VerificationEligibility checkEligibility({
    required ReportModel report,
    required UserModel? user,
    required double? userLatitude,
    required double? userLongitude,
    required bool hasAlreadyVoted,
    double? radiusKm,
  }) {
    final effectiveRadiusKm = radiusKm ?? defaultRadiusKm;
    if (user == null) {
      return const VerificationEligibility(
        isEligible: false,
        reason: 'You must be signed in to verify repairs.',
        distanceKm: -1,
        isWithinRadius: false,
        hasAlreadyVoted: false,
      );
    }

    if (user.role != UserRole.citizen) {
      return const VerificationEligibility(
        isEligible: false,
        reason:
            'Only community citizens can participate in repair verification.',
        distanceKm: -1,
        isWithinRadius: false,
        hasAlreadyVoted: false,
      );
    }

    // Rule: Prevent the original reporter from verifying their own report
    if (report.reporterUid.trim() == user.uid.trim()) {
      return const VerificationEligibility(
        isEligible: false,
        reason: 'As the original reporter, you cannot submit community verification votes.',
        distanceKm: -1,
        isWithinRadius: false,
        hasAlreadyVoted: false,
      );
    }

    // Rule: Prevent the assigned technician from verifying their own repair
    if (report.assignedTechnicianUid != null &&
        report.assignedTechnicianUid!.trim() == user.uid.trim()) {
      return const VerificationEligibility(
        isEligible: false,
        reason:
            'Field technicians cannot audit or verify their own repair work.',
        distanceKm: -1,
        isWithinRadius: false,
        hasAlreadyVoted: false,
      );
    }

    // Rule: Report must be in completed status (or disputed for viewing)
    if (report.status != FaultStatus.completed) {
      return VerificationEligibility(
        isEligible: false,
        reason: 'Only repairs marked as completed can be verified by the community.',
        distanceKm: -1,
        isWithinRadius: false,
        hasAlreadyVoted: hasAlreadyVoted,
      );
    }

    // Rule: Duplicate voting check
    if (hasAlreadyVoted) {
      return const VerificationEligibility(
        isEligible: false,
        reason: 'You have already submitted your response for this repair.',
        distanceKm: -1,
        isWithinRadius: false,
        hasAlreadyVoted: true,
      );
    }

    // Distance verification
    if (userLatitude == null || userLongitude == null) {
      return const VerificationEligibility(
        isEligible: false,
        reason: 'Location access is required to confirm proximity to the repair site.',
        distanceKm: -1,
        isWithinRadius: false,
        hasAlreadyVoted: false,
      );
    }

    final distanceKm = calculateDistanceKm(
      startLatitude: userLatitude,
      startLongitude: userLongitude,
      endLatitude: report.latitude,
      endLongitude: report.longitude,
    );

    final isWithinRadius = distanceKm <= effectiveRadiusKm;
    if (!isWithinRadius) {
      final formattedDist = distanceKm.toStringAsFixed(1);
      final formattedMax = effectiveRadiusKm.toStringAsFixed(0);
      return VerificationEligibility(
        isEligible: false,
        reason:
            'You are $formattedDist km away. Verification is only allowed within $formattedMax km.',
        distanceKm: distanceKm,
        isWithinRadius: false,
        hasAlreadyVoted: false,
      );
    }

    return VerificationEligibility(
      isEligible: true,
      distanceKm: distanceKm,
      isWithinRadius: true,
      hasAlreadyVoted: false,
    );
  }
}
