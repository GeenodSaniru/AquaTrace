import 'dart:async';

import 'package:aquatrace/core/constants/app_roles.dart';
import 'package:aquatrace/core/models/firestore_time.dart';
import 'package:aquatrace/core/models/mock_data.dart';
import 'package:aquatrace/core/models/notification_item.dart';
import 'package:aquatrace/core/navigation/app_router.dart';
import 'package:aquatrace/core/navigation/navigation_service.dart';
import 'package:aquatrace/core/services/auth_service.dart';
import 'package:aquatrace/core/services/data_repository.dart';
import 'package:aquatrace/core/services/preferences_service.dart';
import 'package:aquatrace/core/theme/app_theme.dart';
import 'package:aquatrace/core/theme/theme_provider.dart';
import 'package:aquatrace/features/admin/presentation/admin_main_shell.dart';
import 'package:aquatrace/features/notifications/services/demo_notifications.dart';
import 'package:aquatrace/features/auth/providers/auth_provider.dart';
import 'package:aquatrace/features/notifications/notification_navigation.dart';
import 'package:aquatrace/features/notifications/presentation/activity_history_screen.dart';
import 'package:aquatrace/features/notifications/presentation/report_link_screen.dart';
import 'package:aquatrace/features/notifications/presentation/shared_notifications_view.dart';
import 'package:aquatrace/features/notifications/services/in_memory_notification_gateway.dart';
import 'package:aquatrace/features/notifications/services/push_messaging_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/notification_fakes.dart';

/// Fake geolocator platform standing in for "open app settings".
class _SettingsPlatform extends GeolocatorPlatform {
  _SettingsPlatform({this.result = true, this.failure});

  final bool result;
  final Object? failure;
  int openCalls = 0;

  @override
  Future<bool> openAppSettings() async {
    openCalls++;
    if (failure != null) throw failure!;
    return result;
  }
}

/// A gateway whose notification stream never emits (to observe loading).
class _NeverEmittingGateway extends InMemoryNotificationGateway {
  @override
  Stream<List<NotificationItem>> watchNotifications(
    String uid, {
    int limit = 100,
  }) => StreamController<List<NotificationItem>>().stream;
}

class NotificationHarness {
  NotificationHarness({
    required this.repo,
    required this.auth,
    required this.push,
    required this.gateway,
    required this.client,
    required this.tokens,
    required this.prefs,
  });

  final PreferencesService prefs;
  final DataRepository repo;
  final AuthProvider auth;
  final PushMessagingService push;
  final InMemoryNotificationGateway gateway;
  final FakePushClient client;
  final FakeTokenStore tokens;
}

Future<NotificationHarness> buildHarness(
  WidgetTester tester, {
  UserRole role = UserRole.citizen,
  List<NotificationItem>? seed,
  InMemoryNotificationGateway? gateway,
  FakePushClient? client,
  bool pushEnabled = true,
  bool signedIn = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = PreferencesService(await SharedPreferences.getInstance());
  final auth = AuthProvider(AuthService(prefs));
  await tester.runAsync(() => auth.signInWithDemoRole(role));
  final uid = auth.currentUser!.uid;

  final gw =
      gateway ??
      InMemoryNotificationGateway(
        seed: {uid: seed ?? const <NotificationItem>[]},
      );
  final repo = DataRepository(notificationGateway: gw);
  repo.bindNotificationUser(uid);

  final fakeClient =
      client ?? FakePushClient(permission: PushPermissionStatus.granted);
  final tokens = FakeTokenStore();
  final push = PushMessagingService(
    client: fakeClient,
    tokenStore: tokens,
    isUserEnabled: () => pushEnabled,
    onOpenReport: (reportId, notificationId) =>
        NotificationNavigation.openReport(repo, reportId, notificationId),
    onForegroundMessage: (message) =>
        NotificationNavigation.showForegroundBanner(message, repo),
  );
  await push.initialize();
  await push.bindUser(uid);

  if (!signedIn) await tester.runAsync(auth.signOut);
  return NotificationHarness(
    repo: repo,
    auth: auth,
    push: push,
    gateway: gw,
    client: fakeClient,
    tokens: tokens,
    prefs: prefs,
  );
}

Future<void> pumpScreen(
  WidgetTester tester,
  NotificationHarness harness,
  Widget home,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<DataRepository>.value(value: harness.repo),
        ChangeNotifierProvider<AuthProvider>.value(value: harness.auth),
        ChangeNotifierProvider<PushMessagingService>.value(value: harness.push),
        ChangeNotifierProvider<PreferencesService>.value(value: harness.prefs),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        navigatorKey: NavigationService.navigatorKey,
        scaffoldMessengerKey: NavigationService.messengerKey,
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: home,
      ),
    ),
  );
  await tester.pump(); // deliver the first notification snapshot
}

