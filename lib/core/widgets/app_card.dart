import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Reusable card container with border and elevation conforming to the AquaTrace design system.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBg =
        backgroundColor ??
        (isDark ? AppColors.darkSurface : AppColors.lightSurface);
    final effectiveBorder =
        borderColor ?? (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    // Use Material (not a bare DecoratedBox/Container) so ListTile /
    // InkWell descendants have a Material ancestor for visible ink splashes.
    final card = Material(
      color: effectiveBg,
      elevation: isDark ? 0 : 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: BorderSide(color: effectiveBorder, width: 1.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );

    final wrapped = Padding(padding: margin, child: card);

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: wrapped,
        ),
      );
    }

    return wrapped;
  }
}
