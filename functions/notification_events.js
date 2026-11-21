'use strict';

/**
 * Pure (dependency-free) notification rules for AquaTrace.
 *
 * Given the before/after state of a `/reports/{reportId}` document these
 * functions decide WHO is notified, with WHAT type and text. They perform no
 * I/O so they can be unit tested with `node --test` (see test/).
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

function faultLabel(faultType) {
  return FAULT_TYPE_LABELS[faultType] || 'Water fault';
}

function isNonEmptyString(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

/** Adds a planned notification, skipping recipients without a uid. */
function plan(list, recipientUid, kind, type, title, body) {
  if (!isNonEmptyString(recipientUid)) return;
  if (!VALID_TYPES.includes(type)) {
    throw new Error(`Invalid notification type: ${type}`);
  }
  // One notification per (recipient, kind) per event.
  if (list.some((n) => n.recipientUid === recipientUid && n.kind === kind)) return;
  list.push({ recipientUid, kind, type, title, body });
}

/**
 * Notifications caused by a report document update.
 *
 * @param {object} args
 * @param {string} args.reportId
 * @param {object} args.before  report data before the update
 * @param {object} args.after   report data after the update
 * @param {string[]} [args.adminUids]  uids of administrators (for alerts)
 * @returns {{recipientUid:string, kind:string, type:string, title:string, body:string}[]}
 */
function buildReportChangeNotifications({ reportId, before, after, adminUids = [] }) {
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
    plan(
      planned,
      reporterUid,
      'repair-completed',
      'verification',
      'Verify Repair',
      `Repair completed for ${reportId}. Please verify whether the issue has been resolved.`,
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
  } else if (next === 'disputed') {
    // --- Dispute opened -----------------------------------------------------
    const body = `A dispute has been raised on ${reportId}. Admin is reviewing.`;
    plan(planned, reporterUid, 'dispute', 'dispute', 'Dispute Opened', body);
    plan(planned, technicianUid, 'dispute', 'dispute', 'Dispute Opened', body);
    for (const adminUid of adminUids) {
      plan(planned, adminUid, 'dispute', 'dispute', 'Dispute Opened', body);
    }
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
 * Deterministic notification document id.
 *
 * Built from the trigger's event id, the recipient and the kind, so a retried
 * or duplicated trigger invocation targets the same document and `create()`
 * fails with ALREADY_EXISTS instead of producing a duplicate notification.
 */
function notificationId(eventId, item) {
  const raw = `${eventId}_${item.recipientUid}_${item.kind}`;
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
 * FCM multicast message. The payload carries only what the app needs to open
 * the right screen; the notification document remains the source of truth and
 * is access controlled by Firestore rules.
 */
function buildPushMessage(tokens, notificationDocument) {
  return {
    tokens,
    notification: {
      title: notificationDocument.title,
      body: notificationDocument.body,
    },
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
  notificationId,
  toNotificationDocument,
  buildPushMessage,
  DEAD_TOKEN_CODES,
  VALID_TYPES,
};
