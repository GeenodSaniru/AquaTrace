'use strict';

/**
 * Notification delivery with injected dependencies.
 *
 * `index.js` supplies Firestore / FCM implementations; the tests supply
 * in-memory fakes. Keeping this logic free of Firebase imports is what lets
 * the ordering, replay (idempotency), preference, missing-user and
 * failure-isolation behaviour be verified without an emulator.
 */

const events = require('./notification_events');

/**
 * Creates each planned notification once and pushes it.
 *
 * Guarantees:
 *  - recipients that no longer exist are skipped;
 *  - each recipient's saved preferences are honoured;
 *  - notifications for one recipient are created **sequentially in planned
 *    order**, so their server timestamps follow the workflow order (e.g.
 *    "Report Approved" is older than "Technician Assigned"); different
 *    recipients are processed in parallel;
 *  - ids are deterministic, so a replay (retry / duplicate trigger) creates
 *    nothing and sends no second push;
 *  - a failed push never fails the delivery and never blocks later items;
 *  - a failed create for one recipient never blocks other recipients.
 *
 * @param {object} args
 * @param {string} args.eventId   trigger event id (idempotency)
 * @param {string} args.reportId
 * @param {Array}  args.planned   output of the notification planners
 * @param {object} args.store     { filterExistingUsers, loadPreferences,
 *                                  createNotification, sendPush }
 * @param {object} [args.logger]  { warn, error }
 * @returns {Promise<{created: string[], existing: string[], failed: number}>}
 */
async function deliverNotifications({ eventId, reportId, planned, store, logger = {} }) {
  const summary = { created: [], existing: [], failed: 0 };
  if (!planned || planned.length === 0) return summary;

  const existingUsers = await store.filterExistingUsers(planned.map((item) => item.recipientUid));
  const reachable = planned.filter((item) => existingUsers.has(item.recipientUid));
  const preferences = await store.loadPreferences(reachable.map((item) => item.recipientUid));
  const deliverable = events.applyPreferences(reachable, preferences);

  // Group by recipient, preserving planned order.
  const byRecipient = new Map();
  for (const item of deliverable) {
    if (!byRecipient.has(item.recipientUid)) byRecipient.set(item.recipientUid, []);
    byRecipient.get(item.recipientUid).push(item);
  }

  await Promise.all(
    [...byRecipient.entries()].map(async ([recipientUid, items]) => {
      for (const item of items) {
        const id = events.notificationId(eventId, item);
        const document = events.toNotificationDocument(id, reportId, item);
        let outcome;
        try {
          outcome = await store.createNotification(recipientUid, id, document);
        } catch (error) {
          summary.failed += 1;
          if (logger.error) logger.error('Notification creation failed', { reportId, recipientUid, id, error: String(error) });
          continue;
        }
        if (outcome === 'exists') {
          summary.existing.push(id);
          continue; // replay: neither a second record nor a second push
        }
        summary.created.push(id);
        if (!item.push) continue;
        try {
          await store.sendPush(recipientUid, document);
        } catch (error) {
          // The in-app record exists; a failed push must not fail the trigger.
          if (logger.warn) logger.warn('Push delivery failed', { recipientUid, id, error: String(error) });
        }
      }
    }),
  );
  return summary;
}

/**
 * Sends one notification to a user's device tokens and removes dead tokens.
 *
 * @param {object} args
 * @param {Array<{token: string, remove: () => Promise<void>}>} args.tokens
 * @param {object} args.document  notification document
 * @param {object} args.messaging { sendEachForMulticast(message) }
 * @returns {Promise<{sent: number, removed: number}>}
 */
async function sendToTokens({ tokens, document, messaging }) {
  if (!tokens || tokens.length === 0) return { sent: 0, removed: 0 };
  const response = await messaging.sendEachForMulticast(
    events.buildPushMessage(
      tokens.map((entry) => entry.token),
      document,
    ),
  );
  const removals = [];
  let sent = 0;
  response.responses.forEach((result, index) => {
    if (result.success) {
      sent += 1;
    } else if (events.DEAD_TOKEN_CODES.includes(result.error && result.error.code)) {
      removals.push(tokens[index].remove());
    }
    // Any other failure (quota, transient) keeps the token for the next attempt.
  });
  await Promise.allSettled(removals);
  return { sent, removed: removals.length };
}

module.exports = { deliverNotifications, sendToTokens };
