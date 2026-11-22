'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  buildReportChangeNotifications,
  buildNewReportNotifications,
  buildVerificationNotifications,
  buildDisputeNotifications,
  planVerificationCount,
  planDisputeUpdate,
  buildVerificationActivity,
  buildMilestoneActivity,
  buildDisputeActivity,
  categoryOf,
  applyPreferences,
  notificationId,
  toNotificationDocument,
  pushText,
  buildPushMessage,
  VALID_TYPES,
  MAX_NEARBY_CITIZENS,
} = require('../notification_events');

const base = {
  reporterUid: 'citizen-1',
  address: 'Galle Road, Colombo 03',
  faultType: 'pipeLeak',
  status: 'pending',
};

const byRecipient = (list, uid) => list.filter((n) => n.recipientUid === uid);

// --- Report status changes (Members 3, 5, 6) ----------------------------------

test('pending -> assigned: reporter gets approval + assignment, technician gets the job', () => {
  const planned = buildReportChangeNotifications({
    reportId: 'AT-1',
    before: { ...base },
    after: {
      ...base,
      status: 'assigned',
      assignedTechnicianUid: 'tech-1',
      assignedTechnicianName: 'Kasun Jayawardena',
    },
  });

  const reporter = byRecipient(planned, 'citizen-1');
  assert.deepEqual(reporter.map((n) => n.type).sort(), ['approval', 'assignment']);
  assert.match(
    reporter.find((n) => n.type === 'assignment').body,
    /assigned to Kasun Jayawardena/,
  );
  const technician = byRecipient(planned, 'tech-1');
  assert.equal(technician.length, 1);
  assert.equal(technician[0].type, 'assignment');
  assert.match(technician[0].body, /AT-1 at Galle Road, Colombo 03/);
});

test('re-assignment to another technician notifies without a second approval', () => {
  const planned = buildReportChangeNotifications({
    reportId: 'AT-1',
    before: { ...base, status: 'assigned', assignedTechnicianUid: 'tech-1' },
    after: { ...base, status: 'assigned', assignedTechnicianUid: 'tech-2', assignedTechnicianName: 'Nimal' },
  });
  assert.equal(planned.some((n) => n.type === 'approval'), false);
  assert.equal(byRecipient(planned, 'tech-2').length, 1);
  assert.equal(byRecipient(planned, 'citizen-1').length, 1);
});

test('disputed -> assigned (reopened job) does not claim a fresh approval', () => {
  const planned = buildReportChangeNotifications({
    reportId: 'AT-1',
    before: { ...base, status: 'disputed', assignedTechnicianUid: 'tech-1' },
    after: { ...base, status: 'assigned', assignedTechnicianUid: 'tech-1', assignedTechnicianName: 'Kasun' },
  });
  assert.equal(planned.some((n) => n.type === 'approval'), false);
  assert.ok(planned.some((n) => n.recipientUid === 'tech-1' && n.type === 'assignment'));
});

test('assigned -> ongoing: repair status update for the reporter only', () => {
  const planned = buildReportChangeNotifications({
    reportId: 'AT-1',
    before: { ...base, status: 'assigned', assignedTechnicianUid: 'tech-1' },
    after: { ...base, status: 'ongoing', assignedTechnicianUid: 'tech-1' },
    adminUids: ['admin-1'],
  });
  assert.equal(planned.length, 1);
  assert.equal(planned[0].recipientUid, 'citizen-1');
  assert.equal(planned[0].type, 'update');
  assert.equal(planned[0].title, 'Repair Started');
});

