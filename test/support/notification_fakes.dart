import 'dart:async';

import 'package:aquatrace/core/constants/fault_constants.dart';
import 'package:aquatrace/core/models/activity_timeline_event.dart';
import 'package:aquatrace/core/models/notification_item.dart';
import 'package:aquatrace/features/notifications/services/push_messaging_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Shared helpers and fakes for the notification / history tests.

NotificationItem note(
  String id, {
  String uid = 'u1',
  bool isRead = false,
  DateTime? at,
  String type = 'update',
  String reportId = 'AT-1',
}) {
  return NotificationItem(
    id: id,
    recipientUid: uid,
    title: 'Title $id',
    body: 'Body $id',
    reportId: reportId,
    type: type,
    isRead: isRead,
    createdAt: at ?? DateTime(2026, 11, 20, 12),
  );
}

ActivityTimelineEvent event(
  String id,
  DateTime at, {
  String reportId = 'AT-1',
}) {
  return ActivityTimelineEvent(
    id: id,
    reportId: reportId,
    title: 'Event $id',
    description: 'd',
    actorName: 'a',
    actorRole: 'Admin',
    status: FaultStatus.pending,
    timestamp: at,
  );
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

/// `DateTime ==` also compares the UTC flag; these tests care about the instant.
Matcher sameMoment(DateTime expected) => predicate<DateTime?>(
  (actual) => actual != null && actual.isAtSameMomentAs(expected),
  'is the instant $expected',
);

// ---------------------------------------------------------------------------
// Push fakes
// ---------------------------------------------------------------------------

class FakePushClient implements PushMessagingClient {
  FakePushClient({
    this.permission = PushPermissionStatus.notDetermined,
    this.requestResult = PushPermissionStatus.granted,
    this.supported = true,
  });

  PushPermissionStatus permission;
  PushPermissionStatus requestResult;
  bool supported;
  Object? supportedError;
  Object? requestError;
  Object? tokenError;
  String? token = 'token-1';
  PushMessage? initialMessage;
  int requestCalls = 0;
  int deleteTokenCalls = 0;

  final refresh = StreamController<String>.broadcast();
  final foreground = StreamController<PushMessage>.broadcast();
  final opened = StreamController<PushMessage>.broadcast();

  @override
  String get platformName => 'android';

  @override
  Future<bool> isSupported() async {
    if (supportedError != null) throw supportedError!;
    return supported;
  }

  @override
  Future<PushPermissionStatus> getPermissionStatus() async => permission;

  @override
  Future<PushPermissionStatus> requestPermission() async {
    requestCalls++;
    if (requestError != null) throw requestError!;
    permission = requestResult;
    return requestResult;
  }

  @override
  Future<String?> getToken() async {
    if (tokenError != null) throw tokenError!;
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => refresh.stream;

  @override
  Stream<PushMessage> get onForegroundMessage => foreground.stream;

  @override
  Stream<PushMessage> get onMessageOpenedApp => opened.stream;

  @override
  Future<PushMessage?> getInitialMessage() async => initialMessage;

  @override
  Future<void> deleteToken() async => deleteTokenCalls++;

  @override
  Future<void> configureForegroundPresentation() async {}
}

class FakeTokenStore implements PushTokenStore {
  final Map<String, Set<String>> tokensByUser = {};
  final Map<String, String> platforms = {};
  Object? upsertFailure;
  Object? removeFailure;

  Set<String> tokensOf(String uid) => tokensByUser[uid] ?? <String>{};

  @override
  Future<void> upsert({
    required String uid,
    required String token,
    required String platform,
  }) async {
    if (upsertFailure != null) throw upsertFailure!;
    tokensByUser.putIfAbsent(uid, () => {}).add(token);
    platforms[token] = platform;
  }

  @override
  Future<void> remove({required String uid, required String token}) async {
    if (removeFailure != null) throw removeFailure!;
    tokensByUser[uid]?.remove(token);
  }
}
