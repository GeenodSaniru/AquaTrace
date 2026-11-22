'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const events = require('../notification_events');
const { deliverNotifications, sendToTokens } = require('../delivery');

/** In-memory stand-in for Firestore + FCM. */
function createFakeStore({ users = [], preferences = {}, tokens = {}, failPush = [], failCreate = [], delayFor = {} } = {}) {
  const documents = new Map(); // `${uid}/${id}` -> document (insertion order == creation order)
  const calls = { create: [], push: [], order: [] };
  return {
    documents,
    calls,
    async filterExistingUsers(uids) {
      return new Set(uids.filter((uid) => users.includes(uid)));
    },
    async loadPreferences(uids) {
      const result = {};
      for (const uid of uids) result[uid] = preferences[uid] || {};
      return result;
    },
    async createNotification(uid, id, document) {
      const delay = delayFor[document.title] || 0;
      calls.order.push(`start:${uid}:${document.title}`);
      if (delay) await new Promise((resolve) => setTimeout(resolve, delay));
      if (failCreate.includes(uid)) throw new Error('create failed');
      const key = `${uid}/${id}`;
      calls.create.push(key);
      if (documents.has(key)) return 'exists';
      documents.set(key, document);
      calls.order.push(`end:${uid}:${document.title}`);
      return 'created';
    },
    async sendPush(uid, document) {
      calls.push.push(`${uid}/${document.id}`);
      if (failPush.includes(uid)) throw new Error('fcm down');
    },
    tokens,
  };
}

const silent = { warn() {}, error() {} };
const titlesOf = (store, uid) =>
  [...store.documents.entries()].filter(([key]) => key.startsWith(`${uid}/`)).map(([, doc]) => doc.title);

const base = { reporterUid: 'citizen-1', address: 'Galle Road', faultType: 'pipeLeak', status: 'pending', assignedArea: 'Colombo 03' };

function assignment() {
  return events.buildReportChangeNotifications({
    reportId: 'AT-1',
    before: { ...base },
    after: { ...base, status: 'assigned', assignedTechnicianUid: 'tech-1', assignedTechnicianName: 'Kasun' },
  });
}

test('a recipient\'s notifications are created sequentially in workflow order', async () => {
  // "Report Approved" is deliberately slow: a parallel implementation would let
  // "Technician Assigned" overtake it and be stored first.
  const store = createFakeStore({ users: ['citizen-1', 'tech-1'], delayFor: { 'Report Approved': 30 } });
  await deliverNotifications({ eventId: 'e1', reportId: 'AT-1', planned: assignment(), store, logger: silent });
  assert.deepEqual(titlesOf(store, 'citizen-1'), ['Report Approved', 'Technician Assigned']);
  assert.deepEqual(titlesOf(store, 'tech-1'), ['New Job Assigned']);
});

test('different recipients are processed in parallel', async () => {
  const store = createFakeStore({ users: ['citizen-1', 'tech-1'], delayFor: { 'Report Approved': 40 } });
  await deliverNotifications({ eventId: 'e1', reportId: 'AT-1', planned: assignment(), store, logger: silent });
  const order = store.calls.order;
  // The technician's notification finished before the reporter's slow first item did.
  assert.ok(order.indexOf('end:tech-1:New Job Assigned') < order.indexOf('end:citizen-1:Report Approved'));
});

test('a replayed event creates nothing new and sends no second push', async () => {
  const store = createFakeStore({ users: ['citizen-1', 'tech-1'] });
  const run = () => deliverNotifications({ eventId: 'e1', reportId: 'AT-1', planned: assignment(), store, logger: silent });
  const first = await run();
  const pushesAfterFirst = store.calls.push.length;
  const second = await run();
  assert.equal(first.created.length, 3);
  assert.equal(second.created.length, 0);
  assert.equal(second.existing.length, 3);
  assert.equal(store.documents.size, 3);
  assert.equal(store.calls.push.length, pushesAfterFirst);
});

test('a different trigger event for the same change is a different notification', async () => {
  const store = createFakeStore({ users: ['citizen-1', 'tech-1'] });
  await deliverNotifications({ eventId: 'e1', reportId: 'AT-1', planned: assignment(), store, logger: silent });
  await deliverNotifications({ eventId: 'e2', reportId: 'AT-1', planned: assignment(), store, logger: silent });
  assert.equal(store.documents.size, 6); // genuinely separate events (e.g. a re-assignment)
});

test('logical-id notifications are shared across different trigger events', async () => {
  const planned = events.buildDisputeNotifications({
    reportId: 'AT-1', report: { ...base, assignedTechnicianUid: 'tech-1' }, voterUid: 'v1', adminUids: ['admin-1'],
  });
  const store = createFakeStore({ users: ['citizen-1', 'tech-1', 'admin-1', 'v1'] });
  await deliverNotifications({ eventId: 'trigger-A', reportId: 'AT-1', planned, store, logger: silent });
  await deliverNotifications({ eventId: 'trigger-B', reportId: 'AT-1', planned, store, logger: silent });
  assert.equal(store.documents.size, 4);
});

