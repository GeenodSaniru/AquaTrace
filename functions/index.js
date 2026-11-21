'use strict';

/**
 * AquaTrace notification triggers (Member 8) - REFERENCE IMPLEMENTATION.
 *
 * Creates `/users/{uid}/notifications/{id}` documents and sends FCM pushes in
 * response to trusted report workflow events. Admin SDK writes bypass
 * Firestore rules, which is why the rules deny every client-side create.
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

initializeApp();
const db = getFirestore();

// gRPC status code for ALREADY_EXISTS (document id already present).
const ALREADY_EXISTS = 6;

async function loadAdminUids() {
  const snapshot = await db.collection('users').where('role', '==', 'admin').get();
  return snapshot.docs.map((doc) => doc.id);
}

async function sendPush(uid, notificationDocument) {
  const tokenSnapshot = await db.collection('users').doc(uid).collection('fcmTokens').get();
  if (tokenSnapshot.empty) return;
  const tokens = tokenSnapshot.docs.map((doc) => doc.id);

  const response = await getMessaging().sendEachForMulticast(
    events.buildPushMessage(tokens, notificationDocument),
  );

  // Remove tokens FCM reports as dead so they are not retried forever.
  const stale = [];
  response.responses.forEach((result, index) => {
    if (!result.success && events.DEAD_TOKEN_CODES.includes(result.error && result.error.code)) {
      stale.push(tokenSnapshot.docs[index].ref.delete());
    }
  });
  await Promise.allSettled(stale);
}

/** Creates each planned notification once, then pushes it. */
async function deliver(eventId, reportId, planned) {
  const results = await Promise.allSettled(
    planned.map(async (item) => {
      const id = events.notificationId(eventId, item);
      const document = events.toNotificationDocument(id, reportId, item);
      const reference = db.collection('users').doc(item.recipientUid).collection('notifications').doc(id);
      try {
        await reference.create({ ...document, createdAt: FieldValue.serverTimestamp() });
      } catch (error) {
        if (error && error.code === ALREADY_EXISTS) return; // duplicate trigger delivery
        throw error;
      }
      try {
        await sendPush(item.recipientUid, document);
      } catch (error) {
        // The in-app record exists; a failed push must not fail the trigger.
        logger.warn('Push delivery failed', { recipientUid: item.recipientUid, id, error: String(error) });
      }
    }),
  );
  results
    .filter((result) => result.status === 'rejected')
    .forEach((result) => logger.error('Notification creation failed', { reportId, error: String(result.reason) }));
}

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
  const planned = events.buildReportChangeNotifications({
    reportId: event.params.reportId,
    before,
    after,
    adminUids: await loadAdminUids(),
  });
  await deliver(event.id, event.params.reportId, planned);
});
