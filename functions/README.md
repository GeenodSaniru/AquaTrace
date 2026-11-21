# AquaTrace notification backend (Member 8)

Reference implementation of the **trusted** side of notifications. The Flutter
client only *reads* notifications and marks them read; it can never create one
(`firestore.rules` denies every client create on
`/users/{uid}/notifications/{id}`). Notifications must therefore be created by
code running with the Admin SDK.

> **Status — not deployed, not emulator-tested.**
> `notification_events.js` (who gets which notification) is unit tested with
> `npm test`. `index.js` (Firestore triggers + FCM send) has **not** been
> deployed or run against the Firebase emulator in this repository. Until it is
> deployed and verified, push delivery and server-created notifications are
> **not** working end to end. The client side is complete and contract-tested.

## Deploy checklist

1. `cd functions && npm install`
2. `npm test` (pure logic tests, no Firebase needed).
3. Set the function region to match the Firestore database location
   (`setGlobalOptions({ region: ... })` in `index.js`; default is `us-central1`).
4. Deploy: `firebase deploy --only functions --project aquatrace-92e2e`
   (requires the Blaze plan).
5. Deploy the updated rules: `firebase deploy --only firestore:rules`.
6. **Android:** nothing else (the app's `google-services.json` is committed).
7. **iOS / macOS:** upload an APNs auth key (`.p8`) in Firebase Console →
   Project settings → Cloud Messaging, and enable the *Push Notifications*
   capability for the Runner target in Xcode (needs an Apple Developer team).
   **Never commit the `.p8`.**
8. **Web:** browser push is not wired (needs a service worker + VAPID key).

## Triggers

| Trigger | When | Recipients |
|---|---|---|
| `onReportCreated` (`reports/{id}` create) | citizen submits a report | every admin: *New Report Submitted* (*Emergency Report Submitted* if `isEmergency`) |
| `onReportUpdated` (`reports/{id}` update) | status / assignment changes | see below |

`onReportUpdated` mapping (`type` is the stored contract value):

| Change | Recipient | `type` | Title |
|---|---|---|---|
| `pending → assigned` | reporter | `approval` | Report Approved |
| `→ assigned` (or technician changed) | reporter | `assignment` | Technician Assigned |
| `→ assigned` (or technician changed) | assigned technician | `assignment` | New Job Assigned |
| `assigned → ongoing` | reporter | `update` | Repair Started |
| `→ completed` | reporter | `verification` | Verify Repair |
| `→ completed` | every admin | `update` | Repair Completed |
| `→ disputed` | reporter, assigned technician, every admin | `dispute` | Dispute Opened |
| any other status change | reporter | `update` | Report Status Updated |

## Notification document contract

`/users/{recipientUid}/notifications/{notificationId}`

```json
{
  "id": "<same as document id>",
  "recipientUid": "<owner uid>",
  "title": "Technician Assigned",
  "body": "Your report AT-2026-00124 has been assigned to Kasun Jayawardena.",
  "reportId": "AT-2026-00124",
  "type": "assignment",
  "isRead": false,
  "createdAt": "<Firestore Timestamp, server time>"
}
```

* `type` ∈ `assignment | verification | approval | dispute | update`.
* `createdAt` **must be a Firestore `Timestamp`** (use `FieldValue.serverTimestamp()`).
  The client query is `orderBy('createdAt', descending: true)`; Firestore orders
  mixed types by type first, so do not mix ISO strings and Timestamps. (The
  client tolerates either when *parsing*, to read older data.)
* `id` is **deterministic**: `<eventId>_<recipientUid>_<kind>`. A retried or
  duplicated trigger hits `ALREADY_EXISTS` and is skipped, so no duplicate
  notification or duplicate push is produced.
* Only `isRead` is client-writable (rules enforce this).

## Push (FCM) contract

* Devices register at `/users/{uid}/fcmTokens/{token}`
  (`token`, `platform`, `createdAt`, `updatedAt`); the document id **is** the
  token. The client removes the token on sign-out / when push is turned off and
  replaces it on token refresh.
* The backend sends with `sendEachForMulticast` and **deletes** tokens that fail
  with `messaging/registration-token-not-registered` or
  `messaging/invalid-registration-token`.
* Message shape (`buildPushMessage`): a `notification` block (title/body — this
  is what the OS shows when the app is in the background or terminated) plus
  `data: { notificationId, reportId, type }` only. No other personal data is
  placed in the payload.
* Tapping the push opens `/reports/detail` with `reportId`. The destination
  resolves the report from the signed-in user's own data, so a push can never
  reveal a report the user may not read.

## Activity history (audit trail)

`/reports/{reportId}/activity/{activityId}` is append-only (rules: no
update/delete). Today clients append events for their own actions
(submitted, assigned, repair started/completed, priority changes). Events that
only the server can know — **community verified** and **dispute opened**
(Member 7) — should be appended by the verification/dispute Cloud Functions
using the same shape:

```json
{
  "id": "<activityId>", "reportId": "AT-2026-00124",
  "title": "Community Verified",
  "description": "3 nearby citizens confirmed the repair is complete.",
  "actorName": "Community", "actorRole": "Citizen Verification",
  "status": "completed",
  "timestamp": "<Firestore Timestamp or ISO-8601 string>"
}
```

The client reads without a server-side `orderBy` and sorts by parsed
timestamp (ties by id), so Timestamp and ISO-string events interleave
correctly.

## Known limitations

* The user's local "Push Notifications" switch (Settings) is device-local; the
  server cannot see it. Turning it off removes this device's token, which is
  what actually stops delivery to that device.
* If the notification document is created but the push send fails, a retry of
  the same event will skip the (already existing) document and will not re-push.
* `firebase-functions` / `firebase-admin` versions in `package.json` were not
  installed or exercised here.
