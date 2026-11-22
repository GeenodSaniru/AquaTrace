'use strict';

/**
 * AquaTrace notification and aggregation triggers (Member 8) - REFERENCE
 * IMPLEMENTATION.
 *
 * Responsibilities (all with the Admin SDK, which bypasses Firestore rules -
 * that is why the rules deny every client-side create of a notification and
 * every client-side write of counters / the `disputed` status):
 *
 *   reports/{id}                        created  -> alert admins
 *   reports/{id}                        updated  -> approved / assigned /
 *                                                   repair status / completed
 *                                                   (+ verification requests)
 *   reports/{id}/verifications/{voter}  created  -> count the vote, append the
 *                                                   audit event, announce the
 *                                                   community milestone
 *   reports/{id}/disputes/{voter}       created  -> count the dispute, reopen
 *                                                   the report as `disputed`,
 *                                                   append the audit event,
 *                                                   notify everyone concerned
 *
 * Status: NOT deployed and NOT run against the Firebase emulator in this
 * repository's CI/environment. The decision logic in notification_events.js
 * is unit tested (`npm test`); the Firebase wiring below must be verified in
 * the emulator / a staging project before relying on it. See README.md.
 */

const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const logger = require('firebase-functions/logger');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

const events = require('./notification_events');
const delivery = require('./delivery');

initializeApp();
const db = getFirestore();

// gRPC status code for ALREADY_EXISTS (document id already present).
const ALREADY_EXISTS = 6;

// Keep in sync with the app (`CommunityVerificationService.confirmationThreshold`).
const VERIFICATION_THRESHOLD =
  Number(process.env.COMMUNITY_VERIFICATION_THRESHOLD) || events.DEFAULT_VERIFICATION_THRESHOLD;

// ---------------------------------------------------------------------------
// Lookups
// ---------------------------------------------------------------------------

async function loadAdminUids() {
  const snapshot = await db.collection('users').where('role', '==', 'admin').get();
  return snapshot.docs.map((doc) => doc.id);
}

/** Citizens in the same service area as the report (bounded). */
async function loadNearbyCitizenUids(report) {
  if (!report || typeof report.assignedArea !== 'string' || report.assignedArea.trim() === '') return [];
  const snapshot = await db
    .collection('users')
    .where('role', '==', 'citizen')
    .where('assignedArea', '==', report.assignedArea)
    .limit(events.MAX_NEARBY_CITIZENS + 2)
    .get();
  return snapshot.docs.map((doc) => doc.id);
}

/** Subset of [uids] that still have a user document (deleted users are skipped). */
async function filterExistingUsers(uids) {
  const unique = [...new Set(uids)];
  if (unique.length === 0) return new Set();
  const snapshots = await db.getAll(...unique.map((uid) => db.collection('users').doc(uid)));
  return new Set(snapshots.filter((snapshot) => snapshot.exists).map((snapshot) => snapshot.id));
}

/** `/users/{uid}/settings/notifications` for each uid (missing doc = defaults). */
async function loadPreferences(uids) {
  const unique = [...new Set(uids)];
  if (unique.length === 0) return {};
  const refs = unique.map((uid) => db.collection('users').doc(uid).collection('settings').doc('notifications'));
  const snapshots = await db.getAll(...refs);
  const byUid = {};
  snapshots.forEach((snapshot, index) => {
    byUid[unique[index]] = snapshot.exists ? snapshot.data() : {};
  });
  return byUid;
}

// ---------------------------------------------------------------------------
// Push + delivery (logic lives in delivery.js so it can be tested with fakes)
// ---------------------------------------------------------------------------

/** Sends one notification to the user's devices; dead tokens are removed. */
async function sendPush(uid, notificationDocument) {
  const tokenSnapshot = await db.collection('users').doc(uid).collection('fcmTokens').get();
  await delivery.sendToTokens({
    tokens: tokenSnapshot.docs.map((doc) => ({ token: doc.id, remove: () => doc.ref.delete() })),
    document: notificationDocument,
    messaging: getMessaging(),
  });
}

/** Firestore-backed implementation of the delivery store. */
const deliveryStore = {
  filterExistingUsers,
  loadPreferences,
  async createNotification(uid, id, document) {
    const reference = db.collection('users').doc(uid).collection('notifications').doc(id);
    try {
      await reference.create({ ...document, createdAt: FieldValue.serverTimestamp() });
      return 'created';
    } catch (error) {
      if (error && error.code === ALREADY_EXISTS) return 'exists'; // duplicate trigger delivery
      throw error;
    }
  },
  sendPush,
};

/**
 * Creates each planned notification once, then pushes it (see delivery.js:
 * ordered per recipient, idempotent, preference- and missing-user-aware).
 */
function deliver(eventId, reportId, planned) {
  return delivery.deliverNotifications({ eventId, reportId, planned, store: deliveryStore, logger });
}

/** Appends an audit event once (deterministic id; the trail is immutable). */
async function appendActivity(reportId, activity) {
  const reference = db.collection('reports').doc(reportId).collection('activity').doc(activity.id);
  try {
    await reference.create({ ...activity, timestamp: FieldValue.serverTimestamp() });
  } catch (error) {
    if (error && error.code === ALREADY_EXISTS) return;
    throw error;
  }
}

// ---------------------------------------------------------------------------
// Report triggers
// ---------------------------------------------------------------------------