test('ongoing -> completed: reporter informed (not asked to verify), admins informed, nearby citizens asked', () => {
  const planned = buildReportChangeNotifications({
    reportId: 'AT-1',
    before: { ...base, status: 'ongoing', assignedTechnicianUid: 'tech-1' },
    after: { ...base, status: 'completed', assignedTechnicianUid: 'tech-1', assignedTechnicianName: 'Kasun' },
    adminUids: ['admin-1', 'admin-2'],
    nearbyCitizenUids: ['near-1', 'near-2'],
  });
  // The reporter may not verify their own report, so they get an update.
  assert.equal(byRecipient(planned, 'citizen-1')[0].type, 'update');
  assert.equal(byRecipient(planned, 'citizen-1')[0].title, 'Repair Completed');
  assert.equal(byRecipient(planned, 'admin-1')[0].type, 'update');
  assert.equal(byRecipient(planned, 'admin-2').length, 1);
  for (const uid of ['near-1', 'near-2']) {
    assert.equal(byRecipient(planned, uid)[0].type, 'verification');
    assert.equal(byRecipient(planned, uid)[0].title, 'Verify Repair');
  }
});

test('verification requests skip reporter, technician, admins, blanks and duplicates, and are capped', () => {
  const many = Array.from({ length: MAX_NEARBY_CITIZENS + 20 }, (_, i) => `n${i}`);
  const planned = buildReportChangeNotifications({
    reportId: 'AT-1',
    before: { ...base, status: 'ongoing', assignedTechnicianUid: 'tech-1' },
    after: { ...base, status: 'completed', assignedTechnicianUid: 'tech-1' },
    adminUids: ['admin-1'],
    nearbyCitizenUids: ['citizen-1', 'tech-1', 'admin-1', '', null, 'n0', ...many],
  });
  const requests = planned.filter((n) => n.type === 'verification');
  assert.equal(requests.length, MAX_NEARBY_CITIZENS);
  assert.equal(new Set(requests.map((n) => n.recipientUid)).size, requests.length);
  for (const uid of ['citizen-1', 'tech-1', 'admin-1']) {
    assert.equal(requests.some((n) => n.recipientUid === uid), false, uid);
  }
});

test('-> disputed produces nothing here (the dispute trigger is the single source)', () => {
  const planned = buildReportChangeNotifications({
    reportId: 'AT-1',
    before: { ...base, status: 'completed', assignedTechnicianUid: 'tech-1' },
    after: { ...base, status: 'disputed', assignedTechnicianUid: 'tech-1' },
    adminUids: ['admin-1'],
  });
  assert.deepEqual(planned, []);
});

test('no status or assignment change produces no notifications (counters, repair notes)', () => {
  assert.deepEqual(
    buildReportChangeNotifications({
      reportId: 'AT-1',
      before: { ...base, status: 'ongoing', assignedTechnicianUid: 'tech-1', repairNotes: 'a' },
      after: { ...base, status: 'ongoing', assignedTechnicianUid: 'tech-1', repairNotes: 'b' },
      adminUids: ['admin-1'],
    }),
    [],
  );
  // The server bumping verificationCount on a completed report must not re-notify.
  assert.deepEqual(
    buildReportChangeNotifications({
      reportId: 'AT-1',
      before: { ...base, status: 'completed', verificationCount: 1 },
      after: { ...base, status: 'completed', verificationCount: 2 },
      adminUids: ['admin-1'],
    }),
    [],
  );
});

test('any other status change falls back to a generic update', () => {
  const planned = buildReportChangeNotifications({
    reportId: 'AT-1',
    before: { ...base, status: 'completed' },
    after: { ...base, status: 'ongoing' },
  });
  assert.equal(planned.length, 1);
  assert.equal(planned[0].type, 'update');
  assert.match(planned[0].body, /now ongoing/);
});

test('missing recipients and missing data are skipped safely', () => {
  assert.deepEqual(buildReportChangeNotifications({ reportId: 'AT-1', before: null, after: base }), []);
  assert.deepEqual(buildReportChangeNotifications({ reportId: '', before: base, after: base }), []);
  const planned = buildReportChangeNotifications({
    reportId: 'AT-1',
    before: { status: 'pending' },
    after: { status: 'ongoing' }, // no reporter uid
    adminUids: [],
  });
  assert.deepEqual(planned, []);
});

