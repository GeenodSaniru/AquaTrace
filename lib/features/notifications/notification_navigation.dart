import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/navigation/app_router.dart';
import '../../core/navigation/navigation_service.dart';
import '../../core/services/data_repository.dart';
import 'services/push_messaging_service.dart';

/// Glue between push messages and in-app navigation.
class NotificationNavigation {
  NotificationNavigation._();

  /// Opens the report / job behind a notification. The notification is marked
  /// read (immediately, or once the inbox has loaded).
  ///
  /// Authorization is enforced by the destination screen, which resolves the
  /// report from the signed-in user's own data.
  static void openReport(
    DataRepository repository,
    String reportId,
    String? notificationId,
  ) {
    if (notificationId != null) {
      repository.notificationStore.markReadWhenAvailable(notificationId);
    }
    final navigation = NavigationService.navigateTo<void>(
      AppRouter.reportDetail,
      arguments: reportId,
    );
    if (navigation != null) unawaited(navigation);
  }

  /// In-app banner for a push that arrives while the app is open.
  static void showForegroundBanner(
    PushMessage message,
    DataRepository repository,
  ) {
    final messenger = NavigationService.messengerKey.currentState;
    final title = message.title?.trim();
    final body = message.body?.trim();
    if (messenger == null ||
        ((title == null || title.isEmpty) && (body == null || body.isEmpty))) {
      return;
    }
    final reportId = message.reportId;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null && title.isNotEmpty)
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              if (body != null && body.isNotEmpty) Text(body),
            ],
          ),
          action: reportId == null
              ? null
              : SnackBarAction(
                  label: 'View',
                  onPressed: () =>
                      openReport(repository, reportId, message.notificationId),
                ),
        ),
      );
  }
}
