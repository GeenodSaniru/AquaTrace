import 'package:aquatrace/core/constants/app_roles.dart';
import 'package:aquatrace/core/models/notification_item.dart';
import 'package:aquatrace/core/models/report_model.dart';
import 'package:aquatrace/core/navigation/app_router.dart';
import 'package:aquatrace/core/navigation/navigation_service.dart';
import 'package:aquatrace/core/services/auth_service.dart';
import 'package:aquatrace/core/services/data_repository.dart';
import 'package:aquatrace/core/services/preferences_service.dart';
import 'package:aquatrace/core/theme/app_theme.dart';
import 'package:aquatrace/core/theme/theme_provider.dart';
import 'package:aquatrace/features/auth/providers/auth_provider.dart';
import 'package:aquatrace/features/notifications/notification_navigation.dart';
import 'package:aquatrace/features/notifications/services/in_memory_notification_gateway.dart';
import 'package:aquatrace/features/notifications/services/push_messaging_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_fakes.dart';

// Shared widget-test harness: a signed-in demo user, an in-memory notification
// backend, a fake push client and the providers the notification screens need.

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
  List<ReportModel>? reports,
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
  final repo = DataRepository(notificationGateway: gw, initialReports: reports);
  repo.bindNotificationUser(uid);

  final fakeClient =
      client ?? FakePushClient(permission: PushPermissionStatus.granted);
  final tokens = FakeTokenStore();
  final push = PushMessagingService(
    client: fakeClient,
    tokenStore: tokens,
    isUserEnabled: () => pushEnabled,
    onOpenReport: (reportId, notificationId, type) =>
        NotificationNavigation.openReport(repo, reportId, notificationId, type),
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
  Widget home, {
  ThemeData? theme,
}) async {
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
        theme: theme ?? AppTheme.lightTheme,
        navigatorKey: NavigationService.navigatorKey,
        scaffoldMessengerKey: NavigationService.messengerKey,
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: home,
      ),
    ),
  );
  await tester.pump(); // deliver the first notification snapshot
}
