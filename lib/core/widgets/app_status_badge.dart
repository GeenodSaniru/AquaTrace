import 'package:flutter/material.dart';

import '../constants/fault_constants.dart';

/// Renders a status badge pill matching the AquaTrace UI Figma specification.
class AppStatusBadge extends StatelessWidget {
  final FaultStatus status;
  final bool showDot;
  final double fontSize;

  const AppStatusBadge({
    super.key,
    required this.status,
    this.showDot = false,
    this.fontSize = 11.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = status.color;
    final bgColor = status.getBackgroundColor(isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            status.displayName,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