test('every planned notification uses a contract type', () => {
  const planned = buildReportChangeNotifications({
    reportId: 'AT-1',
    before: { ...base, status: 'pending' },
    after: { ...base, status: 'assigned', assignedTechnicianUid: 'tech-1' },
  });
  assert.ok(planned.every((n) => VALID_TYPES.includes(n.type)));
});

test('new report alerts admins, flags emergencies, skips self-notification', () => {
  const planned = buildNewReportNotifications({
    reportId: 'AT-9',
    report: { ...base, faultType: 'burstPipe', isEmergency: true },
    adminUids: ['admin-1', 'citizen-1'],
  });
  assert.equal(planned.length, 1);
  assert.equal(planned[0].recipientUid, 'admin-1');
  assert.equal(planned[0].title, 'Emergency Report Submitted');
  assert.match(planned[0].body, /Burst Pipe/);
});

// --- Ids, documents, payloads -------------------------------------------------

test('notification ids are deterministic, per recipient and kind, and Firestore-safe', () => {
  const item = { recipientUid: 'u/1', kind: 'assigned' };
  assert.equal(notificationId('evt-1', item), notificationId('evt-1', item));
  assert.notEqual(notificationId('evt-1', item), notificationId('evt-2', item));
  assert.notEqual(
    notificationId('evt-1', item),
    notificationId('evt-1', { ...item, recipientUid: 'u2' }),
  );
  assert.equal(notificationId('evt-1', item).includes('/'), false);
  assert.ok(notificationId('x'.repeat(500), item).length <= 200);
});

test('notification document is unread and matches the client contract', () => {
  const doc = toNotificationDocument('id-1', 'AT-1', {
    recipientUid: 'citizen-1',
    title: 'T',
    body: 'B',
    type: 'update',
  });
  assert.deepEqual(Object.keys(doc).sort(), [
    'body', 'id', 'isRead', 'recipientUid', 'reportId', 'title', 'type',
  ]);
  assert.equal(doc.isRead, false);
});

test('push payload carries only a generic notification block and minimal data', () => {
  const document = {
    id: 'n1',
    title: 'Technician Assigned',
    body: 'Your report AT-1 has been assigned to Kasun Jayawardena.',
    reportId: 'AT-1',
    type: 'assignment',
    recipientUid: 'u1',
  };
  const message = buildPushMessage(['t1'], document);
  assert.deepEqual(message.data, { notificationId: 'n1', reportId: 'AT-1', type: 'assignment' });
  assert.deepEqual(message.notification, pushText(document));
  const serialised = JSON.stringify(message);
  assert.equal(serialised.includes('u1'), false); // no recipient uid
  assert.equal(serialised.includes('Kasun'), false); // no names on the lock screen
  assert.equal(serialised.includes('Jayawardena'), false);
});

test('OS push text identifies only the report, never people or places', () => {
  const text = pushText({
    title: 'Technician Assigned',
    body: 'Report AT-1 at Galle Road, Colombo 03 has been assigned to you.',
    reportId: 'AT-1',
  });
  assert.equal(text.title, 'Technician Assigned');
  assert.equal(text.body, 'Report AT-1. Open AquaTrace for details.');
  assert.equal(text.body.includes('Galle'), false);
});

// --- Community verification / dispute (Member 7) ------------------------------

const completed = {
  ...base,
  status: 'completed',
  assignedTechnicianUid: 'tech-1',
  assignedTechnicianName: 'Kasun',
  verificationCount: 2,
};

