import 'package:flutter/material.dart';

import '../constants/fault_constants.dart';

/// Renders a priority/severity badge pill.
class AppPriorityBadge extends StatelessWidget {
  final FaultSeverity severity;
  final bool isSolid;

  const AppPriorityBadge({
    super.key,
    required this.severity,
    this.isSolid = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = severity.color;

    if (isSolid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          severity.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        severity.displayName,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
