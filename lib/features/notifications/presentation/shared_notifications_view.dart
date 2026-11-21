import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/notification_item.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/services/data_repository.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_widget.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../services/push_messaging_service.dart';
import 'notification_formatters.dart';
import 'push_permission_banner.dart';

/// Notification list shared by the citizen, technician and admin shells.
///
/// Layout follows the AquaTrace UI design: a "New" section with an unread
/// count, an "Earlier" section, per-item unread dot, relative timestamps and a
/// "Mark all read" action in the app bar.
class SharedNotificationsView extends StatelessWidget {
  const SharedNotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<DataRepository>();
    final store = repository.notificationStore;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = store.items;
    final unread = items.where((item) => !item.isRead).toList();
    final read = items.where((item) => item.isRead).toList();

    // Surface a failed mark-read once, after this frame.
    final actionError = store.takeActionError();
    if (actionError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(content: Text(actionError)));
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread.isNotEmpty)
            TextButton(
              onPressed: store.markAllAsRead,
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
      body: Column(
        children: [
          const PushPermissionBanner(),
          Expanded(
            child: _buildContent(
              context,
              isDark: isDark,
              isLoading: store.isLoading,
              errorMessage: store.errorMessage,
              onRetry: store.retry,
              unread: unread,
              read: read,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required bool isDark,
    required bool isLoading,
    required String? errorMessage,
    required VoidCallback onRetry,
    required List<NotificationItem> unread,
    required List<NotificationItem> read,
  }) {
    final hasItems = unread.isNotEmpty || read.isNotEmpty;
    if (isLoading && !hasItems) {
      return const AppLoadingIndicator(message: 'Loading notifications…');
    }
    if (errorMessage != null && !hasItems) {
      return AppErrorWidget(message: errorMessage, onRetry: onRetry);
    }
    if (!hasItems) {
      return const AppEmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'No Notifications',
        description: 'You are all caught up on report updates and alerts.',
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Showing saved notifications. $errorMessage',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.statusDisputed,
              ),
            ),
          ),
        if (unread.isNotEmpty) ...[
          _SectionHeader(title: 'New', count: unread.length, isDark: isDark),
          const SizedBox(height: 10),
          for (final notification in unread)
            _NotificationTile(notification: notification, isDark: isDark),
          const SizedBox(height: 6),
        ],
        if (read.isNotEmpty) ...[
          _SectionHeader(title: 'Earlier', isDark: isDark),
          const SizedBox(height: 10),
          for (final notification in read)
            _NotificationTile(notification: notification, isDark: isDark),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.count, required this.isDark});

  final String title;
  final int? count;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryNavy,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.isDark});

  final NotificationItem notification;
  final bool isDark;

  static ({IconData icon, Color color}) _appearance(NotificationType type) {
    switch (type) {
      case NotificationType.assignment:
        return (
          icon: Icons.person_add_alt_1_outlined,
          color: AppColors.statusAssigned,
        );
      case NotificationType.verification:
        return (
          icon: Icons.verified_outlined,
          color: AppColors.statusCompleted,
        );
      case NotificationType.approval:
        return (
          icon: Icons.trending_up_rounded,
          color: AppColors.statusOngoing,
        );
      case NotificationType.dispute:
        return (
          icon: Icons.error_outline_rounded,
          color: AppColors.statusDisputed,
        );
      case NotificationType.update:
        return (
          icon: Icons.notifications_none_rounded,
          color: AppColors.primaryCyan,
        );
    }
  }

  Future<void> _open(BuildContext context) async {
    final repository = context.read<DataRepository>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    unawaited(repository.markNotificationAsRead(notification.id));

    final reportId = sanitizeReportId(notification.reportId);
    if (reportId == null) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('This notification is not linked to a report.'),
        ),
      );
      return;
    }
    unawaited(navigator.pushNamed(AppRouter.reportDetail, arguments: reportId));
  }

  @override
  Widget build(BuildContext context) {
    final appearance = _appearance(notification.notificationType);
    final isRead = notification.isRead;
    final primary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final relative = NotificationFormatters.relativeTime(
      notification.createdAt,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        label:
            '${isRead ? 'Read' : 'Unread'} notification. '
            '${notification.title}. ${notification.body}. $relative.',
        excludeSemantics: true,
        onTap: () => _open(context),
        child: Material(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: InkWell(
            onTap: () => _open(context),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: appearance.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      appearance.icon,
                      size: 20,
                      color: appearance.color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isRead
                                      ? FontWeight.w600
                                      : FontWeight.w700,
                                  color: primary,
                                ),
                              ),
                            ),
                            if (!isRead)
                              Container(
                                key: const ValueKey('unread-dot'),
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
                          notification.body,
                          style: TextStyle(fontSize: 12, color: secondary),
                        ),
                        const SizedBox(height: 6),
                        Tooltip(
                          message: NotificationFormatters.absoluteTime(
                            notification.createdAt,
                          ),
                          child: Text(
                            relative,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