test('milestone fires only for the vote that reaches the threshold', () => {
  const args = { reportId: 'AT-1', report: completed, voterUid: 'v1', threshold: 3, adminUids: ['admin-1'] };
  assert.deepEqual(buildVerificationNotifications({ ...args, newCount: 2 }), []);
  assert.deepEqual(buildVerificationNotifications({ ...args, newCount: 4 }), []);
  const planned = buildVerificationNotifications({ ...args, newCount: 3 });
  assert.deepEqual(planned.map((n) => n.recipientUid).sort(), ['admin-1', 'citizen-1', 'tech-1']);
  assert.ok(planned.every((n) => n.type === 'verification'));
  assert.match(byRecipient(planned, 'tech-1')[0].body, /3 nearby citizens/);
});

test('milestone: logical id is stable across attempts and distinct per recipient', () => {
  const planned = buildVerificationNotifications({
    reportId: 'AT-1', report: completed, voterUid: 'v1', newCount: 3, threshold: 3, adminUids: ['admin-1'],
  });
  const first = planned.map((n) => notificationId('event-A', n));
  const second = planned.map((n) => notificationId('event-B', n)); // a retry has a new event id
  assert.deepEqual(first, second);
  assert.equal(new Set(first).size, first.length);
});

test('milestone does not notify the reporter as a recipient when they are the voter', () => {
  const planned = buildVerificationNotifications({
    reportId: 'AT-1', report: completed, voterUid: 'citizen-1', newCount: 3, threshold: 3,
  });
  assert.equal(byRecipient(planned, 'citizen-1').length, 0);
});

test('dispute notifies admins, technician, reporter and the voter exactly once each', () => {
  const planned = buildDisputeNotifications({
    reportId: 'AT-1', report: completed, voterUid: 'voter-1', adminUids: ['admin-1', 'admin-2'],
  });
  assert.deepEqual(
    planned.map((n) => n.recipientUid).sort(),
    ['admin-1', 'admin-2', 'citizen-1', 'tech-1', 'voter-1'],
  );
  assert.ok(planned.every((n) => n.type === 'dispute'));
  assert.equal(byRecipient(planned, 'voter-1')[0].title, 'Dispute Submitted');
});

test('dispute text carries no voter id, name or reason', () => {
  const planned = buildDisputeNotifications({
    reportId: 'AT-1', report: completed, voterUid: 'voter-1', adminUids: ['admin-1'],
  });
  for (const n of planned) {
    assert.equal(/reason|voter-1/i.test(n.body), false, n.body);
  }
});

test('dispute: same logical id per citizen across attempts; different citizens differ', () => {
  const a = buildDisputeNotifications({ reportId: 'AT-1', report: completed, voterUid: 'v1', adminUids: ['admin-1'] });
  const b = buildDisputeNotifications({ reportId: 'AT-1', report: completed, voterUid: 'v2', adminUids: ['admin-1'] });
  const adminA = byRecipient(a, 'admin-1')[0];
  const adminB = byRecipient(b, 'admin-1')[0];
  assert.equal(notificationId('e1', adminA), notificationId('e2', adminA));
  assert.notEqual(notificationId('e1', adminA), notificationId('e1', adminB));
});

test('dispute: a reporter who is the voter is notified once; missing data is safe', () => {
  const planned = buildDisputeNotifications({
    reportId: 'AT-1', report: completed, voterUid: 'citizen-1', adminUids: [],
  });
  assert.equal(byRecipient(planned, 'citizen-1').length, 1);
  assert.deepEqual(buildDisputeNotifications({ reportId: 'AT-1', report: null, voterUid: 'v' }), []);
  assert.deepEqual(buildDisputeNotifications({ reportId: 'AT-1', report: completed, voterUid: '' }), []);
});

test('deleted / unknown reports produce no verification or dispute notifications', () => {
  assert.deepEqual(buildVerificationNotifications({ reportId: 'AT-1', report: undefined, newCount: 3 }), []);
  assert.deepEqual(buildDisputeNotifications({ reportId: '', report: completed, voterUid: 'v' }), []);
});

// --- Aggregation (the server owns counters and the disputed flip) -------------

