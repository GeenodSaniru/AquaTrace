'use strict';

/**
 * Replays the whole report lifecycle through the real planners and the real
 * delivery logic (with an in-memory store) and checks who is notified, with
 * what, and in which order. The expected per-recipient lists mirror the Dart
 * test `test/lifecycle_history_test.dart` (demo backend), so the app's demo
 * flow and the backend rules cannot silently drift apart.
 */

const test = require('node:test');
const assert = require('node:assert/strict');

const events = require('../notification_events');
const { deliverNotifications } = require('../delivery');

const silent = { warn() {}, error() {} };

function createStore(users) {
  const documents = []; // creation order
  const ids = new Set();
  return {
    documents,
    async filterExistingUsers(uids) {
      return new Set(uids.filter((uid) => users.includes(uid)));
    },
    async loadPreferences() {
      return {};
    },
    async createNotification(uid, id, document) {
      const key = `${uid}/${id}`;
      if (ids.has(key)) return 'exists';
      ids.add(key);
      documents.push({ uid, ...document });
      return 'created';
    },
    async sendPush() {},
  };
}

/** Newest-first titles a user would see in their inbox for [reportId]. */
const inbox = (store, uid) =>
  store.documents
    .filter((doc) => doc.recipientUid === uid && doc.reportId === 'AT-LC-1')
    .map((doc) => doc.title)
    .reverse();

const REPORTER = 'reporter-lc';
const TECH = 'tech-lc';
const ADMIN = 'admin-1';
const NEIGHBOURS = ['neighbour-1', 'voter-1', 'voter-2', 'voter-3', 'disputer'];
const USERS = [REPORTER, TECH, ADMIN, ...NEIGHBOURS, 'bystander-elsewhere'];

const submitted = {
  reporterUid: REPORTER,
  address: 'Galle Road, Colombo 03',
  faultType: 'pipeLeak',
  assignedArea: 'Colombo 03',
  isEmergency: false,
  status: 'pending',
  verificationCount: 0,
  disputeCount: 0,
};

async function runLifecycle(store, { replay = false } = {}) {
  const log = [];
  const send = async (eventId, planned) => {
    log.push(await deliverNotifications({ eventId, reportId: 'AT-LC-1', planned, store, logger: silent }));
    if (replay) log.push(await deliverNotifications({ eventId, reportId: 'AT-LC-1', planned, store, logger: silent }));
  };

  // 1. Citizen submits.
  await send('evt-1', events.buildNewReportNotifications({ reportId: 'AT-LC-1', report: submitted, adminUids: [ADMIN] }));

  // 2. Admin approves and assigns.
  const assigned = { ...submitted, status: 'assigned', assignedTechnicianUid: TECH, assignedTechnicianName: 'Tech LC' };
  await send('evt-2', events.buildReportChangeNotifications({ reportId: 'AT-LC-1', before: submitted, after: assigned, adminUids: [ADMIN] }));

  // 3. Technician starts.
  const ongoing = { ...assigned, status: 'ongoing' };
  await send('evt-3', events.buildReportChangeNotifications({ reportId: 'AT-LC-1', before: assigned, after: ongoing, adminUids: [ADMIN] }));

  // 4. Technician completes (everyone in the service area is a candidate verifier).
  let report = { ...ongoing, status: 'completed' };
  await send(
    'evt-4',
    events.buildReportChangeNotifications({
      reportId: 'AT-LC-1', before: ongoing, after: report, adminUids: [ADMIN], nearbyCitizenUids: [REPORTER, ...NEIGHBOURS],
    }),
  );

  // 5. Three neighbours confirm; the server counts each vote.
  for (const [index, voter] of ['voter-1', 'voter-2', 'voter-3'].entries()) {
    const update = events.planVerificationCount(report);
    assert.ok(update, 'a completed repair accepts verification votes');
    report = { ...report, verificationCount: update.newCount };
    await send(
      `evt-vote-${index}`,
      events.buildVerificationNotifications({ reportId: 'AT-LC-1', report, voterUid: voter, newCount: update.newCount, adminUids: [ADMIN] }),
    );
  }

  // 6. A resident disputes: the server reopens the report.
  const reopen = events.planDisputeUpdate(report);
  assert.deepEqual(reopen, { newCount: 1, status: 'disputed' });
  report = { ...report, status: reopen.status, disputeCount: reopen.newCount };
  await send('evt-dispute', events.buildDisputeNotifications({ reportId: 'AT-LC-1', report, voterUid: 'disputer', adminUids: [ADMIN] }));
  // The counter/status update by the function re-triggers the report-update planner: nothing more.
  const reTrigger = events.buildReportChangeNotifications({
    reportId: 'AT-LC-1', before: { ...report, status: 'completed' }, after: report, adminUids: [ADMIN],
  });
  assert.deepEqual(reTrigger, []);
  return log;
}

