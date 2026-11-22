# AquaTrace notification and aggregation backend (Member 8)

Reference implementation of the **trusted** side of notifications and of the
community verification / dispute aggregation. The Flutter client only *reads*
notifications and marks them read; it can never create one, and it cannot write
report counters, the `disputed` status or other people's activity
(`firestore.rules` denies all of that). Those writes must come from code running
with the Admin SDK — this folder.

> **Status — not deployed, not emulator-tested.**
> `notification_events.js` (who gets which notification, counting rules,
> preferences, push text) and the app/rules/backend document contracts are unit
> tested with `npm test` (40 tests, no Firebase needed). `index.js` (Firestore
> triggers, transactions, FCM send) has **not** been deployed or run against the
> Firebase emulator in this repository. Until it is deployed and verified,
> server-created notifications, vote/dispute counting and push delivery are
> **not** working end to end. The client side is complete and contract-tested.

## Deploy checklist

1. `cd functions && npm install`
2. `npm test` (pure logic + contract tests, no Firebase needed).
3. Set the function region to match the Firestore database location
   (`setGlobalOptions({ region: ... })` in `index.js`; default is `us-central1`).
4. Optional: `COMMUNITY_VERIFICATION_THRESHOLD` environment variable (default
   `3`; must equal the app's `CommunityVerificationService.confirmationThreshold`).
5. Deploy: `firebase deploy --only functions --project aquatrace-92e2e`
   (requires the Blaze plan).
6. Deploy the updated rules: `firebase deploy --only firestore:rules`.
   **Deploy functions and rules together** — the app's vote / dispute documents
   are only counted by the functions, and only accepted by the updated rules.
7. **Android:** nothing else (the app's `google-services.json` is committed).
8. **iOS / macOS:** upload an APNs auth key (`.p8`) in Firebase Console →
   Project settings → Cloud Messaging, and enable the *Push Notifications*
   capability for the Runner target in Xcode (needs an Apple Developer team).
   **Never commit the `.p8`.**
9. **Web:** browser push is not wired (needs a service worker + VAPID key).
10. Smoke test in the emulator or a staging project (see "Verification plan").

## Workflow events → who writes what

| Event (module) | Written by | Trigger | Result |
|---|---|---|---|
| Report submitted (Member 3) | citizen app | `onReportCreated` | admins: *New / Emergency Report Submitted* |
| Approved & technician assigned, priority (Member 5) | admin app | `onReportUpdated` | reporter: *Report Approved* + *Technician Assigned*; technician: *New Job Assigned* |
| Repair started / completed (Member 6) | technician app | `onReportUpdated` | reporter: *Repair Started* / *Repair Completed*; admins: *Repair Completed*; **nearby citizens** (same `assignedArea`, max 50): *Verify Repair* |
| Community confirmation (Member 7) | citizen app → `verifications/{voter}` | `onVerificationCreated` | server counts it, appends audit event; on the vote that reaches the threshold: *Community Verified* audit event + notifications to reporter, technician, admins |
| Community dispute (Member 7) | citizen app → `disputes/{voter}` | `onDisputeCreated` | server counts it, sets status `disputed`, appends audit event; notifies admins, technician, reporter, and the disputing citizen |

Rules of the road:

* **One source per notification.** `disputed` notifications are produced only by
  `onDisputeCreated`; the report-update trigger deliberately emits nothing for
  `→ disputed` (otherwise everyone would be notified twice). Counter updates by
  the functions do not change `status`, so they never re-trigger notifications.
* **The reporter is never asked to verify their own repair** (Member 7's
  eligibility rules forbid it). They get an informational *Repair Completed*.
  The *Verify Repair* request goes to citizens whose profile area matches the
  report's `assignedArea` (a coarse proxy for "nearby"; the verification screen
  still enforces the real 5 km GPS check). A geo index would make this precise —
  not done.
* **Invalid references are skipped, never errors:** deleted report, deleted user
  (`users/{uid}` missing), blank uids, a vote on a report that is no longer
  `completed` (marked `rejected`, not counted).

## Idempotency (no duplicate notifications, counts or audit entries)

* Event-driven notifications use id `<triggerEventId>_<recipientUid>_<kind>`;
  a retried invocation hits `ALREADY_EXISTS` and is skipped (no second record,
  no second push).
* Milestone / dispute notifications use a **logical** id
  (`community-verified-<reportId>_<uid>`, `dispute-<reportId>-<voterUid>_<uid>`),
  so they are also safe across retries and across triggers.
* Vote / dispute documents are marked `counted: true, countedAs: n` in the same
  transaction as the counter update; a retry re-derives the same outcome and
  does not count again.
* Audit events use deterministic ids (`verification-<uid>`, `community-verified`,
  `dispute-<uid>`) created once (`create()`), so the trail is append-only and
  immutable (rules: no update / delete).
* If the notification document is created but the push send fails, the retry
  skips the (existing) document and will not re-push.

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
* `createdAt` **must be a Firestore `Timestamp`** (`FieldValue.serverTimestamp()`).
  The client query is `orderBy('createdAt', descending: true)`; Firestore orders
  mixed types by type first, so do not mix ISO strings and Timestamps. (The
  client tolerates either when *parsing*.)
* Only `isRead` is client-writable (rules enforce this).

## Vote / dispute document contract (written by the app, counted by the backend)

`/reports/{id}/verifications/{voterUid}` — `voterUid, voterName, reportId, createdAt, note?`
`/reports/{id}/disputes/{voterUid}` — `voterUid, voterName, reportId, reason, evidenceImageUrl?, createdAt`

The app writes **only these documents**. The backend adds `counted`,
`countedAs` (and `rejected`) with the Admin SDK. `contract.test.js` fails if the
app's fields ever drift from what `firestore.rules` accepts.

## Preferences

The app mirrors the Settings switches to
`/users/{uid}/settings/notifications` (client sync: 8B part 3):

```json
{ "pushEnabled": true, "reportUpdates": true, "repairVerification": true, "nearbyFaults": true, "updatedAt": "<server timestamp>" }
```

The backend honours them (missing document or field = enabled):

| Setting | Effect |
|---|---|
| `reportUpdates: false` | no in-app record and no push for approval / assignment / dispute / update notifications |
| `repairVerification: false` | none of the verification requests or community milestones |
| `pushEnabled: false` | in-app record is still created; no push |
| `nearbyFaults` | stored; **no producer yet** (there is no "new fault near you" notification) |

## Push (FCM) contract

* Devices register at `/users/{uid}/fcmTokens/{token}`
  (`token`, `platform`, `createdAt`, `updatedAt`); the document id **is** the
  token. The client removes the token on sign-out / when push is turned off and
  replaces it on token refresh.
* The backend sends with `sendEachForMulticast` and **deletes** tokens that fail
  with `messaging/registration-token-not-registered` or
  `messaging/invalid-registration-token`.
* **Privacy:** the OS-visible text (lock screen / shade) is deliberately generic:
  title = the notification title, body = `Report <id>. Open AquaTrace for
  details.` No names, addresses, dispute reasons or recipient uids. The `data`
  block is exactly `{ notificationId, reportId, type }`. The full message lives
  in the access-controlled notification document, shown after authentication.
* Tapping the push opens `/reports/detail` with `reportId` and `type`. The
  destination resolves the report from the signed-in user's own data, so a push
  can never reveal a report the user may not read; a `verification` push for a
  completed repair opens the community verification screen only for an eligible
  citizen (not the reporter / technician).

## Activity history (audit trail)

`/reports/{reportId}/activity/{activityId}` is append-only (rules: no
update/delete; read = admin, citizen, or the assigned technician). Clients append
events for their own actions (submitted, assigned, repair started/completed,
priority changes). The backend appends what only it can know:
*Community Verification Confirmed*, *Community Verified* and *Dispute Raised*
(no voter name or dispute reason in the public trail).

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

The client reads without a server-side `orderBy` and sorts by parsed timestamp
(ties by id), so Timestamp and ISO-string events interleave correctly.

## Verification plan (to run once deployed / in the emulator)

1. Submit a report as a citizen → admin gets *New Report Submitted*.
2. Assign a technician as admin → reporter gets 2 notifications, technician 1.
3. Technician starts and completes → reporter *Repair Started* / *Repair
   Completed*; citizens in the same area get *Verify Repair*.
4. Three citizens confirm → `verificationCount` = 3, one *Community Verified*
   audit event, one milestone notification per recipient; a 4th confirmation
   adds nothing.
5. A citizen disputes → report becomes `disputed`, `disputeCount` = 1, one audit
   event, four notifications; re-run the same event (replay) → no duplicates.
6. Turn *Report Updates* off for a user → they receive none of 2–5's updates.
7. Delete the report / the recipient and replay → no errors, no notifications.

## Known limitations

* The user's local "Push Notifications" switch is mirrored to Firestore only
  while signed in with a real Firebase session; turning it off also removes this
  device's token.
* `firebase-functions` / `firebase-admin` versions in `package.json` were not
  installed or exercised here.
* "Nearby" is the profile area, not GPS (see above). No notification is produced
  for the `nearbyFaults` preference yet.
