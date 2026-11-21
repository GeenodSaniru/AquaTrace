'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  buildReportChangeNotifications,
  buildNewReportNotifications,
  notificationId,
  toNotificationDocument,
  buildPushMessage,
  VALID_TYPES,
} = require('../notification_events');

const base = {
  reporterUid: 'citizen-1',
  address: 'Galle Road, Colombo 03',
  faultType: 'pipeLeak',
  status: 'pending',
};

const byRecipient = (list, uid) => list.filter((n) => n.recipientUid === uid);

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

test('ongoing -> completed: reporter asked to verify, admins informed', () => {
  const planned = buildReportChangeNotifications({
    reportId: 'AT-1',
    before: { ...base, status: 'ongoing', assignedTechnicianUid: 'tech-1' },
    after: { ...base, status: 'completed', assignedTechnicianUid: 'tech-1', assignedTechnicianName: 'Kasun' },
    adminUids: ['admin-1', 'admin-2'],
  });
  assert.equal(byRecipient(planned, 'citizen-1')[0].type, 'verification');
  assert.equal(byRecipient(planned, 'admin-1')[0].type, 'update');
  assert.equal(byRecipient(planned, 'admin-2').length, 1);
});

test('-> disputed: reporter, technician and every admin get a dispute notification', () => {
  const planned = buildReportChangeNotifications({
    reportId: 'AT-1',
    before: { ...base, status: 'completed', assignedTechnicianUid: 'tech-1' },
    after: { ...base, status: 'disputed', assignedTechnicianUid: 'tech-1' },
    adminUids: ['admin-1'],
  });
  assert.deepEqual(
    planned.map((n) => n.recipientUid).sort(),
    ['admin-1', 'citizen-1', 'tech-1'],
  );
  assert.ok(planned.every((n) => n.type === 'dispute' && n.title === 'Dispute Opened'));
});

test('no status or assignment change produces no notifications (e.g. repair notes edit)', () => {
  const planned = buildReportChangeNotifications({
    reportId: 'AT-1',
    before: { ...base, status: 'ongoing', assignedTechnicianUid: 'tech-1', repairNotes: 'a' },
    after: { ...base, status: 'ongoing', assignedTechnicianUid: 'tech-1', repairNotes: 'b' },
    adminUids: ['admin-1'],
  });
  assert.deepEqual(planned, []);
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
    after: { status: 'disputed' }, // no reporter / technician uid
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

test('push payload carries only the notification block and minimal data', () => {
  const message = buildPushMessage(['t1'], {
    id: 'n1', title: 'Hi', body: 'There', reportId: 'AT-1', type: 'update', recipientUid: 'u1',
  });
  assert.deepEqual(message.data, { notificationId: 'n1', reportId: 'AT-1', type: 'update' });
  assert.deepEqual(message.notification, { title: 'Hi', body: 'There' });
  assert.equal(JSON.stringify(message).includes('u1'), false); // no recipient uid in payload
});