test('a failed push does not fail delivery or block later notifications', async () => {
  const store = createFakeStore({ users: ['citizen-1', 'tech-1'], failPush: ['citizen-1'] });
  const warnings = [];
  const summary = await deliverNotifications({
    eventId: 'e1', reportId: 'AT-1', planned: assignment(), store,
    logger: { warn: (message) => warnings.push(message), error() {} },
  });
  assert.equal(summary.created.length, 3);
  assert.equal(summary.failed, 0);
  assert.equal(warnings.length, 2); // both of the reporter's pushes failed, both records exist
  assert.deepEqual(titlesOf(store, 'citizen-1'), ['Report Approved', 'Technician Assigned']);
});

test('a failed create for one recipient does not block the others', async () => {
  const store = createFakeStore({ users: ['citizen-1', 'tech-1'], failCreate: ['citizen-1'] });
  const errors = [];
  const summary = await deliverNotifications({
    eventId: 'e1', reportId: 'AT-1', planned: assignment(), store,
    logger: { warn() {}, error: (message) => errors.push(message) },
  });
  assert.equal(summary.failed, 2);
  assert.equal(errors.length, 2);
  assert.deepEqual(titlesOf(store, 'tech-1'), ['New Job Assigned']);
});

test('deleted users are skipped silently', async () => {
  const store = createFakeStore({ users: ['tech-1'] }); // the reporter's account is gone
  const summary = await deliverNotifications({ eventId: 'e1', reportId: 'AT-1', planned: assignment(), store, logger: silent });
  assert.equal(summary.created.length, 1);
  assert.deepEqual(titlesOf(store, 'citizen-1'), []);
});

test('preferences: category off drops the record, push off keeps it without a push', async () => {
  const planned = [
    { recipientUid: 'a', kind: 'k1', type: 'verification', title: 'Verify Repair', body: 'b' },
    { recipientUid: 'a', kind: 'k2', type: 'update', title: 'Repair Started', body: 'b' },
    { recipientUid: 'b', kind: 'k1', type: 'update', title: 'Repair Started', body: 'b' },
  ];
  const store = createFakeStore({
    users: ['a', 'b'],
    preferences: { a: { repairVerification: false }, b: { pushEnabled: false } },
  });
  await deliverNotifications({ eventId: 'e1', reportId: 'AT-1', planned, store, logger: silent });
  assert.deepEqual(titlesOf(store, 'a'), ['Repair Started']);
  assert.deepEqual(titlesOf(store, 'b'), ['Repair Started']);
  assert.equal(store.calls.push.filter((call) => call.startsWith('a/')).length, 1);
  assert.equal(store.calls.push.filter((call) => call.startsWith('b/')).length, 0);
});

test('an empty plan does no work', async () => {
  const store = createFakeStore();
  const summary = await deliverNotifications({ eventId: 'e1', reportId: 'AT-1', planned: [], store, logger: silent });
  assert.deepEqual(summary, { created: [], existing: [], failed: 0 });
  assert.equal(store.calls.create.length, 0);
});

// --- Push token handling -------------------------------------------------------

function fakeMessaging(results) {
  return { sent: [], async sendEachForMulticast(message) { this.sent.push(message); return { responses: results }; } };
}
function tokenEntries(names) {
  const removed = [];
  return { removed, entries: names.map((token) => ({ token, remove: async () => { removed.push(token); } })) };
}
const document = { id: 'n1', title: 'T', body: 'secret body', reportId: 'AT-1', type: 'update', recipientUid: 'u1' };

test('dead tokens are removed, transient failures keep the token, successes are counted', async () => {
  const { entries, removed } = tokenEntries(['ok', 'dead-1', 'dead-2', 'flaky']);
  const messaging = fakeMessaging([
    { success: true },
    { success: false, error: { code: 'messaging/registration-token-not-registered' } },
    { success: false, error: { code: 'messaging/invalid-registration-token' } },
    { success: false, error: { code: 'messaging/internal-error' } },
  ]);
  const result = await sendToTokens({ tokens: entries, document, messaging });
  assert.deepEqual(result, { sent: 1, removed: 2 });
  assert.deepEqual(removed.sort(), ['dead-1', 'dead-2']);
});

test('no tokens means no send', async () => {
  const messaging = fakeMessaging([]);
  assert.deepEqual(await sendToTokens({ tokens: [], document, messaging }), { sent: 0, removed: 0 });
  assert.equal(messaging.sent.length, 0);
});

test('the FCM message never contains the in-app body or the recipient uid', async () => {
  const { entries } = tokenEntries(['t1']);
  const messaging = fakeMessaging([{ success: true }]);
  await sendToTokens({ tokens: entries, document, messaging });
  const serialised = JSON.stringify(messaging.sent[0]);
  assert.equal(serialised.includes('secret body'), false);
  assert.equal(serialised.includes('u1'), false);
  assert.deepEqual(messaging.sent[0].tokens, ['t1']);
});