exports.onReportCreated = onDocumentCreated('reports/{reportId}', async (event) => {
  const report = event.data && event.data.data();
  if (!report) return;
  const planned = events.buildNewReportNotifications({
    reportId: event.params.reportId,
    report,
    adminUids: await loadAdminUids(),
  });
  await deliver(event.id, event.params.reportId, planned);
});

exports.onReportUpdated = onDocumentUpdated('reports/{reportId}', async (event) => {
  const before = event.data && event.data.before.data();
  const after = event.data && event.data.after.data();
  if (!before || !after) return;

  // Counter / notes / priority updates change no status: skip the lookups.
  const statusChanged = before.status !== after.status;
  const completedNow = before.status !== 'completed' && after.status === 'completed';
  const planned = events.buildReportChangeNotifications({
    reportId: event.params.reportId,
    before,
    after,
    adminUids: statusChanged ? await loadAdminUids() : [],
    // Only look up nearby citizens when a repair has just been completed.
    nearbyCitizenUids: completedNow ? await loadNearbyCitizenUids(after) : [],
  });
  await deliver(event.id, event.params.reportId, planned);
});

// ---------------------------------------------------------------------------
// Community verification / dispute triggers (Member 7's documents)
// ---------------------------------------------------------------------------

/**
 * Counts a verification vote exactly once and returns the count it produced.
 * Idempotent: the vote document is marked `counted` (with `countedAs`) in the
 * same transaction as the counter update, so a retry re-derives the same
 * outcome instead of counting again.
 */
async function countVerification(reportRef, voteRef) {
  return db.runTransaction(async (transaction) => {
    const [reportSnapshot, voteSnapshot] = await Promise.all([transaction.get(reportRef), transaction.get(voteRef)]);
    if (!reportSnapshot.exists || !voteSnapshot.exists) return { skipped: 'missing' };
    const report = reportSnapshot.data();
    if (voteSnapshot.get('counted') === true) {
      return { report, newCount: voteSnapshot.get('countedAs') };
    }
    const update = events.planVerificationCount(report);
    if (!update) {
      transaction.update(voteRef, { counted: true, rejected: true });
      return { skipped: 'not-completed' };
    }
    transaction.update(reportRef, { verificationCount: update.newCount, updatedAt: FieldValue.serverTimestamp() });
    transaction.update(voteRef, { counted: true, countedAs: update.newCount });
    return { report, newCount: update.newCount };
  });
}

/** Same for a dispute: counts it and reopens the report as `disputed`. */
async function countDispute(reportRef, disputeRef) {
  return db.runTransaction(async (transaction) => {
    const [reportSnapshot, disputeSnapshot] = await Promise.all([
      transaction.get(reportRef),
      transaction.get(disputeRef),
    ]);
    if (!reportSnapshot.exists || !disputeSnapshot.exists) return { skipped: 'missing' };
    const report = reportSnapshot.data();
    if (disputeSnapshot.get('counted') === true) return { report };
    const update = events.planDisputeUpdate(report);
    if (!update) {
      transaction.update(disputeRef, { counted: true, rejected: true });
      return { skipped: 'not-completed' };
    }
    transaction.update(reportRef, {
      status: update.status,
      disputeCount: update.newCount,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(disputeRef, { counted: true, countedAs: update.newCount });
    return { report };
  });
}

exports.onVerificationCreated = onDocumentCreated('reports/{reportId}/verifications/{voterUid}', async (event) => {
  const { reportId, voterUid } = event.params;
  const vote = event.data && event.data.data();
  if (!vote) return;
  const reportRef = db.collection('reports').doc(reportId);

  const outcome = await countVerification(reportRef, event.data.ref);
  if (outcome.skipped) {
    // Deleted report or not a completed repair: nothing to announce.
    logger.info('Verification ignored', { reportId, voterUid, reason: outcome.skipped });
    return;
  }

  await appendActivity(reportId, events.buildVerificationActivity({ reportId, voterUid, voterName: vote.voterName }));
  if (outcome.newCount === VERIFICATION_THRESHOLD) {
    await appendActivity(reportId, events.buildMilestoneActivity({ reportId, threshold: VERIFICATION_THRESHOLD }));
  }
  const planned = events.buildVerificationNotifications({
    reportId,
    report: outcome.report,
    voterUid,
    newCount: outcome.newCount,
    threshold: VERIFICATION_THRESHOLD,
    adminUids: outcome.newCount === VERIFICATION_THRESHOLD ? await loadAdminUids() : [],
  });
  await deliver(event.id, reportId, planned);
});

exports.onDisputeCreated = onDocumentCreated('reports/{reportId}/disputes/{voterUid}', async (event) => {
  const { reportId, voterUid } = event.params;
  const dispute = event.data && event.data.data();
  if (!dispute) return;
  const reportRef = db.collection('reports').doc(reportId);

  const outcome = await countDispute(reportRef, event.data.ref);
  if (outcome.skipped) {
    logger.info('Dispute ignored', { reportId, voterUid, reason: outcome.skipped });
    return;
  }

  await appendActivity(reportId, events.buildDisputeActivity({ reportId, voterUid }));
  const planned = events.buildDisputeNotifications({
    reportId,
    report: outcome.report,
    voterUid,
    adminUids: await loadAdminUids(),
  });
  await deliver(event.id, reportId, planned);
});