test('every recipient receives the right notifications in the right order', async () => {
  const store = createStore(USERS);
  await runLifecycle(store);

  // Identical to the Dart demo-backend expectations.
  assert.deepEqual(inbox(store, REPORTER), [
    'Dispute Opened', 'Repair Verified', 'Repair Completed', 'Repair Started', 'Technician Assigned', 'Report Approved',
  ]);
  assert.deepEqual(inbox(store, TECH), ['Repair Disputed', 'Repair Verified by Community', 'New Job Assigned']);
  assert.deepEqual(inbox(store, ADMIN), [
    'Dispute Raised', 'Repair Verified by Community', 'Repair Completed', 'New Report Submitted',
  ]);
  assert.deepEqual(inbox(store, 'neighbour-1'), ['Verify Repair']);
  assert.deepEqual(inbox(store, 'disputer'), ['Dispute Submitted', 'Verify Repair']);
  assert.deepEqual(inbox(store, 'voter-1'), ['Verify Repair']);
  assert.deepEqual(inbox(store, 'bystander-elsewhere'), []);
});

test('the reporter is never asked to verify their own repair and the technician never verifies their own work', async () => {
  const store = createStore(USERS);
  await runLifecycle(store);
  for (const uid of [REPORTER, TECH]) {
    assert.equal(inbox(store, uid).includes('Verify Repair'), false, uid);
  }
});

test('replaying every event (retries / duplicate triggers) changes nothing', async () => {
  const once = createStore(USERS);
  await runLifecycle(once);
  const twice = createStore(USERS);
  const log = await runLifecycle(twice, { replay: true });
  assert.equal(twice.documents.length, once.documents.length);
  assert.deepEqual(
    twice.documents.map((doc) => doc.id),
    once.documents.map((doc) => doc.id),
  );
  // Every replay found only existing documents.
  const replays = log.filter((_, index) => index % 2 === 1);
  assert.ok(replays.every((summary) => summary.created.length === 0));
});

test('a fourth confirmation does not announce the milestone again', async () => {
  const store = createStore(USERS);
  await runLifecycle(store);
  const before = store.documents.length;
  const report = { ...submitted, status: 'completed', assignedTechnicianUid: TECH, verificationCount: 3 };
  const update = events.planVerificationCount(report);
  assert.equal(update.newCount, 4);
  await deliverNotifications({
    eventId: 'evt-vote-late',
    reportId: 'AT-LC-1',
    planned: events.buildVerificationNotifications({ reportId: 'AT-LC-1', report, voterUid: 'late', newCount: 4, adminUids: [ADMIN] }),
    store,
    logger: silent,
  });
  assert.equal(store.documents.length, before);
});

test('a deleted report or deleted users produce no notifications and no errors', async () => {
  const store = createStore([ADMIN]); // reporter and technician accounts deleted
  await deliverNotifications({
    eventId: 'evt-x', reportId: 'AT-LC-1', store, logger: silent,
    planned: events.buildDisputeNotifications({ reportId: 'AT-LC-1', report: { ...submitted, assignedTechnicianUid: TECH }, voterUid: 'gone', adminUids: [ADMIN] }),
  });
  assert.deepEqual(store.documents.map((doc) => doc.recipientUid), [ADMIN]);
  // Report deleted: the planners receive no report and plan nothing.
  assert.deepEqual(events.buildDisputeNotifications({ reportId: 'AT-LC-1', report: undefined, voterUid: 'v' }), []);
});
