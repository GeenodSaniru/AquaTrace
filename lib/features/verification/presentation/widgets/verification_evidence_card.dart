import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Interactive card presenting before and after repair photographic evidence.
class VerificationEvidenceCard extends StatefulWidget {
  final String? beforeImageUrl;
  final String? afterImageUrl;
  final String? repairNotes;

  const VerificationEvidenceCard({
    super.key,
    this.beforeImageUrl,
    this.afterImageUrl,
    this.repairNotes,
  });

  @override
  State<VerificationEvidenceCard> createState() =>
      _VerificationEvidenceCardState();
}

class _VerificationEvidenceCardState extends State<VerificationEvidenceCard> {
  int _selectedTabIndex = 1; // Default to After photo to inspect the repair

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentPhotoUrl = _selectedTabIndex == 0
        ? widget.beforeImageUrl
        : widget.afterImageUrl;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Repair Evidence',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkBackground
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    _buildTabButton('Before', 0, isDark),
                    _buildTabButton('After Repair', 1, isDark),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 200,
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              child: currentPhotoUrl != null && currentPhotoUrl.isNotEmpty
                  ? Image.network(
                      currentPhotoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _buildPlaceholder(
                        isDark,
                        icon: Icons.broken_image_outlined,
                        label: 'Photo evidence failed to load',
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      },
                    )
                  : _buildPlaceholder(
                      isDark,
                      icon: _selectedTabIndex == 0
                          ? Icons.camera_alt_outlined
                          : Icons.verified_outlined,
                      label: _selectedTabIndex == 0
                          ? 'No initial leak photo uploaded'
                          : 'No after-repair photo uploaded yet',
                    ),
            ),
          ),
          if (widget.repairNotes != null &&
              widget.repairNotes!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkBackground.withValues(alpha: 0.6)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkBorder
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.engineering_outlined,
                        size: 16,
                        color: isDark
                            ? AppColors.primaryCyan
                            : AppColors.primaryNavy,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Technician Completion Notes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.repairNotes!.trim(),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index, bool isDark) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.primaryCyan : AppColors.primaryNavy)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (isDark ? AppColors.primaryNavy : Colors.white)
                : (isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(
    bool isDark, {
    required IconData icon,
    required String label,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 36,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
