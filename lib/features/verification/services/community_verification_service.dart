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
class CommunityVerificationService {
  /// Default radius in kilometers within which citizens can verify completed repairs.
  static const double defaultRadiusKm = 5.0;

  /// Required number of community confirmations to reach "Community Verified" milestone.
  static const int confirmationThreshold = 3;

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
    double radiusKm = defaultRadiusKm,
  }) {
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

    final isWithinRadius = distanceKm <= radiusKm;
    if (!isWithinRadius) {
      final formattedDist = distanceKm.toStringAsFixed(1);
      final formattedMax = radiusKm.toStringAsFixed(0);
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
