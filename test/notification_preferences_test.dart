import 'dart:async';

import 'package:aquatrace/features/notifications/services/notification_preferences_sync.dart';
import 'package:aquatrace/features/notifications/services/push_messaging_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/notification_fakes.dart';

class _FakePreferencesStore implements NotificationPreferencesStore {
  final List<(String, NotificationPreferences)> saves = [];
  Object? failure;
  Completer<void>? gate;

  @override
  Future<void> save(String uid, NotificationPreferences preferences) async {
    saves.add((uid, preferences));
    final pending = gate;
    if (pending != null) await pending.future;
    final error = failure;
    if (error != null) throw error;
  }
}

class _Choices {
  bool push = true;
  bool verification = true;
  bool nearby = true;

  NotificationPreferences read() => NotificationPreferences(
    pushEnabled: push,
    repairVerification: verification,
    nearbyFaults: nearby,
  );
}

void main() {
  group('NotificationPreferences', () {
    test('serialises exactly the fields the rules accept', () {
      expect(
        const NotificationPreferences(
          pushEnabled: false,
          repairVerification: true,
          nearbyFaults: false,
        ).toMap(),
        {
          'pushEnabled': false,
          'repairVerification': true,
          'nearbyFaults': false,
        },
      );
    });

    test('has value equality', () {
      const a = NotificationPreferences(
        pushEnabled: true,
        repairVerification: true,
        nearbyFaults: true,
      );
      const b = NotificationPreferences(
        pushEnabled: true,
        repairVerification: true,
        nearbyFaults: true,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          const NotificationPreferences(
            pushEnabled: false,
            repairVerification: true,
            nearbyFaults: true,
          ),
        ),
      );
    });
  });

  group('NotificationPreferencesSync', () {
    late _FakePreferencesStore store;
    late _Choices choices;
    late bool backend;
    late NotificationPreferencesSync sync;

    NotificationPreferencesSync build({
      Duration retryDelay = const Duration(milliseconds: 20),
      int maxRetries = 5,
    }) => NotificationPreferencesSync(
      store: store,
      read: choices.read,
      canUseBackend: (_) => backend,
      retryDelay: retryDelay,
      maxRetries: maxRetries,
    );

    setUp(() {
      store = _FakePreferencesStore();
      choices = _Choices();
      backend = true;
      sync = build();
    });

    tearDown(() => sync.dispose());

    test('signing in writes the current choices for that user only', () async {
      await sync.bindUser('u1');
      expect(store.saves, hasLength(1));
      expect(store.saves.single.$1, 'u1');
      expect(store.saves.single.$2, choices.read());
    });

    test('unchanged choices are not written again', () async {
      await sync.bindUser('u1');
      await sync.sync();
      await sync.sync();
      expect(store.saves, hasLength(1));
    });

    test('a changed choice is written', () async {
      await sync.bindUser('u1');
      choices.verification = false;
      await sync.sync();
      expect(store.saves, hasLength(2));
      expect(store.saves.last.$2.repairVerification, isFalse);
      expect(store.saves.last.$2.pushEnabled, isTrue);
    });

    test(
      'signed out or without a backend session nothing is written',
      () async {
        await sync.sync(); // not bound
        expect(store.saves, isEmpty);

        backend = false; // demo identity
        await sync.bindUser('demo-citizen-001');
        choices.push = false;
        await sync.sync();
        expect(store.saves, isEmpty);

        await sync.bindUser(null);
        await sync.sync();
        expect(store.saves, isEmpty);
      },
    );

    test(
      'signing in as someone else writes for them, not the previous user',
      () async {
        await sync.bindUser('u1');
        await sync.bindUser(null);
        choices.nearby = false;
        await sync.bindUser('u2');
        expect(store.saves.map((s) => s.$1), ['u1', 'u2']);
        expect(store.saves.last.$2.nearbyFaults, isFalse);
      },
    );

    test(
      'a failed write is remembered and retried until it succeeds',
      () async {
        store.failure = StateError('offline');
        await sync.bindUser('u1');
        expect(sync.hasPendingChange, isTrue);
        expect(sync.lastError, isNotNull);

        store.failure = null;
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(store.saves.length, greaterThanOrEqualTo(2));
        expect(sync.hasPendingChange, isFalse);
        expect(sync.lastError, isNull);
      },
    );

    test('retries are bounded', () async {
      sync.dispose();
      sync = build(retryDelay: const Duration(milliseconds: 5), maxRetries: 2);
      store.failure = StateError('down');
      await sync.bindUser('u1');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      // 1 initial attempt + 2 retries, then it stops.
      expect(store.saves, hasLength(3));
      expect(sync.hasPendingChange, isTrue);
    });

    test('the latest choice wins when it changes during a write', () async {
      final gate = Completer<void>();
      store.gate = gate;
      final first = sync.bindUser('u1'); // write 1 blocked on the gate
      await settle();
      choices.push = false; // newer choice while write 1 is in flight
      unawaited(sync.sync());
      store.gate = null;
      gate.complete();
      await first;
      await settle();
      await settle();
      expect(store.saves.last.$2.pushEnabled, isFalse);
    });

    test('an account change during a write is not recorded as synced for the new user', () async {
      final gate = Completer<void>();
      store.gate = gate;
      final pending = sync.bindUser('u1');
      await settle();
      store.gate = null;
      await sync.bindUser('u2'); // switches while u1's write is in flight
      gate.complete();
      await pending;
      await settle();
      // u2 got its own write; nothing was skipped because of u1's.
      expect(store.saves.where((s) => s.$1 == 'u2'), hasLength(1));
    });
  });

  group('Push message de-duplication', () {
    late FakePushClient client;
    late FakeTokenStore tokens;
    late DateTime now;
    late List<String> opened;
    late List<String> shown;
    late PushMessagingService service;

    setUp(() async {
      client = FakePushClient(permission: PushPermissionStatus.granted);
      tokens = FakeTokenStore();
      now = DateTime(2026, 11, 22, 9);
      opened = [];
      shown = [];
      service = PushMessagingService(
        client: client,
        tokenStore: tokens,
        clock: () => now,
        onOpenReport: (reportId, notificationId, type) =>
            opened.add('$reportId/$notificationId'),
        onForegroundMessage: (message) => shown.add(message.messageId ?? '?'),
      );
      await service.initialize();
      await service.bindUser('u1');
    });

    tearDown(() => service.dispose());

    PushMessage message({String? id = 'm1', String notification = 'n1'}) =>
        PushMessage(
          messageId: id,
          title: 'T',
          data: {'reportId': 'AT-1', 'notificationId': notification},
        );

    test(
      'the same foreground message delivered twice shows one banner',
      () async {
        client.foreground
          ..add(message())
          ..add(message());
        await settle();
        expect(shown, ['m1']);
      },
    );

    test(
      'a duplicate open report (cold start + opened-app) navigates once',
      () async {
        client.opened
          ..add(message())
          ..add(message());
        await settle();
        expect(opened, ['AT-1/n1']);
      },
    );

    test('opening the same notification again later is allowed', () async {
      client.opened.add(message());
      await settle();
      now = now.add(
        PushMessagingService.duplicateWindow + const Duration(seconds: 1),
      );
      client.opened.add(message());
      await settle();
      expect(opened, ['AT-1/n1', 'AT-1/n1']);
    });

    test('different messages are never suppressed', () async {
      client.foreground
        ..add(message(id: 'a', notification: 'n1'))
        ..add(message(id: 'b', notification: 'n2'));
      await settle();
      expect(shown, ['a', 'b']);
    });

    test(
      'messages without any id cannot be de-duplicated, so none are dropped',
      () async {
        const anonymous = PushMessage(title: 'T', data: {'reportId': 'AT-1'});
        client.foreground
          ..add(anonymous)
          ..add(anonymous);
        await settle();
        expect(shown, hasLength(2));
      },
    );
  });
}
