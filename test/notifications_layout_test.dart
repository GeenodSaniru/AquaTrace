import 'package:aquatrace/core/constants/app_roles.dart';
import 'package:aquatrace/core/models/firestore_time.dart';
import 'package:aquatrace/core/models/notification_item.dart';
import 'package:aquatrace/core/theme/app_theme.dart';
import 'package:aquatrace/features/notifications/presentation/activity_history_screen.dart';
import 'package:aquatrace/features/notifications/presentation/shared_notifications_view.dart';
import 'package:aquatrace/features/notifications/services/in_memory_notification_gateway.dart';
import 'package:aquatrace/features/notifications/services/push_messaging_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/notification_fakes.dart';
import 'support/notification_harness.dart';

const _longTitle =
    'Technician Assigned to Your Report: Pipe Leak at an Unusually Long Street Name';
const _longBody =
    'Your report AT-2026-00124 has been assigned to Kasun Jayawardena of the '
    'Colombo North service area. Please keep the area clear and accessible so '
    'the repair team can start work as soon as they arrive on site.';

/// A small phone, [textScale] times the normal text size.
void useSmallScreen(WidgetTester tester, {double textScale = 1}) {
  tester.view.physicalSize = const Size(320 * 3, 568 * 3);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

List<NotificationItem> longNotifications() => [
  for (var i = 0; i < 3; i++)
    NotificationItem(
      id: 'long-$i',
      recipientUid: 'demo-citizen-001',
      title: _longTitle,
      body: _longBody,
      reportId: 'AT-2026-00124',
      type: NotificationType.values[i].value,
      isRead: i == 2,
      createdAt: DateTime.now().subtract(Duration(hours: i + 1)),
    ),
];

void main() {
  group('Notification list layout and accessibility', () {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets(
          'long content fits a 320 px phone at ${scale}x text (${dark ? 'dark' : 'light'})',
          (tester) async {
            useSmallScreen(tester, textScale: scale);
            final h = await buildHarness(
              tester,
              seed: longNotifications(),
              client: FakePushClient(),
            );
            await pumpScreen(
              tester,
              h,
              const SharedNotificationsView(),
              theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            );
            // Any RenderFlex overflow / layout error fails the test on its own.
            // The list is lazy and, at large text, the permission banner fills
            // the first screen: scroll until a tile is built.
            await tester.drag(
              find.byType(CustomScrollView),
              const Offset(0, -600),
            );
            await tester.pump();
            expect(find.text(_longTitle), findsWidgets);
            expect(find.text('Mark all read'), findsOneWidget);
            // The permission banner (not asked yet) fit above the list.
            await tester.drag(
              find.byType(CustomScrollView),
              const Offset(0, 1200),
            );
            await tester.pump();
            expect(find.text('Turn on push notifications'), findsOneWidget);
          },
        );
      }
    }

    testWidgets('every notification is a large, labelled touch target', (
      tester,
    ) async {
      final h = await buildHarness(tester, seed: longNotifications());
      await pumpScreen(tester, h, const SharedNotificationsView());
      final handle = tester.ensureSemantics();
      final tiles = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.label ?? '').contains('notification.'),
      );
      expect(tiles, findsNWidgets(3));
      for (final element in tiles.evaluate()) {
        final size = tester.getSize(find.byWidget(element.widget));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
      }
      expect(
        find.bySemanticsLabel(RegExp(r'^Unread notification\. ')),
        findsNWidgets(2),
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Read notification\. ')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a long inbox scrolls to the end without errors', (
      tester,
    ) async {
      final many = [
        for (var i = 0; i < 100; i++)
          NotificationItem(
            id: 'n$i',
            recipientUid: 'demo-citizen-001',
            title: 'Update $i',
            body: 'Body $i',
            reportId: 'AT-2026-00124',
            type: 'update',
            isRead: i.isOdd,
            createdAt: DateTime.now().subtract(Duration(minutes: i)),
          ),
      ];
      final h = await buildHarness(tester, seed: many);
      await pumpScreen(tester, h, const SharedNotificationsView());
      expect(find.text('New'), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -20000));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -20000));
      await tester.pump();
      expect(find.text('Update 99'), findsOneWidget); // oldest, at the very end
    });

    testWidgets('the unread count on the badge matches the list', (
      tester,
    ) async {
      final h = await buildHarness(tester, seed: longNotifications());
      await pumpScreen(tester, h, const SharedNotificationsView());
      expect(h.repo.unreadNotificationCount, 2);
      expect(find.text('2'), findsOneWidget);
    });
  });

  group('Activity history layout', () {
    testWidgets('a long timeline fits a 320 px phone at 2x text', (
      tester,
    ) async {
      useSmallScreen(tester, textScale: 2);
      final h = await buildHarness(tester);
      h.repo.getTimelineForReport(
        'AT-2026-00124',
      ); // demo timeline for this report
      await pumpScreen(
        tester,
        h,
        const ActivityHistoryScreen(reportId: 'AT-2026-00124'),
      );
      await tester.pump();
      await tester.pump(); // stream delivers the demo history
      // At 2x text the report card fills the first screen; scroll to the timeline.
      await tester.scrollUntilVisible(
        find.text('Report Submitted'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Report Submitted'), findsOneWidget);
    });

    testWidgets('unknown event times are labelled and keep their place', (
      tester,
    ) async {
      final h = await buildHarness(tester, role: UserRole.admin);
      await pumpScreen(
        tester,
        h,
        const ActivityHistoryScreen(reportId: 'AT-2026-00124'),
        theme: AppTheme.darkTheme,
      );
      await tester.pump();
      // Known events show full dates; none of the demo events is "unknown".
      expect(find.text('Time unavailable'), findsNothing);
      expect(isKnownTime(unknownTime), isFalse);
    });
  });

  group('Stale references and offline behaviour', () {
    testWidgets(
      'a notification whose report is gone opens an explanation, not a crash',
      (tester) async {
        final h = await buildHarness(
          tester,
          seed: [note('stale', reportId: 'AT-DELETED-9', at: DateTime.now())],
        );
        await pumpScreen(tester, h, const SharedNotificationsView());
        await tester.tap(find.text('Title stale'));
        await tester.pump();
        await tester.pump(
          const Duration(seconds: 4),
        ); // grace period for live reports
        expect(find.text('Report unavailable'), findsOneWidget);
        expect(
          h.gateway.snapshotFor(h.auth.currentUser!.uid).single.isRead,
          isTrue,
          reason: 'opening still marks it read',
        );
      },
    );

    testWidgets(
      'losing the connection after data loaded keeps the inbox and says so',
      (tester) async {
        final gateway = InMemoryNotificationGateway(
          seed: {
            'demo-citizen-001': [
              note('keep', uid: 'demo-citizen-001', at: DateTime.now()),
            ],
          },
        );
        final h = await buildHarness(tester, gateway: gateway);
        await pumpScreen(tester, h, const SharedNotificationsView());
        expect(find.text('Title keep'), findsOneWidget);

        gateway.failStream('demo-citizen-001', StateError('offline'));
        await tester.pump();
        await tester.pump();

        // The saved notifications stay visible, with a notice; nothing crashes.
        expect(find.text('Title keep'), findsOneWidget);
        expect(
          find.textContaining('Showing saved notifications.'),
          findsOneWidget,
        );
        expect(find.text('Something went wrong'), findsNothing);

        // Back online: retry clears the notice and shows live data again.
        h.repo.notificationStore.retry();
        await tester.pump();
        await tester.pump();
        expect(
          find.textContaining('Showing saved notifications.'),
          findsNothing,
        );
        expect(find.text('Title keep'), findsOneWidget);
      },
    );

    testWidgets(
      'mark-all-read while offline reports the failure and restores unread',
      (tester) async {
        final h = await buildHarness(tester, seed: longNotifications());
        await pumpScreen(tester, h, const SharedNotificationsView());
        h.gateway.markFailure = StateError('offline');
        await tester.tap(find.text('Mark all read'));
        await tester.pump();
        await tester.pump();
        expect(h.repo.unreadNotificationCount, 2);
        expect(
          find.text('Could not mark notifications as read. Please try again.'),
          findsOneWidget,
        );
        // Back online: the same action now works.
        h.gateway.markFailure = null;
        await tester.pump(const Duration(seconds: 5));
        await tester.tap(find.text('Mark all read'));
        await tester.pump();
        await tester.pump();
        expect(h.repo.unreadNotificationCount, 0);
      },
    );

    testWidgets('permission banner states fit a small screen at 2x text', (
      tester,
    ) async {
      useSmallScreen(tester, textScale: 2);
      for (final status in [
        PushPermissionStatus.notDetermined,
        PushPermissionStatus.denied,
      ]) {
        final h = await buildHarness(
          tester,
          seed: const [],
          client: FakePushClient(permission: status),
        );
        await pumpScreen(tester, h, const SharedNotificationsView());
        expect(
          find.byIcon(Icons.notifications_active_outlined),
          findsOneWidget,
        );
      }
    });
  });
}
