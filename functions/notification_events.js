'use strict';

/**
 * Pure (dependency-free) notification, aggregation and activity rules for
 * AquaTrace.
 *
 * Nothing here performs I/O, so every rule is unit tested with `node --test`
 * (see test/). `index.js` wires these functions to Firestore / FCM.
 *
 * `type` values are the shared contract used by the Flutter client and the
 * Firestore rules: assignment | verification | approval | dispute | update.
 * `kind` is an internal discriminator used only to build deterministic
 * notification ids (idempotency); it is not stored.
 */

const FAULT_TYPE_LABELS = {
  pipeLeak: 'Pipe Leak',
  burstPipe: 'Burst Pipe',
  damagedPipe: 'Damaged Pipe',
  roadWaterFlow: 'Road Water Flow',
  lowPressure: 'Low Water Pressure',
  waterContamination: 'Water Contamination',
  other: 'Other Fault',
};

const VALID_TYPES = ['assignment', 'verification', 'approval', 'dispute', 'update'];

/** Number of independent community confirmations that "verifies" a repair. */
const DEFAULT_VERIFICATION_THRESHOLD = 3;

/** Upper bound on citizens asked to verify one completed repair. */
const MAX_NEARBY_CITIZENS = 50;

function faultLabel(faultType) {
  return FAULT_TYPE_LABELS[faultType] || 'Water fault';
}

