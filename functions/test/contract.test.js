'use strict';

/**
 * Cross-checks the three places that must agree about document shapes:
 *   - the Dart models / gateways (what the app writes and reads),
 *   - firestore.rules (what clients are allowed to write),
 *   - notification_events.js (what the trusted backend writes).
 *
 * These are static source checks (no emulator needed). They exist because a
 * mismatch between the app and the rules is invisible to the Dart tests and
 * only shows up as permission-denied in production.
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..', '..');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8').replace(/\r\n/g, '\n');

const events = require('../notification_events');

/** Quoted keys of the first `{ ... }` map literal found after [marker]. */
function mapKeysAfter(source, marker) {
  const start = source.indexOf(marker);
  assert.notEqual(start, -1, `marker not found: ${marker}`);
  const open = source.indexOf('{', start + marker.length);
  let depth = 0;
  let end = open;
  for (let i = open; i < source.length; i += 1) {
    if (source[i] === '{') depth += 1;
    if (source[i] === '}') {
      depth -= 1;
      if (depth === 0) {
        end = i;
        break;
      }
    }
  }
  const body = source.slice(open, end);
  return [...body.matchAll(/'(\w+)'\s*:/g)].map((match) => match[1]);
}

/** Keys of the `hasOnly([...])` list inside the rules block starting at [marker]. */
function rulesAllowedKeys(rules, marker) {
  const start = rules.indexOf(marker);
  assert.notEqual(start, -1, `rules block not found: ${marker}`);
  const hasOnly = rules.indexOf('hasOnly([', start);
  const close = rules.indexOf('])', hasOnly);
  return [...rules.slice(hasOnly, close).matchAll(/'(\w+)'/g)].map((match) => match[1]);
}

const rules = read('firestore.rules');

test('vote documents written by the app are accepted by the rules', () => {
  const written = mapKeysAfter(read('lib/core/models/verification_vote_model.dart'), 'toMap()');
  const allowed = rulesAllowedKeys(rules, 'match /verifications/{voterUid}');
  assert.ok(written.length > 0);
  for (const key of written) assert.ok(allowed.includes(key), `rules reject vote field "${key}"`);
});

test('dispute documents written by the app are accepted by the rules', () => {
  const written = mapKeysAfter(read('lib/core/models/dispute_record_model.dart'), 'toMap()');
  const allowed = rulesAllowedKeys(rules, 'match /disputes/{voterUid}');
  assert.ok(written.length > 0);
  for (const key of written) assert.ok(allowed.includes(key), `rules reject dispute field "${key}"`);
});

test('device tokens written by the app are accepted by the rules', () => {
  const source = read('lib/features/notifications/services/push_messaging_service.dart');
  const created = mapKeysAfter(source, 'await ref.set(');
  const allowed = rulesAllowedKeys(rules, 'match /fcmTokens/{token}');
  assert.deepEqual([...created].sort(), [...allowed].sort());
});

test('the app does not write counters, status or activity when voting or disputing', () => {
  const gateway = read('lib/core/services/community_verification_gateway.dart');
  const submit = gateway.slice(gateway.indexOf('submitVerification({', gateway.indexOf('class Firebase')));
  const writes = submit.slice(0, submit.indexOf('uploadDisputePhoto'));
  // Only vote / dispute documents may be written by clients (rules forbid the rest).
  assert.equal(/transaction\.update\(/.test(writes), false, 'client must not update the report');
  assert.equal(/collection\('activity'\)/.test(writes), false, 'client must not write activity');
  assert.equal(/\.set\(/.test(writes.replace(/transaction\.set\((voteRef|disputeRef)/g, '')), false);
});

test('rules keep counters, notifications and activity out of clients\' hands', () => {
  const notifications = rules.slice(rules.indexOf('match /notifications/{notificationId}'));
  assert.match(notifications.slice(0, notifications.indexOf('allow delete')), /allow create: if false;/);
  assert.match(rules, /match \/verifications\/\{voterUid\}[\s\S]*?allow update, delete: if false;/);
});

test('notification documents written by the backend match what the client reads', () => {
  const document = events.toNotificationDocument('id', 'AT-1', {
    recipientUid: 'u', title: 't', body: 'b', type: 'update',
  });
  const dart = read('lib/core/models/notification_item.dart');
  const clientReads = [...dart.slice(dart.indexOf('factory NotificationItem.fromMap')).matchAll(/map\['(\w+)'\]/g)].map(
    (match) => match[1],
  );
  // The backend adds createdAt (server timestamp) separately.
  const serverKeys = [...Object.keys(document), 'createdAt'];
  for (const key of serverKeys) assert.ok(clientReads.includes(key), `client ignores "${key}"`);
  for (const key of new Set(clientReads)) assert.ok(serverKeys.includes(key), `backend omits "${key}"`);
});

test('audit events written by the backend match what the client reads', () => {
  const dart = read('lib/core/models/activity_timeline_event.dart');
  const clientReads = new Set(
    [...dart.slice(dart.indexOf('factory ActivityTimelineEvent.fromMap')).matchAll(/map\['(\w+)'\]/g)].map(
      (match) => match[1],
    ),
  );
  for (const activity of [
    events.buildVerificationActivity({ reportId: 'AT-1', voterUid: 'v' }),
    events.buildMilestoneActivity({ reportId: 'AT-1' }),
    events.buildDisputeActivity({ reportId: 'AT-1', voterUid: 'v' }),
  ]) {
    // id is the document id; the server adds `timestamp`.
    for (const key of [...Object.keys(activity), 'timestamp']) {
      assert.ok(clientReads.has(key) || key === 'id', `client ignores "${key}"`);
    }
    assert.ok(['pending', 'assigned', 'ongoing', 'completed', 'disputed'].includes(activity.status));
  }
});

test('notification types used by the backend are exactly the types the client understands', () => {
  const dart = read('lib/core/models/notification_item.dart');
  const clientTypes = [...dart.matchAll(/^\s+\w+\('(\w+)'\)[,;]/gm)].map((match) => match[1]);
  assert.deepEqual([...clientTypes].sort(), [...events.VALID_TYPES].sort());
});

test('the server verification threshold default matches the app default', () => {
  const dart = read('lib/features/verification/services/community_verification_service.dart');
  const match = dart.match(/_configuredThreshold\s*=\s*(\d+)/);
  assert.ok(match, 'threshold constant not found in the app');
  assert.equal(Number(match[1]), events.DEFAULT_VERIFICATION_THRESHOLD);
});
