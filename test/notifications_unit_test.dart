import 'package:aquatrace/core/constants/app_roles.dart';
import 'package:aquatrace/core/constants/fault_constants.dart';
import 'package:aquatrace/core/models/activity_timeline_event.dart';
import 'package:aquatrace/core/models/firestore_time.dart';
import 'package:aquatrace/core/models/notification_item.dart';
import 'package:aquatrace/core/services/auth_service.dart';
import 'package:aquatrace/core/services/preferences_service.dart';
import 'package:aquatrace/features/auth/providers/auth_provider.dart';
import 'package:aquatrace/features/notifications/presentation/notification_formatters.dart';
import 'package:aquatrace/features/notifications/services/in_memory_notification_gateway.dart';
import 'package:aquatrace/features/notifications/services/notification_gateway.dart';
import 'package:aquatrace/features/notifications/services/notification_store.dart';
import 'package:aquatrace/features/notifications/services/push_messaging_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/notification_fakes.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Timestamp parsing', () {
    test('accepts Firestore Timestamp, ISO string, DateTime and epoch ms', () {
      final moment = DateTime.utc(2026, 11, 3, 11, 15);
      expect(
        parseFirestoreTime(Timestamp.fromDate(moment)),
        sameMoment(moment),
      );
      expect(
        parseFirestoreTime('2026-11-03T11:15:00.000Z'),
        sameMoment(moment),
      );
      expect(parseFirestoreTime(moment), sameMoment(moment));
      expect(
        parseFirestoreTime(moment.millisecondsSinceEpoch),
        sameMoment(moment),
      );
    });

    test('missing or unreadable values are unknown, never "now"', () {
      for (final bad in [null, '', '   ', 'not a date', 0, -5, 3.5, {}]) {
        expect(parseFirestoreTime(bad), isNull, reason: '$bad');
      }
      final item = NotificationItem.fromMap({'title': 'x'}, documentId: 'n');
      expect(item.hasKnownTime, isFalse);
      expect(isKnownTime(item.createdAt), isFalse);
    });

    test(
      'NotificationItem reads a server Timestamp (previously became "now")',
      () {
        final moment = DateTime.utc(2026, 11, 3, 11, 15);
        final item = NotificationItem.fromMap({
          'recipientUid': 'u1',
          'title': 'T',
          'body': 'B',
          'reportId': 'AT-1',
          'type': 'assignment',
          'isRead': false,
          'createdAt': Timestamp.fromDate(moment),
        }, documentId: 'n1');
        expect(item.createdAt, sameMoment(moment));
        expect(item.notificationType, NotificationType.assignment);
      },
    );

    test('unknown notification types degrade to update', () {
      expect(NotificationType.fromString('brand-new'), NotificationType.update);
      expect(NotificationType.fromString(null), NotificationType.update);
      for (final type in NotificationType.values) {
        expect(NotificationType.fromString(type.value), type);
      }
    });

    test('activity event reads Timestamp and ISO string', () {
      final moment = DateTime.utc(2026, 9, 24, 5, 2);
      final fromTimestamp = ActivityTimelineEvent.fromMap({
        'title': 't',
        'status': 'assigned',
        'timestamp': Timestamp.fromDate(moment),
      }, documentId: 'a');
      final fromIso = ActivityTimelineEvent.fromMap({
        'title': 't',
        'status': 'assigned',
        'timestamp': moment.toIso8601String(),
      }, documentId: 'b');
      expect(fromTimestamp.timestamp, sameMoment(moment));
      expect(fromIso.timestamp, sameMoment(moment));
      expect(fromTimestamp.status, FaultStatus.assigned);
    });
  });

  group('Time formatting', () {
    final now = DateTime(2026, 11, 21, 12);

    test('relative buckets', () {
      String f(Duration ago) =>
          NotificationFormatters.relativeTime(now.subtract(ago), now: now);
      expect(f(Duration.zero), 'Just now');
      expect(f(const Duration(seconds: 59)), 'Just now');
      expect(f(const Duration(minutes: 5)), '5m ago');
      expect(f(const Duration(minutes: 59)), '59m ago');
      expect(f(const Duration(hours: 2)), '2h ago');
      expect(f(const Duration(hours: 23)), '23h ago');
      expect(f(const Duration(days: 2)), '2d ago');
      expect(f(const Duration(days: 6)), '6d ago');
      expect(f(const Duration(days: 10)), '11 Nov 2026');
    });

    test('future (clock skew) and unknown times do not show nonsense', () {
      expect(
        NotificationFormatters.relativeTime(
          now.add(const Duration(hours: 3)),
          now: now,
        ),
        'Just now',
      );
      expect(
        NotificationFormatters.relativeTime(unknownTime, now: now),
        'Time unavailable',
      );
      expect(
        NotificationFormatters.absoluteTime(unknownTime),
        'Time unavailable',
      );
    });

    test('absolute format matches the timeline design', () {
      expect(
        NotificationFormatters.absoluteTime(DateTime(2026, 9, 24, 10, 32)),
        '24 Sep 2026 – 10:32 AM',
      );
      expect(
        NotificationFormatters.absoluteTime(DateTime(2026, 9, 24, 13, 15)),
        '24 Sep 2026 – 1:15 PM',
      );
    });
  });

  group('Report id sanitising for deep links', () {
    test('accepts plain ids and rejects anything else', () {
      expect(sanitizeReportId('AT-2026-00124'), 'AT-2026-00124');
      expect(sanitizeReportId('  abc_DEF-1 '), 'abc_DEF-1');
      for (final bad in [
        null,
        '',
        ' ',
        '../admin',
        'a/b',
        'AT 1',
        '-leading',
        'x' * 65,
        'AT-1?x=1',
      ]) {
        expect(sanitizeReportId(bad), isNull, reason: '$bad');
      }
    });

    test('PushMessage exposes sanitised ids only', () {
      expect(
        const PushMessage(data: {'reportId': 'AT-1', 'notificationId': ' n1 '})
            .reportId,
        'AT-1',
      );
      expect(const PushMessage(data: {'reportId': '../x'}).reportId, isNull);
      expect(
        const PushMessage(data: {'notificationId': ''}).notificationId,
        isNull,
      );
    });
  });

  group('History ordering', () {
    test(
      'events sort oldest first with stable id tie-break; unknown first',
      () {
        final sorted = sortActivityChronologically([
          event('c', DateTime(2026, 9, 24, 15)),
          event('b', DateTime(2026, 9, 24, 11)),
          event('z', DateTime(2026, 9, 24, 11)),
          event('a', unknownTime),
          event('d', DateTime(2026, 9, 24, 10)),
        ]);
        expect(sorted.map((e) => e.id), ['a', 'd', 'b', 'z', 'c']);
      },
    );

    test('notifications sort newest first with unknown times last', () {
      final sorted = sortNotificationsNewestFirst([
        note('old', at: DateTime(2026, 1, 1)),
        note('none', at: unknownTime),
        note('new', at: DateTime(2026, 11, 1)),
      ]);
      expect(sorted.map((n) => n.id), ['new', 'old', 'none']);
    });

    test(
      'in-memory gateway streams history in order and live-appends',
      () async {
        final gateway = InMemoryNotificationGateway()
          ..seedActivity('AT-1', [
            event('2', DateTime(2026, 9, 24, 11)),
            event('1', DateTime(2026, 9, 24, 10)),
          ]);
        final emissions = <List<String>>[];
        final subscription = gateway
            .watchActivity('AT-1')
            .listen(
              (events) => emissions.add(events.map((e) => e.id).toList()),
            );
        await settle();
        gateway.appendActivity(event('3', DateTime(2026, 9, 24, 9)));
        await settle();
        await subscription.cancel();
        expect(emissions.first, ['1', '2']);
        expect(emissions.last, ['3', '1', '2']);
      },
    );
  });

  group('NotificationStore', () {
    late InMemoryNotificationGateway gateway;
    late NotificationStore store;

    setUp(() {
      gateway = InMemoryNotificationGateway(
        seed: {
          'u1': [
            note('a', at: DateTime(2026, 11, 20, 10)),
            note('b', at: DateTime(2026, 11, 20, 12)),
            note('c', at: DateTime(2026, 11, 19), isRead: true),
          ],
          'u2': [note('x', uid: 'u2')],
        },
      );
      store = NotificationStore(gateway: gateway);
    });

    tearDown(() => store.dispose());

    test('empty until a user is bound, then loads newest first', () async {
      expect(store.items, isEmpty);
      expect(store.isLoading, isFalse);
      store.bindUser('u1');
      expect(store.isLoading, isTrue);
      await settle();
      expect(store.isLoading, isFalse);
      expect(store.items.map((n) => n.id), ['b', 'a', 'c']);
      expect(store.unreadCount, 2);
    });

    test(
      'markAsRead updates state and writes once; repeat taps are no-ops',
      () async {
        store.bindUser('u1');
        await settle();
        await store.markAsRead('a');
        expect(store.unreadCount, 1);
        expect(
          gateway.snapshotFor('u1').firstWhere((n) => n.id == 'a').isRead,
          isTrue,
        );
        await store.markAsRead('a'); // already read
        await store.markAsRead('c'); // was read from the start
        await store.markAsRead('missing');
        expect(gateway.markReadCalls, 1);
      },
    );

    test(
      'markAllAsRead clears unread in one batch and is a no-op when empty',
      () async {
        store.bindUser('u1');
        await settle();
        await store.markAllAsRead();
        expect(store.unreadCount, 0);
        expect(gateway.markAllReadCalls, 1);
        await store.markAllAsRead();
        expect(gateway.markAllReadCalls, 1);
      },
    );

    test('failed mark-read rolls back and reports once', () async {
      store.bindUser('u1');
      await settle();
      gateway.markFailure = StateError('offline');
      await store.markAsRead('a');
      expect(store.items.firstWhere((n) => n.id == 'a').isRead, isFalse);
      expect(store.unreadCount, 2);
      expect(store.takeActionError(), contains('Could not update'));
      expect(store.takeActionError(), isNull);

      await store.markAllAsRead();
      expect(store.unreadCount, 2);
      expect(store.takeActionError(), contains('mark notifications as read'));
    });

    test('a new notification delivered by the backend appears live', () async {
      store.bindUser('u1');
      await settle();
      gateway.deliver(note('fresh', at: DateTime(2026, 11, 21)));
      await settle();
      expect(store.items.first.id, 'fresh');
      expect(store.unreadCount, 3);
      // Redelivery with the same id is idempotent (no duplicate).
      gateway.deliver(note('fresh', at: DateTime(2026, 11, 21)));
      await settle();
      expect(store.items.where((n) => n.id == 'fresh'), hasLength(1));
    });

    test('switching or clearing the user never leaks notifications', () async {
      store.bindUser('u1');
      await settle();
      store.bindUser('u2');
      expect(store.items, isEmpty);
      await settle();
      expect(store.items.map((n) => n.id), ['x']);
      gateway.deliver(note('late', uid: 'u1'));
      await settle();
      expect(store.items.map((n) => n.id), ['x']);
      store.bindUser(null);
      expect(store.items, isEmpty);
      expect(store.isLoading, isFalse);
      expect(store.boundUid, isNull);
    });

    test(
      'rollback is skipped if the account changed during the write',
      () async {
        store.bindUser('u1');
        await settle();
        gateway.markFailure = StateError('offline');
        final pending = store.markAsRead('a');
        store.bindUser('u2');
        await pending;
        await settle();
        expect(store.items.map((n) => n.id), ['x']);
      },
    );

    test('stream error shows a message and retry recovers', () async {
      gateway.watchFailure = StateError('boom');
      store.bindUser('u1');
      await settle();
      expect(store.isLoading, isFalse);
      expect(store.errorMessage, isNotNull);
      expect(store.items, isEmpty);

      gateway.watchFailure = null;
      store.retry();
      await settle();
      expect(store.errorMessage, isNull);
      expect(store.items, isNotEmpty);
    });

    test(
      'markReadWhenAvailable defers until the notification arrives',
      () async {
        store.bindUser('u1');
        await settle();
        store.markReadWhenAvailable('later');
        expect(gateway.markReadCalls, 0);
        gateway.deliver(note('later', at: DateTime(2026, 11, 21)));
        await settle();
        await settle();
        expect(
          gateway.snapshotFor('u1').firstWhere((n) => n.id == 'later').isRead,
          isTrue,
        );

        // Loaded id marks immediately.
        store.markReadWhenAvailable('a');
        await settle();
        expect(
          gateway.snapshotFor('u1').firstWhere((n) => n.id == 'a').isRead,
          isTrue,
        );
      },
    );
  });

  group('PushMessagingService', () {
    late FakePushClient client;
    late FakeTokenStore tokens;
    late bool enabled;
    late bool backend;
    late List<(String, String?, NotificationType?)> opened;
    late List<PushMessage> shown;
    late PushMessagingService service;

    PushMessagingService build() {
      return PushMessagingService(
        client: client,
        tokenStore: tokens,
        canUseBackend: (_) => backend,
        isUserEnabled: () => enabled,
        onOpenReport: (reportId, notificationId, type) =>
            opened.add((reportId, notificationId, type)),
        onForegroundMessage: shown.add,
      );
    }

    setUp(() {
      client = FakePushClient();
      tokens = FakeTokenStore();
      enabled = true;
      backend = true;
      opened = [];
      shown = [];
      service = build();
    });

    tearDown(() => service.dispose());

    test(
      'permission denial: no token is registered and status is reported',
      () async {
        client.requestResult = PushPermissionStatus.denied;
        await service.initialize();
        await service.bindUser('u1');
        expect(service.status, PushPermissionStatus.notDetermined);
        expect(service.canPromptForPermission, isTrue);

        final result = await service.requestPermission();
        expect(result, PushPermissionStatus.denied);
        expect(service.status, PushPermissionStatus.denied);
        expect(service.isRegistered, isFalse);
        expect(tokens.tokensOf('u1'), isEmpty);
      },
    );

    test('permission is never requested automatically', () async {
      await service.initialize();
      await service.bindUser('u1');
      await service.refreshStatus();
      expect(client.requestCalls, 0);
    });

    test(
      'granting permission registers the token for the signed-in user',
      () async {
        await service.initialize();
        await service.bindUser('u1');
        expect(tokens.tokensOf('u1'), isEmpty);

        final result = await service.requestPermission();
        expect(result, PushPermissionStatus.granted);
        expect(service.isRegistered, isTrue);
        expect(tokens.tokensOf('u1'), {'token-1'});
        expect(tokens.platforms['token-1'], 'android');
        expect(service.lastError, isNull);
      },
    );

    test('an already-granted permission registers on sign-in', () async {
      client.permission = PushPermissionStatus.granted;
      await service.initialize();
      await service.bindUser('u1');
      expect(tokens.tokensOf('u1'), {'token-1'});
      expect(client.requestCalls, 0);
    });

    test(
      'token refresh stores the new token and removes the old one',
      () async {
        client.permission = PushPermissionStatus.granted;
        await service.initialize();
        await service.bindUser('u1');
        client.refresh.add('token-2');
        await settle();
        await settle();
        expect(tokens.tokensOf('u1'), {'token-2'});
        expect(service.currentToken, 'token-2');
      },
    );

    test('token refresh is ignored when signed out or push is off', () async {
      client.permission = PushPermissionStatus.granted;
      await service.initialize();
      client.refresh.add('orphan');
      await settle();
      expect(tokens.tokensByUser, isEmpty);

      await service.bindUser('u1');
      enabled = false;
      client.refresh.add('while-off');
      await settle();
      expect(tokens.tokensOf('u1'), {'token-1'});
    });

    test(
      'unregister removes the token and invalidates the device token',
      () async {
        client.permission = PushPermissionStatus.granted;
        await service.initialize();
        await service.bindUser('u1');
        await service.unregister();
        expect(tokens.tokensOf('u1'), isEmpty);
        expect(service.isRegistered, isFalse);
        expect(client.deleteTokenCalls, 1);

        // A refresh emitted by the SDK after deleteToken must not re-register.
        client.refresh.add('regenerated');
        await settle();
        expect(tokens.tokensOf('u1'), isEmpty);
      },
    );

    test(
      'unregister survives backend failures (e.g. already signed out)',
      () async {
        client.permission = PushPermissionStatus.granted;
        await service.initialize();
        await service.bindUser('u1');
        tokens.removeFailure = StateError('permission-denied');
        await service.unregister();
        expect(client.deleteTokenCalls, 1); // device token still invalidated
      },
    );

    test(
      'switching accounts discards the previous token before registering',
      () async {
        client.permission = PushPermissionStatus.granted;
        await service.initialize();
        await service.bindUser('u1');
        client.token = 'token-for-u2';
        await service.bindUser('u2');
        expect(tokens.tokensOf('u1'), isEmpty);
        expect(tokens.tokensOf('u2'), {'token-for-u2'});
        expect(client.deleteTokenCalls, 1);
      },
    );

    test('signing out clears registration state', () async {
      client.permission = PushPermissionStatus.granted;
      await service.initialize();
      await service.bindUser('u1');
      await service.unregister();
      await service.bindUser(null);
      expect(service.isRegistered, isFalse);
    });

    test('turning the preference off unregisters; on re-registers', () async {
      client.permission = PushPermissionStatus.granted;
      await service.initialize();
      await service.bindUser('u1');
      enabled = false;
      await service.onPreferenceChanged();
      expect(tokens.tokensOf('u1'), isEmpty);
      expect(client.deleteTokenCalls, 1);

      enabled = true;
      await service.onPreferenceChanged();
      expect(tokens.tokensOf('u1'), {'token-1'});
    });

    test('preference changes while signed out do nothing', () async {
      client.permission = PushPermissionStatus.granted;
      await service.initialize();
      await service.onPreferenceChanged();
      enabled = false;
      await service.onPreferenceChanged();
      expect(client.deleteTokenCalls, 0);
      expect(tokens.tokensByUser, isEmpty);
    });

    test(
      'push is off for a user who disabled it, even with OS permission',
      () async {
        enabled = false;
        client.permission = PushPermissionStatus.granted;
        await service.initialize();
        await service.bindUser('u1');
        expect(tokens.tokensByUser, isEmpty);
      },
    );

    test(
      'demo identities (no backend session) never register a token',
      () async {
        backend = false;
        client.permission = PushPermissionStatus.granted;
        await service.initialize();
        await service.bindUser('demo-citizen-001');
        await service.requestPermission();
        expect(tokens.tokensByUser, isEmpty);
        expect(service.isRegistered, isFalse);
      },
    );

    test('registration failures are reported, not thrown', () async {
      client.permission = PushPermissionStatus.granted;
      tokens.upsertFailure = StateError('offline');
      await service.initialize();
      await service.bindUser('u1');
      expect(service.isRegistered, isFalse);
      expect(service.lastError, isNotNull);

      tokens.upsertFailure = null;
      client.token = null;
      await service.refreshStatus();
      expect(service.lastError, contains('did not return a push token'));

      client.token = 'token-1';
      await service.refreshStatus();
      expect(service.lastError, isNull);
      expect(service.isRegistered, isTrue);
    });

    test('a permission request that throws leaves status intact', () async {
      client.requestError = StateError('plugin');
      await service.initialize();
      await service.bindUser('u1');
      final result = await service.requestPermission();
      expect(result, PushPermissionStatus.notDetermined);
      expect(service.lastError, isNotNull);
    });

    test(
      'unsupported platforms/builds report unsupported and register nothing',
      () async {
        client.supported = false;
        await service.initialize();
        await service.bindUser('u1');
        expect(service.status, PushPermissionStatus.unsupported);
        expect(
          await service.requestPermission(),
          PushPermissionStatus.unsupported,
        );
        expect(client.requestCalls, 0);

        final unsupported = PushMessagingService(
          client: const UnsupportedPushMessagingClient(),
          tokenStore: tokens,
        );
        await unsupported.initialize();
        expect(unsupported.status, PushPermissionStatus.unsupported);
        unsupported.dispose();
      },
    );

    test('initialisation failure is contained', () async {
      client.supportedError = StateError('no plugin');
      await service.initialize();
      expect(service.status, PushPermissionStatus.unsupported);
    });

    test('tapping a push while signed in opens the report once', () async {
      await service.initialize();
      await service.bindUser('u1');
      client.opened.add(
        const PushMessage(
          data: {
            'reportId': 'AT-7',
            'notificationId': 'n7',
            'type': 'verification',
          },
        ),
      );
      await settle();
      expect(opened, [('AT-7', 'n7', NotificationType.verification)]);
    });

    test('a push tapped while signed out waits for sign-in', () async {
      client.initialMessage = const PushMessage(
        data: {'reportId': 'AT-8', 'notificationId': 'n8'},
      );
      await service.initialize(); // cold start from the notification
      expect(opened, isEmpty);
      await service.bindUser('u1');
      expect(opened, [('AT-8', 'n8', null)]);
      // Consumed: a later account change must not replay it.
      await service.bindUser(null);
      await service.bindUser('u2');
      expect(opened, hasLength(1));
    });

    test('malformed or missing report ids in a push are ignored', () async {
      await service.initialize();
      await service.bindUser('u1');
      client.opened
        ..add(const PushMessage(data: {'reportId': '../../admin'}))
        ..add(const PushMessage(data: {}))
        ..add(const PushMessage(data: {'reportId': 'a b'}));
      await settle();
      expect(opened, isEmpty);
    });

    test('foreground messages are surfaced only while signed in', () async {
      await service.initialize();
      client.foreground.add(const PushMessage(title: 'Hi'));
      await settle();
      expect(shown, isEmpty);
      await service.bindUser('u1');
      client.foreground.add(const PushMessage(title: 'Hi', body: 'There'));
      await settle();
      expect(shown.single.title, 'Hi');
    });
  });

  group('AuthProvider sign-out hook', () {
    Future<AuthProvider> signedIn() async {
      final prefs = PreferencesService(await SharedPreferences.getInstance());
      final provider = AuthProvider(AuthService(prefs));
      await provider.signInWithDemoRole(UserRole.citizen);
      return provider;
    }

    test('runs before the session ends', () async {
      final provider = await signedIn();
      var sawSession = false;
      provider.beforeSignOut = () async {
        sawSession = provider.isAuthenticated;
      };
      await provider.signOut();
      expect(sawSession, isTrue);
      expect(provider.isAuthenticated, isFalse);
    });

    test('a failing cleanup never blocks sign-out', () async {
      final provider = await signedIn();
      provider.beforeSignOut = () async => throw StateError('cleanup failed');
      await provider.signOut();
      expect(provider.isAuthenticated, isFalse);
    });
  });
}