function isNonEmptyString(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

/**
 * Adds a planned notification, skipping recipients without a uid.
 *
 * `idKey` (optional) is a *logical* event key. When present the notification
 * id is derived from it instead of the trigger's event id, so the same
 * logical event can never notify a recipient twice even if it is observed by
 * more than one trigger or attempt.
 */
function plan(list, recipientUid, kind, type, title, body, idKey) {
  if (!isNonEmptyString(recipientUid)) return;
  if (!VALID_TYPES.includes(type)) {
    throw new Error(`Invalid notification type: ${type}`);
  }
  // One notification per (recipient, kind) per event.
  if (list.some((n) => n.recipientUid === recipientUid && n.kind === kind)) return;
  const item = { recipientUid, kind, type, title, body };
  if (idKey) item.idKey = idKey;
  list.push(item);
}

/**
 * Notifications caused by a report document update.
 *
 * @param {object} args
 * @param {string} args.reportId
 * @param {object} args.before  report data before the update
 * @param {object} args.after   report data after the update
 * @param {string[]} [args.adminUids]  uids of administrators (for alerts)
 * @param {string[]} [args.nearbyCitizenUids]  citizens near a completed repair
 *   who may be asked to verify it (the caller bounds this list)
 * @returns {{recipientUid:string, kind:string, type:string, title:string, body:string}[]}
 */
function buildReportChangeNotifications({
  reportId,
  before,
  after,
  adminUids = [],
  nearbyCitizenUids = [],
}) {
  const planned = [];
  if (!before || !after || !isNonEmptyString(reportId)) return planned;

  const reporterUid = after.reporterUid;
  const technicianUid = after.assignedTechnicianUid;
  const technicianName = isNonEmptyString(after.assignedTechnicianName)
    ? after.assignedTechnicianName
    : 'a technician';
  const previous = before.status;
  const next = after.status;
  const statusChanged = previous !== next;
  const technicianChanged =
    isNonEmptyString(technicianUid) && technicianUid !== before.assignedTechnicianUid;
  const address = isNonEmptyString(after.address) ? after.address : 'the reported location';

  // --- Approved / verified, and technician assigned ------------------------
  if (next === 'assigned' && (statusChanged || technicianChanged) && isNonEmptyString(technicianUid)) {
    if (previous === 'pending') {
      plan(
        planned,
        reporterUid,
        'approved',
        'approval',
        'Report Approved',
        `Your report ${reportId} has been verified by admin and is now assigned.`,
      );
    }
    plan(
      planned,
      reporterUid,
      'assigned',
      'assignment',
      'Technician Assigned',
      `Your report ${reportId} has been assigned to ${technicianName}.`,
    );
    plan(
      planned,
      technicianUid,
      'job-assigned',
      'assignment',
      'New Job Assigned',
      `Report ${reportId} at ${address} has been assigned to you.`,
    );
    return planned;
  }

  if (!statusChanged) return planned;

  // --- Repair status updated ----------------------------------------------
  if (previous === 'assigned' && next === 'ongoing') {
    plan(
      planned,
      reporterUid,
      'repair-started',
      'update',
      'Repair Started',
      `Repair work has started on your report ${reportId}.`,
    );
  } else if (next === 'completed') {
    // The reporter is informed, but is NOT asked to verify their own report
    // (the community verification rules forbid it); nearby citizens are.
    plan(
      planned,
      reporterUid,
      'repair-completed',
      'update',
      'Repair Completed',
      `Your report ${reportId} has been marked completed. Nearby residents may be asked to confirm the repair.`,
    );
    for (const adminUid of adminUids) {
      plan(
        planned,
        adminUid,
        'repair-completed',
        'update',
        'Repair Completed',
        `${reportId} was marked completed by ${technicianName}.`,
      );
    }
    const excluded = new Set([reporterUid, technicianUid, ...adminUids]);
    // Filter and de-duplicate first, then cap, so the cap counts real people.
    [...new Set(nearbyCitizenUids.filter((uid) => isNonEmptyString(uid) && !excluded.has(uid)))]
      .slice(0, MAX_NEARBY_CITIZENS)
      .forEach((uid) =>
        plan(
          planned,
          uid,
          'verify-request',
          'verification',
          'Verify Repair',
          `Repair completed for ${reportId}. Please verify whether the issue has been resolved.`,
        ),
      );
  } else if (next === 'disputed') {
    // Intentionally no notification here. A report only becomes `disputed`
    // when the dispute-created trigger processes a citizen's dispute
    // document, and that trigger (buildDisputeNotifications) is the single
    // source of dispute notifications. Emitting them here as well would
    // notify everyone twice.
  } else {
    plan(
      planned,
      reporterUid,
      `status-${next}`,
      'update',
      'Report Status Updated',
      `Your report ${reportId} is now ${next}.`,
    );
  }
  return planned;
}

/**
 * Alerts for administrators when a new report is submitted.
 */
function buildNewReportNotifications({ reportId, report, adminUids = [] }) {
  const planned = [];
  if (!report || !isNonEmptyString(reportId)) return planned;
  const emergency = report.isEmergency === true;
  const title = emergency ? 'Emergency Report Submitted' : 'New Report Submitted';
  const address = isNonEmptyString(report.address) ? report.address : 'an unspecified location';
  const body = `${reportId} ${faultLabel(report.faultType)} at ${address} needs review.`;
  for (const adminUid of adminUids) {
    // Do not alert an administrator about their own submission.
    if (adminUid === report.reporterUid) continue;
    plan(planned, adminUid, 'new-report', 'update', title, body);
  }
  return planned;
}

/**
 * Community verification milestone ("Community Verified").
 *
 * Fires only for the vote that makes the count equal the threshold, so later
 * confirmations do not repeat it. The logical id key additionally guarantees
 * one notification per recipient even if the trigger is retried.
 */
function buildVerificationNotifications({
  reportId,
  report,
  voterUid,
  newCount,
  threshold = DEFAULT_VERIFICATION_THRESHOLD,
  adminUids = [],
}) {
  const planned = [];
  if (!report || !isNonEmptyString(reportId) || newCount !== threshold) return planned;
  const idKey = `community-verified-${reportId}`;
  if (report.reporterUid !== voterUid) {
    plan(
      planned,
      report.reporterUid,
      'milestone',
      'verification',
      'Repair Verified',
      `Community confirmed resolution for your report ${reportId}.`,
      idKey,
    );
  }
  plan(
    planned,
    report.assignedTechnicianUid,
    'milestone',
    'verification',
    'Repair Verified by Community',
    `${threshold} nearby citizens confirmed your repair on ${reportId} is complete.`,
    idKey,
  );
  for (const adminUid of adminUids) {
    plan(
      planned,
      adminUid,
      'milestone',
      'verification',
      'Repair Verified by Community',
      `Report ${reportId} reached the community verification threshold.`,
      idKey,
    );
  }
  return planned;
}

/**
 * Notifications for a community dispute. One logical event per
 * (report, disputing citizen); text carries no voter name or reason (the
 * dispute document itself holds those, behind its own access rules).
 */
function buildDisputeNotifications({ reportId, report, voterUid, adminUids = [] }) {
  const planned = [];
  if (!report || !isNonEmptyString(reportId) || !isNonEmptyString(voterUid)) return planned;
  const idKey = `dispute-${reportId}-${voterUid}`;
  for (const adminUid of adminUids) {
    plan(
      planned,
      adminUid,
      'dispute',
      'dispute',
      'Dispute Raised',
      `Dispute raised on ${reportId}. Case reopened for Admin review.`,
      idKey,
    );
  }
  plan(
    planned,
    report.assignedTechnicianUid,
    'dispute',
    'dispute',
    'Repair Disputed',
    `Completed repair on ${reportId} was disputed by the community and reopened for review.`,
    idKey,
  );
  if (report.reporterUid !== voterUid) {
    plan(
      planned,
      report.reporterUid,
      'dispute',
      'dispute',
      'Dispute Opened',
      `A community dispute has been raised on your report ${reportId}. Admin is reviewing.`,
      idKey,
    );
  }
  plan(
    planned,
    voterUid,
    'dispute-submitted',
    'dispute',
    'Dispute Submitted',
    `Your dispute on ${reportId} was submitted to the Water Board.`,
    idKey,
  );
  return planned;
}

// ---------------------------------------------------------------------------
// Aggregation (counters / status) - the server owns these fields.
// ---------------------------------------------------------------------------

/**
 * What a new verification vote does to its report, or `null` when the vote is
 * not valid (only completed repairs can be verified).
 */
function planVerificationCount(report) {
  if (!report || report.status !== 'completed') return null;
  return { newCount: (Number(report.verificationCount) || 0) + 1 };
}

/**
 * What a new dispute does to its report, or `null` when it is not valid.
 * Disputing a completed repair reopens it as `disputed`; further disputes on
 * an already disputed report only raise the counter.
 */
function planDisputeUpdate(report) {
  if (!report || (report.status !== 'completed' && report.status !== 'disputed')) return null;
  return { newCount: (Number(report.disputeCount) || 0) + 1, status: 'disputed' };
}

// ---------------------------------------------------------------------------
// Audit-trail events (appended by the server; ids are deterministic so a
// retry cannot create a duplicate entry).
// ---------------------------------------------------------------------------

function buildVerificationActivity({ reportId, voterUid, voterName }) {
  return {
    id: `verification-${voterUid}`,
    reportId,
    title: 'Community Verification Confirmed',
    description: `${isNonEmptyString(voterName) ? voterName : 'A nearby citizen'} confirmed repair completion.`,
    actorName: isNonEmptyString(voterName) ? voterName : 'Community',
    actorRole: 'Citizen Verification',
    status: 'completed',
  };
}

function buildMilestoneActivity({ reportId, threshold = DEFAULT_VERIFICATION_THRESHOLD }) {
  return {
    id: 'community-verified',
    reportId,
    title: 'Community Verified',
    description: `${threshold} nearby citizens confirmed the repair is complete.`,
    actorName: 'Community',
    actorRole: 'Citizen Verification',
    status: 'completed',
  };
}

function buildDisputeActivity({ reportId, voterUid }) {
  return {
    id: `dispute-${voterUid}`,
    reportId,
    title: 'Dispute Raised',
    description: 'A community dispute was raised. Status reopened for Admin review.',
    actorName: 'Community',
    actorRole: 'Citizen Dispute',
    status: 'disputed',
  };
}

// ---------------------------------------------------------------------------
// User notification preferences
// ---------------------------------------------------------------------------

/**
 * Preference category of a notification type. Settings screen categories:
 * "Report Updates" and "Repair Verification" (verification requests and
 * community milestones).
 */
function categoryOf(type) {
  return type === 'verification' ? 'repairVerification' : 'reportUpdates';
}

/**
 * Applies each recipient's saved preferences.
 *
 * `prefsByUid[uid]` is `/users/{uid}/settings/notifications`:
 * `{ pushEnabled, reportUpdates, repairVerification, ... }` - any missing
 * field defaults to *enabled*.
 *   - category switched off  -> no in-app record and no push;
 *   - `pushEnabled === false` -> in-app record only, no push.
 *
 * @returns {Array<object & {push: boolean}>}
 */
function applyPreferences(planned, prefsByUid = {}) {
  const result = [];
  for (const item of planned) {
    const prefs = prefsByUid[item.recipientUid] || {};
    const category = categoryOf(item.type);
    if (prefs[category] === false) continue;
    result.push({ ...item, push: prefs.pushEnabled !== false });
  }
  return result;
}

// ---------------------------------------------------------------------------
// Documents and payloads
// ---------------------------------------------------------------------------

/**
 * Deterministic notification document id.
 *
 * Event-driven notifications use the trigger's event id, so a retried or
 * duplicated invocation targets the same document. Notifications with a
 * logical `idKey` use that instead, which also de-duplicates across
 * different triggers and attempts. Either way `create()` fails with
 * ALREADY_EXISTS instead of producing a duplicate notification or push.
 */
function notificationId(eventId, item) {
  const raw = item.idKey
    ? `${item.idKey}_${item.recipientUid}`
    : `${eventId}_${item.recipientUid}_${item.kind}`;
  return raw.replace(/[^A-Za-z0-9_-]/g, '_').slice(0, 200);
}

/** Notification document body (everything except the server timestamp). */
function toNotificationDocument(id, reportId, item) {
  return {
    id,
    recipientUid: item.recipientUid,
    title: item.title,
    body: item.body,
    reportId,
    type: item.type,
    isRead: false,
  };
}

/**
 * Text shown by the operating system (lock screen, notification shade).
 *
 * The in-app `body` can name people or places (technician, address); the OS
 * text is deliberately generic and only identifies the report. The full
 * message is in the access-controlled notification document, which the app
 * shows after authentication.
 */
function pushText(notificationDocument) {
  return {
    title: notificationDocument.title,
    body: `Report ${notificationDocument.reportId}. Open AquaTrace for details.`,
  };
}

/**
 * FCM multicast message. The payload carries only what the app needs to open
 * the right screen (`notificationId`, `reportId`, `type`); the notification
 * document remains the source of truth.
 */
function buildPushMessage(tokens, notificationDocument) {
  return {
    tokens,
    notification: pushText(notificationDocument),
    data: {
      notificationId: notificationDocument.id,
      reportId: notificationDocument.reportId,
      type: notificationDocument.type,
    },
    android: { priority: 'high' },
    apns: { payload: { aps: { sound: 'default' } } },
  };
}

/** FCM error codes that mean a stored token is dead and should be deleted. */
const DEAD_TOKEN_CODES = [
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
];

module.exports = {
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
  DEAD_TOKEN_CODES,
  VALID_TYPES,
  DEFAULT_VERIFICATION_THRESHOLD,
  MAX_NEARBY_CITIZENS,
};