final _now = DateTime.now();

List<NotificationItem> threeNotifications() => [
  note(
    'n-new',
    at: _now.subtract(const Duration(hours: 2)),
    reportId: 'AT-2026-00124',
    type: 'assignment',
  ),
  note(
    'n-mid',
    at: _now.subtract(const Duration(hours: 5)),
    reportId: 'AT-2026-00126',
    type: 'verification',
  ),
  note(
    'n-old',
    at: _now.subtract(const Duration(days: 1)),
    isRead: true,
    reportId: 'AT-2026-00128',
    type: 'approval',
  ),
];

int unreadDots(WidgetTester tester) =>
    find.byKey(const ValueKey('unread-dot')).evaluate().length;

void main() {
  tearDown(() {
    // Navigator/messenger keys are process-wide singletons.
    NavigationService.messengerKey.currentState?.clearSnackBars();
  });

  group('Notification list', () {
    testWidgets('shows New / Earlier sections, unread dots and timestamps', (
      tester,
    ) async {
      final h = await buildHarness(tester, seed: threeNotifications());
      await pumpScreen(tester, h, const SharedNotificationsView());

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(find.text('Earlier'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // unread count badge
      expect(unreadDots(tester), 2);
      expect(find.text('Mark all read'), findsOneWidget);
      expect(find.text('Title n-new'), findsOneWidget);
      expect(find.text('2h ago'), findsOneWidget);
      expect(find.text('5h ago'), findsOneWidget);
      expect(find.text('1d ago'), findsOneWidget);

      // Newest first within the New section.
      final first = tester.getTopLeft(find.text('Title n-new')).dy;
      final second = tester.getTopLeft(find.text('Title n-mid')).dy;
      final third = tester.getTopLeft(find.text('Title n-old')).dy;
      expect(first, lessThan(second));
      expect(second, lessThan(third));
    });

    testWidgets('unknown timestamps are labelled, not shown as "now"', (
      tester,
    ) async {
      final h = await buildHarness(
        tester,
        seed: [
          note('n1', at: unknownTime),
          note('n2', at: _now),
        ],
      );
      await pumpScreen(tester, h, const SharedNotificationsView());
      expect(find.text('Time unavailable'), findsOneWidget);
      expect(find.text('Just now'), findsOneWidget);
      // Unknown-time item sinks below the dated one.
      expect(
        tester.getTopLeft(find.text('Title n2')).dy,
        lessThan(tester.getTopLeft(find.text('Title n1')).dy),
      );
    });

    testWidgets('mark all read clears every unread marker and the action', (
      tester,
    ) async {
      final h = await buildHarness(tester, seed: threeNotifications());
      await pumpScreen(tester, h, const SharedNotificationsView());

      await tester.tap(find.text('Mark all read'));
      await tester.pump();
      await tester.pump();

      expect(unreadDots(tester), 0);
      expect(find.text('Mark all read'), findsNothing);
      expect(find.text('New'), findsNothing);
      expect(h.repo.unreadNotificationCount, 0);
      expect(h.gateway.markAllReadCalls, 1);
    });

    testWidgets('a failed mark-all-read restores state and explains', (
      tester,
    ) async {
      final h = await buildHarness(tester, seed: threeNotifications());
      await pumpScreen(tester, h, const SharedNotificationsView());
      h.gateway.markFailure = StateError('offline');

      await tester.tap(find.text('Mark all read'));
      await tester.pump();
      await tester.pump();

      expect(unreadDots(tester), 2);
      expect(
        find.text('Could not mark notifications as read. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping a notification marks it read and opens the report', (
      tester,
    ) async {
      final h = await buildHarness(tester, seed: threeNotifications());
      await pumpScreen(tester, h, const SharedNotificationsView());

      await tester.tap(find.text('Title n-new'));
      await tester.pumpAndSettle();

      // Deep link destination: the report's activity history.
      expect(find.byType(ActivityHistoryScreen), findsOneWidget);
      expect(find.text('Activity History'), findsOneWidget);
      expect(find.text('AT-2026-00124'), findsOneWidget);

      // Read state was persisted through the gateway.
      expect(
        h.gateway
            .snapshotFor(h.auth.currentUser!.uid)
            .firstWhere((n) => n.id == 'n-new')
            .isRead,
        isTrue,
      );

      // Back on the list: one fewer unread, and no stale New entry.
      NavigationService.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(unreadDots(tester), 1);
    });

    testWidgets('a notification without a valid report explains itself', (
      tester,
    ) async {
      final h = await buildHarness(
        tester,
        seed: [
          note('n1', reportId: ''),
          note('n2', reportId: '../etc'),
        ],
      );
      await pumpScreen(tester, h, const SharedNotificationsView());

      await tester.tap(find.text('Title n1'));
      await tester.pump();
      await tester.pump();
      expect(
        find.text('This notification is not linked to a report.'),
        findsOneWidget,
      );
      expect(find.byType(ReportLinkScreen), findsNothing);
      // It is still marked read.
      expect(unreadDots(tester), 1);

      await tester.tap(find.text('Title n2'));
      await tester.pump();
      expect(find.byType(ReportLinkScreen), findsNothing);
    });

    testWidgets('empty inbox shows the empty state', (tester) async {
      final h = await buildHarness(tester, seed: const []);
      await pumpScreen(tester, h, const SharedNotificationsView());
      expect(find.text('No Notifications'), findsOneWidget);
      expect(find.text('Mark all read'), findsNothing);
    });

    testWidgets('shows a loading state until the first snapshot', (
      tester,
    ) async {
      final h = await buildHarness(tester, gateway: _NeverEmittingGateway());
      await pumpScreen(tester, h, const SharedNotificationsView());
      expect(find.text('Loading notifications…'), findsOneWidget);
      expect(find.text('No Notifications'), findsNothing);
    });

    testWidgets('load failure shows an error with a working retry', (
      tester,
    ) async {
      final gateway = InMemoryNotificationGateway(
        seed: {
          MockData.citizenUser.uid: [note('n1', uid: MockData.citizenUser.uid)],
        },
      )..watchFailure = StateError('down');
      final h = await buildHarness(tester, gateway: gateway);
      await pumpScreen(tester, h, const SharedNotificationsView());

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      gateway.watchFailure = null;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Title n1'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
    });

    testWidgets('a notification delivered by the backend appears live', (
      tester,
    ) async {
      final h = await buildHarness(tester, seed: const []);
      await pumpScreen(tester, h, const SharedNotificationsView());
      expect(find.text('No Notifications'), findsOneWidget);

      h.gateway.deliver(
        note(
          'live',
          uid: h.auth.currentUser!.uid,
          at: DateTime.now(),
          type: 'dispute',
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Title live'), findsOneWidget);
      expect(find.text('Just now'), findsOneWidget);
      expect(unreadDots(tester), 1);
    });
  });

  group('Push permission banner', () {
    testWidgets('offers to enable, requests permission on tap, registers', (
      tester,
    ) async {
      final client = FakePushClient(); // not determined, will grant
      final h = await buildHarness(tester, seed: const [], client: client);
      await pumpScreen(tester, h, const SharedNotificationsView());

      expect(find.text('Turn on push notifications'), findsOneWidget);
      expect(client.requestCalls, 0); // never automatic

      await tester.tap(find.text('Enable'));
      await tester.pump();
      await tester.pump();

      expect(client.requestCalls, 1);
      expect(find.text('Turn on push notifications'), findsNothing);
      expect(h.tokens.tokensOf(h.auth.currentUser!.uid), {'token-1'});
    });

    testWidgets('permission denied: explains and keeps push off', (
      tester,
    ) async {
      final client = FakePushClient(requestResult: PushPermissionStatus.denied);
      final h = await buildHarness(tester, seed: const [], client: client);
      await pumpScreen(tester, h, const SharedNotificationsView());

      await tester.tap(find.text('Enable'));
      await tester.pump();
      await tester.pump();

      expect(
        find.textContaining('Push notifications stay off'),
        findsOneWidget,
      );
      expect(find.text('Push notifications are blocked'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);
      expect(h.tokens.tokensByUser, isEmpty);
    });

    testWidgets('settings action opens system settings when it can', (
      tester,
    ) async {
      final platform = _SettingsPlatform();
      final previous = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = platform;
      addTearDown(() => GeolocatorPlatform.instance = previous);

      final client = FakePushClient(permission: PushPermissionStatus.denied);
      final h = await buildHarness(tester, seed: const [], client: client);
      await pumpScreen(tester, h, const SharedNotificationsView());

      await tester.tap(find.text('Open settings'));
      await tester.pump();
      await tester.pump();
      expect(platform.openCalls, 1);
      expect(
        find.text('Open your device settings to change notifications.'),
        findsNothing,
      );
    });

    testWidgets('settings action explains when settings cannot be opened', (
      tester,
    ) async {
      for (final failure in <Object?>[null, MissingPluginException('none')]) {
        final platform = _SettingsPlatform(result: false, failure: failure);
        final previous = GeolocatorPlatform.instance;
        GeolocatorPlatform.instance = platform;
        addTearDown(() => GeolocatorPlatform.instance = previous);

        final client = FakePushClient(permission: PushPermissionStatus.denied);
        final h = await buildHarness(tester, seed: const [], client: client);
        await pumpScreen(tester, h, const SharedNotificationsView());

        await tester.tap(find.text('Open settings'));
        await tester.pump();
        await tester.pump();
        expect(
          find.text('Open your device settings to change notifications.'),
          findsOneWidget,
          reason: failure == null ? 'returned false' : 'plugin missing',
        );
        NavigationService.messengerKey.currentState?.clearSnackBars();
      }
    });

    testWidgets('can be dismissed', (tester) async {
      final h = await buildHarness(
        tester,
        seed: const [],
        client: FakePushClient(),
      );
      await pumpScreen(tester, h, const SharedNotificationsView());
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pump();
      expect(find.text('Turn on push notifications'), findsNothing);
    });

    testWidgets('is hidden when granted, unsupported, or switched off', (
      tester,
    ) async {
      final granted = await buildHarness(tester, seed: const []);
      await pumpScreen(tester, granted, const SharedNotificationsView());
      expect(find.byIcon(Icons.notifications_active_outlined), findsNothing);

      final unsupported = await buildHarness(
        tester,
        seed: const [],
        client: FakePushClient(supported: false),
      );
      await pumpScreen(tester, unsupported, const SharedNotificationsView());
      expect(find.byIcon(Icons.notifications_active_outlined), findsNothing);

      final off = await buildHarness(
        tester,
        seed: const [],
        client: FakePushClient(),
        pushEnabled: false,
      );
      await pumpScreen(tester, off, const SharedNotificationsView());
      expect(find.byIcon(Icons.notifications_active_outlined), findsNothing);
    });

    testWidgets('registration problems are surfaced with a retry', (
      tester,
    ) async {
      final client = FakePushClient(permission: PushPermissionStatus.granted)
        ..token = null;
      final h = await buildHarness(tester, seed: const [], client: client);
      await pumpScreen(tester, h, const SharedNotificationsView());
      expect(find.text('Push notifications need attention'), findsOneWidget);

      client.token = 'token-1';
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Push notifications need attention'), findsNothing);
      expect(h.tokens.tokensOf(h.auth.currentUser!.uid), {'token-1'});
    });
  });

  group('Deep link destination', () {
    testWidgets('citizen sees the report activity history', (tester) async {
      final h = await buildHarness(tester);
      await pumpScreen(
        tester,
        h,
        const ReportLinkScreen(reportId: 'AT-2026-00124'),
      );
      expect(find.byType(ActivityHistoryScreen), findsOneWidget);
      expect(find.text('Report Submitted'), findsOneWidget);
    });

    testWidgets('the assigned technician is taken to the job detail', (
      tester,
    ) async {
      final h = await buildHarness(tester, role: UserRole.technician);
      await pumpScreen(
        tester,
        h,
        const ReportLinkScreen(reportId: 'AT-2026-00128'),
      );
      expect(find.text('Job Details'), findsOneWidget);
      expect(find.text('AT-2026-00128'), findsOneWidget);
    });

    testWidgets('a technician is not shown another technician\'s job', (
      tester,
    ) async {
      // AT-2026-00127 belongs to a different technician.
      final h = await buildHarness(tester, role: UserRole.technician);
      // Repository holds all demo reports; ownership is enforced by the screen
      // choosing the technician view only for the assigned technician.
      await pumpScreen(
        tester,
        h,
        const ReportLinkScreen(reportId: 'AT-2026-00127'),
      );
      expect(find.text('Job Details'), findsNothing);
      expect(find.byType(ActivityHistoryScreen), findsOneWidget);
    });

    testWidgets('admin opens the history for any report', (tester) async {
      final h = await buildHarness(tester, role: UserRole.admin);
      await pumpScreen(
        tester,
        h,
        const ReportLinkScreen(reportId: 'AT-2026-00125'),
      );
      expect(find.byType(ActivityHistoryScreen), findsOneWidget);
    });

    testWidgets('an unknown or deleted report becomes "unavailable"', (
      tester,
    ) async {
      final h = await buildHarness(tester);
      await pumpScreen(tester, h, const ReportLinkScreen(reportId: 'AT-9999'));
      expect(find.text('Opening report…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Report unavailable'), findsOneWidget);
      expect(find.byType(ActivityHistoryScreen), findsNothing);
    });

    testWidgets('a malformed id is rejected immediately', (tester) async {
      final h = await buildHarness(tester);
      await pumpScreen(tester, h, const ReportLinkScreen(reportId: '../admin'));
      expect(find.text('Report unavailable'), findsOneWidget);
      expect(
        find.text('This link does not point to a valid report.'),
        findsOneWidget,
      );
    });

    testWidgets('requires authentication', (tester) async {
      final h = await buildHarness(tester, signedIn: false);
      await pumpScreen(
        tester,
        h,
        const ReportLinkScreen(reportId: 'AT-2026-00124'),
      );
      expect(find.text('Sign in required'), findsOneWidget);
      expect(find.byType(ActivityHistoryScreen), findsNothing);
    });

    testWidgets('a tapped push opens the report and marks it read', (
      tester,
    ) async {
      final h = await buildHarness(tester, seed: threeNotifications());
      await pumpScreen(tester, h, const SharedNotificationsView());

      h.client.opened.add(
        const PushMessage(
          data: {'reportId': 'AT-2026-00124', 'notificationId': 'n-new'},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ActivityHistoryScreen), findsOneWidget);
      expect(
        h.gateway
            .snapshotFor(h.auth.currentUser!.uid)
            .firstWhere((n) => n.id == 'n-new')
            .isRead,
        isTrue,
      );
    });

    testWidgets(
      'a foreground push shows a banner whose action opens the report',
      (tester) async {
        final h = await buildHarness(tester, seed: threeNotifications());
        await pumpScreen(tester, h, const SharedNotificationsView());

        h.client.foreground.add(
          const PushMessage(
            title: 'Technician Assigned',
            body: 'Assigned to Kasun',
            data: {'reportId': 'AT-2026-00128', 'notificationId': 'n-old'},
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle(); // finish the snackbar entry animation
        expect(find.text('Technician Assigned'), findsWidgets);
        expect(find.text('Assigned to Kasun'), findsOneWidget);

        await tester.tap(find.text('View'));
        await tester.pumpAndSettle();
        expect(find.byType(ActivityHistoryScreen), findsOneWidget);
        expect(find.text('AT-2026-00128'), findsOneWidget);
      },
    );
  });

  group('Activity history', () {
    testWidgets('shows the timeline oldest first with the design formatting', (
      tester,
    ) async {
      // Tall viewport so the lazily-built list renders the final card too.
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final h = await buildHarness(tester);
      await pumpScreen(
        tester,
        h,
        const ActivityHistoryScreen(reportId: 'AT-2026-00124'),
      );
      await tester.pump();

      const titles = [
        'Report Submitted',
        'Report Verified',
        'Technician Assigned',
        'Repair Started',
        'Community Verified',
      ];
      final offsets = [
        for (final title in titles) tester.getTopLeft(find.text(title)).dy,
      ];
      expect([...offsets]..sort(), offsets, reason: 'chronological order');

      expect(find.text('Pipe Leak · Galle Road, Colombo 03'), findsOneWidget);
      expect(find.text('24 Sep 2026 – 10:32 AM'), findsOneWidget);
      expect(find.text('24 Sep 2026 – 1:15 PM'), findsOneWidget);
      expect(find.text('Amal Perera'), findsOneWidget);
      expect(find.text('Ongoing'), findsOneWidget); // status badge
      expect(find.text('Community Verified ✓'), findsOneWidget);
      expect(
        find.text('3 nearby citizens confirmed this repair is complete.'),
        findsOneWidget,
      );
    });

    testWidgets('empty history, then a live appended event', (tester) async {
      final h = await buildHarness(tester, role: UserRole.admin);
      await pumpScreen(
        tester,
        h,
        const ActivityHistoryScreen(reportId: 'AT-2026-00125'),
      );
      await tester.pump();
      expect(find.text('No activity yet'), findsOneWidget);
      expect(find.text('Community Verified ✓'), findsNothing);

      await h.repo.assignTechnician(
        reportId: 'AT-2026-00125',
        technicianUid: MockData.technicianUser.uid,
        technicianName: MockData.technicianUser.displayName,
        adminName: 'Dilani Wickramasinghe',
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('No activity yet'), findsNothing);
      expect(find.text('Technician Assigned'), findsOneWidget);
      expect(find.text('Dilani Wickramasinghe'), findsOneWidget);
    });

    testWidgets('a report that cannot be read still renders gracefully', (
      tester,
    ) async {
      final h = await buildHarness(tester);
      await pumpScreen(
        tester,
        h,
        const ActivityHistoryScreen(reportId: 'AT-404'),
      );
      await tester.pump();
      expect(find.text('AT-404'), findsOneWidget);
      expect(find.text('Report details are not available.'), findsOneWidget);
      expect(find.text('No activity yet'), findsOneWidget);
    });

    testWidgets(
      'admin shell: the bell opens notifications, the Activity tab opens history',
      (tester) async {
        // The admin dashboard (Member 5) triggers a debug-only "ListTile inside
        // a coloured DecoratedBox" assertion; it is unrelated to this module, so
        // ignore exactly that message and fail on anything else.
        final previousOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains(
            'ListTile background color or ink splashes may be invisible',
          )) {
            return;
          }
          previousOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = previousOnError);

        await tester.binding.setSurfaceSize(const Size(800, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final h = await buildHarness(
          tester,
          role: UserRole.admin,
          seed: DemoNotifications.build()[MockData.adminUser.uid],
        );
        await pumpScreen(tester, h, const AdminMainShell());
        await tester.pump();

        // Dashboard bell shows the unread count and opens the notification list.
        expect(h.repo.unreadNotificationCount, 2);
        await tester.tap(find.byIcon(Icons.notifications_outlined));
        await tester.pumpAndSettle();
        expect(find.byType(SharedNotificationsView), findsOneWidget);
        expect(find.text('New Report Submitted'), findsOneWidget);
        expect(find.text('Dispute Opened'), findsOneWidget);

        // Back to the shell; the Activity tab is the report history hub.
        NavigationService.navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Activity'));
        await tester.pumpAndSettle();
        expect(find.byType(ActivityHubView), findsOneWidget);
        expect(find.text('AT-2026-00124'), findsWidgets);
      },
    );

    testWidgets('admin Activity tab lists reports by latest activity', (
      tester,
    ) async {
      final h = await buildHarness(tester, role: UserRole.admin);
      await pumpScreen(tester, h, const ActivityHubView());

      const order = [
        'AT-2026-00124',
        'AT-2026-00126',
        'AT-2026-00128',
        'AT-2026-00125',
        'AT-2026-00127',
      ];
      final offsets = [
        for (final id in order) tester.getTopLeft(find.text(id)).dy,
      ];
      expect([...offsets]..sort(), offsets);

      await tester.tap(find.text('AT-2026-00124'));
      await tester.pumpAndSettle();
      expect(find.byType(ActivityHistoryScreen), findsOneWidget);
      expect(find.text('Report Submitted'), findsOneWidget);
    });
  });

  group('Notification inbox per signed-in user (demo data)', () {
    test('each demo role only sees its own notifications', () async {
      final repo = DataRepository();
      repo.bindNotificationUser(MockData.citizenUser.uid);
      await settle();
      expect(repo.notifications, hasLength(4));
      expect(repo.unreadNotificationCount, 2);
      expect(
        repo.notifications.every(
          (n) => n.recipientUid == MockData.citizenUser.uid,
        ),
        isTrue,
      );

      repo.bindNotificationUser(MockData.technicianUser.uid);
      await settle();
      expect(repo.notifications, isNotEmpty);
      expect(
        repo.notifications.every(
          (n) => n.recipientUid == MockData.technicianUser.uid,
        ),
        isTrue,
      );
      expect(
        repo.notifications.any(
          (n) => n.notificationType == NotificationType.assignment,
        ),
        isTrue,
      );

      repo.bindNotificationUser(MockData.adminUser.uid);
      await settle();
      expect(
        repo.notifications.every(
          (n) => n.recipientUid == MockData.adminUser.uid,
        ),
        isTrue,
      );
      expect(
        repo.notifications.any(
          (n) => n.notificationType == NotificationType.dispute,
        ),
        isTrue,
      );

      repo.bindNotificationUser(null);
      expect(repo.notifications, isEmpty);
      expect(repo.unreadNotificationCount, 0);
    });

    test(
      'the badge count follows read state through the repository API',
      () async {
        final repo = DataRepository();
        repo.bindNotificationUser(MockData.citizenUser.uid);
        await settle();
        expect(repo.unreadNotificationCount, 2);
        await repo.markNotificationAsRead('notif-001');
        expect(repo.unreadNotificationCount, 1);
        await repo.markAllNotificationsAsRead();
        await settle(); // let the gateway's confirming snapshots arrive
        expect(repo.unreadNotificationCount, 0);
      },
    );

    test(
      'history for a report is chronological through the repository',
      () async {
        final repo = DataRepository();
        final events = await repo.watchReportHistory('AT-2026-00124').first;
        expect(events.map((e) => e.title), [
          'Report Submitted',
          'Report Verified',
          'Technician Assigned',
          'Repair Started',
          'Community Verified',
        ]);
        expect([
          for (var i = 1; i < events.length; i++)
            events[i].timestamp.isAfter(events[i - 1].timestamp),
        ], everyElement(isTrue));
      },
    );
  });
}