test('a verification vote is counted only for completed repairs', () => {
  assert.deepEqual(planVerificationCount(completed), { newCount: 3 });
  assert.deepEqual(planVerificationCount({ status: 'completed' }), { newCount: 1 });
  for (const status of ['pending', 'assigned', 'ongoing', 'disputed']) {
    assert.equal(planVerificationCount({ ...completed, status }), null, status);
  }
  assert.equal(planVerificationCount(null), null);
});

test('a dispute reopens a completed repair and only counts on an already disputed one', () => {
  assert.deepEqual(planDisputeUpdate({ ...completed, disputeCount: 1 }), { newCount: 2, status: 'disputed' });
  assert.deepEqual(planDisputeUpdate({ ...completed, status: 'disputed', disputeCount: 4 }), {
    newCount: 5, status: 'disputed',
  });
  for (const status of ['pending', 'assigned', 'ongoing']) {
    assert.equal(planDisputeUpdate({ ...completed, status }), null, status);
  }
});

test('audit events have deterministic ids, the right actors and no private detail', () => {
  const verification = buildVerificationActivity({ reportId: 'AT-1', voterUid: 'v1', voterName: 'Nimal' });
  assert.equal(verification.id, 'verification-v1');
  assert.equal(verification.status, 'completed');
  assert.equal(buildMilestoneActivity({ reportId: 'AT-1' }).id, 'community-verified');
  assert.match(buildMilestoneActivity({ reportId: 'AT-1', threshold: 5 }).description, /5 nearby citizens/);
  const dispute = buildDisputeActivity({ reportId: 'AT-1', voterUid: 'v1' });
  assert.equal(dispute.id, 'dispute-v1');
  assert.equal(dispute.status, 'disputed');
  assert.equal(dispute.description.includes('v1'), false);
  assert.equal(buildVerificationActivity({ reportId: 'AT-1', voterUid: 'v2' }).actorName, 'Community');
});

// --- User notification preferences --------------------------------------------

test('type maps to a preference category', () => {
  assert.equal(categoryOf('verification'), 'repairVerification');
  for (const type of ['assignment', 'approval', 'dispute', 'update']) {
    assert.equal(categoryOf(type), 'reportUpdates', type);
  }
});

test('preferences: defaults on; category off drops the record; push off keeps in-app only', () => {
  const planned = [
    { recipientUid: 'a', type: 'update', kind: 'k', title: 't', body: 'b' },
    { recipientUid: 'a', type: 'verification', kind: 'k2', title: 't', body: 'b' },
    { recipientUid: 'b', type: 'update', kind: 'k', title: 't', body: 'b' },
    { recipientUid: 'c', type: 'dispute', kind: 'k', title: 't', body: 'b' },
  ];
  const result = applyPreferences(planned, {
    a: { reportUpdates: false },
    b: { pushEnabled: false },
    // c has no saved preferences -> everything on
  });
  assert.deepEqual(
    result.map((n) => [n.recipientUid, n.type, n.push]),
    [['a', 'verification', true], ['b', 'update', false], ['c', 'dispute', true]],
  );
  assert.equal('push' in planned[0], false); // input is not mutated
});

test('preferences: repair verification off drops verification notifications only', () => {
  const planned = [
    { recipientUid: 'a', type: 'verification', kind: 'k', title: 't', body: 'b' },
    { recipientUid: 'a', type: 'dispute', kind: 'k2', title: 't', body: 'b' },
  ];
  const result = applyPreferences(planned, { a: { repairVerification: false } });
  assert.deepEqual(result.map((n) => n.type), ['dispute']);
});

test('preferences: a missing or empty preference map keeps everything', () => {
  const planned = [{ recipientUid: 'a', type: 'update', kind: 'k', title: 't', body: 'b' }];
  assert.equal(applyPreferences(planned).length, 1);
  assert.equal(applyPreferences(planned, {}).length, 1);
  assert.equal(applyPreferences(planned, { a: {} })[0].push, true);
});
