import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/notification_item.dart';
import '../../../core/services/data_repository.dart';
import '../../../core/widgets/app_empty_state.dart';

/// Notifications list screen matching the Figma prototype.
class SharedNotificationsView extends StatelessWidget {
  const SharedNotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final dataRepo = Provider.of<DataRepository>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final unread = dataRepo.notifications.where((n) => !n.isRead).toList();
    final read = dataRepo.notifications.where((n) => n.isRead).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread.isNotEmpty)
            TextButton(
              onPressed: () => dataRepo.markAllNotificationsAsRead(),
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: dataRepo.notifications.isEmpty
          ? const AppEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No Notifications',
              description:
                  'You are all caught up on report updates and alerts.',
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                if (unread.isNotEmpty) ...[
                  Row(
                    children: [
                      Text(
                        'New',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryNavy,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${unread.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...unread.map(
                    (notif) => Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: _buildNotificationTile(context, notif, isDark),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (read.isNotEmpty) ...[
                  Text(
                    'Earlier',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...read.map(
                    (notif) => Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: _buildNotificationTile(context, notif, isDark),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    NotificationItem notif,
    bool isDark,
  ) {
    final dataRepo = Provider.of<DataRepository>(context, listen: false);

    IconData icon;
    Color iconColor;
    switch (notif.type) {
      case 'assignment':
        icon = Icons.person_add_alt_1_outlined;
        iconColor = AppColors.statusAssigned;
        break;
      case 'verification':
        icon = Icons.verified_outlined;
        iconColor = AppColors.statusCompleted;
        break;
      case 'approval':
        icon = Icons.trending_up_rounded;
        iconColor = AppColors.statusOngoing;
        break;
      case 'dispute':
        icon = Icons.error_outline_rounded;
        iconColor = AppColors.statusDisputed;
        break;
      default:
        icon = Icons.notifications_none_rounded;
        iconColor = AppColors.primaryCyan;
    }

    return InkWell(
      onTap: () {
        dataRepo.markNotificationAsRead(notif.id);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: notif.isRead
                                ? FontWeight.w600
                                : FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryCyan,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.body,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTimeAgo(notif.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.lightTextMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
