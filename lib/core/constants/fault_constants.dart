import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The 5 core workflow statuses for water pipe fault reports in AquaTrace.
enum FaultStatus {
  pending,
  assigned,
  ongoing,
  completed,
  disputed;

  String get id => name;

  String get displayName {
    switch (this) {
      case FaultStatus.pending:
        return 'Pending';
      case FaultStatus.assigned:
        return 'Assigned';
      case FaultStatus.ongoing:
        return 'Ongoing';
      case FaultStatus.completed:
        return 'Completed';
      case FaultStatus.disputed:
        return 'Disputed';
    }
  }

  Color get color {
    switch (this) {
      case FaultStatus.pending:
        return AppColors.statusPending;
      case FaultStatus.assigned:
        return AppColors.statusAssigned;
      case FaultStatus.ongoing:
        return AppColors.statusOngoing;
      case FaultStatus.completed:
        return AppColors.statusCompleted;
      case FaultStatus.disputed:
        return AppColors.statusDisputed;
    }
  }

  Color getBackgroundColor(bool isDark) {
    switch (this) {
      case FaultStatus.pending:
        return isDark
            ? AppColors.statusPendingDarkBg
            : AppColors.statusPendingBg;
      case FaultStatus.assigned:
        return isDark
            ? AppColors.statusAssignedDarkBg
            : AppColors.statusAssignedBg;
      case FaultStatus.ongoing:
        return isDark
            ? AppColors.statusOngoingDarkBg
            : AppColors.statusOngoingBg;
      case FaultStatus.completed:
        return isDark
            ? AppColors.statusCompletedDarkBg
            : AppColors.statusCompletedBg;
      case FaultStatus.disputed:
        return isDark
            ? AppColors.statusDisputedDarkBg
            : AppColors.statusDisputedBg;
    }
  }

  IconData get icon {
    switch (this) {
      case FaultStatus.pending:
        return Icons.schedule_rounded;
      case FaultStatus.assigned:
        return Icons.assignment_ind_outlined;
      case FaultStatus.ongoing:
        return Icons.build_circle_outlined;
      case FaultStatus.completed:
        return Icons.check_circle_outline_rounded;
      case FaultStatus.disputed:
        return Icons.error_outline_rounded;
    }
  }

  static FaultStatus fromString(String? value) {
    if (value == null) return FaultStatus.pending;
    final normalized = value.trim().toLowerCase();
    for (final s in FaultStatus.values) {
      if (s.name == normalized || s.displayName.toLowerCase() == normalized) {
        return s;
      }
    }
    return FaultStatus.pending;
  }
}

/// Severity classification for faults.
enum FaultSeverity {
  low,
  medium,
  high,
  critical;

  String get id => name;

  String get displayName {
    switch (this) {
      case FaultSeverity.low:
        return 'Low';
      case FaultSeverity.medium:
        return 'Medium';
      case FaultSeverity.high:
        return 'High';
      case FaultSeverity.critical:
        return 'Critical';
    }
  }

  Color get color {
    switch (this) {
      case FaultSeverity.low:
        return AppColors.priorityLow;
      case FaultSeverity.medium:
        return AppColors.priorityMedium;
      case FaultSeverity.high:
        return AppColors.priorityHigh;
      case FaultSeverity.critical:
        return AppColors.priorityCritical;
    }
  }

  static FaultSeverity fromString(String? value) {
    if (value == null) return FaultSeverity.medium;
    final normalized = value.trim().toLowerCase();
    for (final s in FaultSeverity.values) {
      if (s.name == normalized || s.displayName.toLowerCase() == normalized) {
        return s;
      }
    }
    return FaultSeverity.medium;
  }
}

/// Categorized types of water infrastructure faults.
enum FaultType {
  pipeLeak,
  burstPipe,
  damagedPipe,
  roadWaterFlow,
  lowPressure,
  waterContamination,
  other;

  String get id => name;

  String get displayName {
    switch (this) {
      case FaultType.pipeLeak:
        return 'Pipe Leak';
      case FaultType.burstPipe:
        return 'Burst Pipe';
      case FaultType.damagedPipe:
        return 'Damaged Pipe';
      case FaultType.roadWaterFlow:
        return 'Road Water Flow';
      case FaultType.lowPressure:
        return 'Low Water Pressure';
      case FaultType.waterContamination:
        return 'Water Contamination';
      case FaultType.other:
        return 'Other Fault';
    }
  }

  IconData get icon {
    switch (this) {
      case FaultType.pipeLeak:
        return Icons.water_drop_outlined;
      case FaultType.burstPipe:
        return Icons.warning_amber_rounded;
      case FaultType.damagedPipe:
        return Icons.broken_image_outlined;
      case FaultType.roadWaterFlow:
        return Icons.waves_rounded;
      case FaultType.lowPressure:
        return Icons.speed_rounded;
      case FaultType.waterContamination:
        return Icons.science_outlined;
      case FaultType.other:
        return Icons.help_outline_rounded;
    }
  }

  static FaultType fromString(String? value) {
    if (value == null) return FaultType.pipeLeak;
    final normalized = value.trim().toLowerCase();
    for (final t in FaultType.values) {
      if (t.name.toLowerCase() == normalized ||
          t.displayName.toLowerCase() == normalized) {
        return t;
      }
    }
    return FaultType.pipeLeak;
  }
}
