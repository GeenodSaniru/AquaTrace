# AquaTrace — Update Log

## 2026-11-13 20:59:46 +05:30 (Asia/Colombo, UTC+05:30) — Member 4 final map QA

### Completed
- Re-audited the map implementation, shared report/model contracts, role handoff documentation, README, prior update entries, Git status, and the map-related UI PDF inventory before editing.
- Made map search functional across report ID, address, reporter, and fault type while retaining status filter chips and `FaultStatus.color` marker/legend colors.
- Added safe coordinate validation to `ReportModel.fromMap`; missing, non-finite, or out-of-range reports are marked non-mappable and skipped by the map instead of being placed at a false default location.
- Added current-location service checks, permission request/denial handling, unavailable-location feedback, map-readiness guards, and bounded zoom controls.
- Added coordinate regression coverage for valid, missing, and out-of-range report coordinates.
- Preserved the existing `flutter_map` tile boundary and avoided unsupported offline tile API changes; no repeated Firestore reads were added by the map.
- Rechecked `docs/AquaTrace UI.pdf`; the browser exposes a blank canvas for its single Figma frame, while the extracted screen inventory confirms map search, nearby markers, status filters, and zoom controls.

### Checks
| Command | Result |
|---------|--------|
| `dart format lib/features/map/presentation/shared_map_view.dart lib/core/models/report_model.dart test/map_regression_test.dart` | Pass; all three files formatted. |
| Workspace diagnostics (`get_errors`) | No errors in the map view, report model, or coordinate regression test. |
| `flutter analyze --no-pub` | Invoked; terminal did not return a completion line. Focused workspace diagnostics are clean. |
| `flutter test --no-pub test/map_regression_test.dart` | Invoked; runner did not return a completion result, so no passing count is claimed. |
| `flutter run -d chrome --web-port 5174` | Reached Chrome debug launch but did not complete compilation; browser received HTML for `main.dart.js` and refused execution due to MIME type. Process stopped. |
| PDF review | Single-page PDF opened and screenshot captured; rendered canvas was blank, extracted text used for map screen confirmation. |

### Limitations / blockers
- Live tile loading/offline fallback, browser geolocation prompts, and navigation handoff could not be exercised because the Flutter web debug build did not complete and no authenticated runtime/device was available.
- The existing map detail interaction remains a modal report summary; a dedicated cross-module report-detail route is not defined by the shared routing contract.
- Firestore performance is bounded by the repository's existing report synchronization limit; the map itself performs no additional Firestore queries.

## 2026-11-11 14:04:14 +05:30 (Asia/Colombo, UTC+05:30) — Member 5 integration audit and Firestore hardening

### Completed
- Re-audited the current admin, report, user, role, Firestore rules, README, handoff, prompts, and UI PDF/extracted screen inventory before editing.
- Extended the shared `ReportModel` contract with optional `assignedAt`; admin assignment now persists technician UID, name, assignment timestamp, assigned status, and updated timestamp without rewriting unrelated report fields.
- Added bounded Firestore report synchronization (`createdAt` descending, limit 500), loading/error state, retry handling, and admin UI error/loading feedback for stale or failed refreshes.
- Fixed nullable repair-note persistence and added focused admin workflow tests for missing-role rejection, invalid transitions, correction requests, and assignment timestamps.
- Hardened Firestore admin rules to allow only workflow fields and only preserve status or move pending/disputed reports to assigned; technicians cannot modify `assignedAt`.
- Persisted admin activity events to `/reports/{reportId}/activity/{activityId}` using the shared activity model for Member 8 and downstream citizen/technician visibility.
- Rechecked `docs/AquaTrace UI.pdf`: the browser renderer still exposes a blank canvas for the single Figma frame; the repository's extracted text remains the available admin review/assignment/activity reference.
## 2026-11-11 14:54:06 +05:30 (Asia/Colombo, UTC+05:30) — Member 4 interactive map and location services

### Completed
- Implemented the shared citizen/technician/admin OpenStreetMap view using the existing `flutter_map`, `latlong2`, and `geolocator` dependencies, with report markers/status colors, detail selection, status filters, local report search, zoom/location controls, attribution, and technician external-directions handoff.
- Connected the map to the shared Firestore report snapshots with a 500-report query cap; configured Firebase flows do not fall back to demo reports. Invalid/missing coordinates are excluded and surfaced to the user.
- Added configurable tile URL and attribution, permission/error/retry/loading/empty/offline handling, and README guidance on OSM tile usage and the absence of an external geocoder.
- Fixed the live-web permission-settings action: browsers now receive instructions to change permission in browser settings instead of invoking unsupported native settings APIs. Missing native settings plugins also show an explicit fallback message.
- Files changed: `README.md`, `lib/core/config/app_config.dart`, `lib/core/models/report_model.dart`, `lib/core/services/data_repository.dart`, `lib/features/map/presentation/shared_map_view.dart`, `lib/features/technician/presentation/technician_home_view.dart`, `lib/features/technician/presentation/technician_main_shell.dart`, `macos/Flutter/GeneratedPluginRegistrant.swift`, `pubspec.yaml`, `pubspec.lock`, and `test/map_view_test.dart`.

### Checks
| Command | Result |
|---------|--------|
| `dart format lib test` | Pass; changed Dart sources and focused test formatted. |
| Workspace diagnostics (`get_errors`) | No errors in `report_model.dart`, `data_repository.dart`, admin dashboard/review, or `admin_workflow_test.dart`. |
| `flutter analyze --no-pub` | Invoked; terminal integration returned formatter output but did not return the analyzer completion line. Workspace diagnostics are clean for touched Dart files. |
| `flutter test --no-pub test/admin_workflow_test.dart` | Invoked; runner remained active after startup without a completion result and was terminated. No pass count claimed. |
| `flutter build web --no-pub --no-wasm-dry-run` | Previously invoked and generated `build/web`; this run was not re-completed because Flutter/Dart workers remained non-returning. |
| App launch | Not verified in this run; no reliable Flutter process completion/device session was available. |
| PDF review | One-page UI PDF opened and screenshot captured; canvas was blank, extracted text reviewed for admin screens. |

### Outstanding / blockers
- Live Firebase authorization, permission-denied behavior, assignment against real `/users` technician documents, and Firestore activity reads require authenticated accounts and a configured runtime session.
- Existing Member 8 timeline UI and Member 6 technician UI must consume the shared Firestore activity and `assignedAt` fields; their modules were not rewritten.
- The repository still has the unrelated generated `macos/Flutter/GeneratedPluginRegistrant.swift` working-tree change from Flutter tooling; it is excluded from the Member 5 commit.

## 2026-11-11 13:45:07 +05:30 (Asia/Colombo, UTC+05:30) — Member 5 admin dashboard and report management

### Completed
- Added admin-only dashboard and report-management surfaces with real report counts, status filters, search, priority display, evidence fallback, activity history, empty states, and refresh interaction.
- Replaced the fixed September trend bars with five weekly buckets derived from report `createdAt` values and a meaningful latest-report date range.
- Added admin review actions supported by the shared five-status contract: approve-and-assign transitions pending/disputed reports to assigned; request correction keeps the report pending and records an audit note. No unsupported rejected status was invented.
- Added admin priority updates and technician assignment using existing stored technician UID/name data only; no fabricated availability data is shown.
- Added repository authorization and status-transition validation. Live Firebase mutations verify `/users/{uid}.role == admin` before admin actions and persist only the intended report fields. The existing Firestore rules remain the server-side authority.
- Added the declared `assets/icons/` directory so the existing pubspec asset declaration no longer blocks Flutter validation.
- Files changed: `lib/core/services/data_repository.dart`, `lib/features/admin/presentation/admin_dashboard_view.dart`, `lib/features/admin/presentation/admin_main_shell.dart`, `lib/features/admin/presentation/admin_reports_view.dart`, and `assets/icons/`.

### Checks
| Command | Result |
|---------|--------|
| `dart format lib test` | Pass — 3 changed Dart files formatted. |
| `flutter analyze --no-pub` | No Dart errors from workspace diagnostics; the previous missing `assets/icons/` asset blocker was resolved. |
| `flutter test` / `flutter test --no-pub --reporter compact` | Invoked; terminal integration did not return a final completion line after web compilation began, so a passing test count cannot be claimed. |
| `flutter build web --no-pub --no-wasm-dry-run` | Invoked; `build/web/index.html` and generated web assets are present, but the terminal did not return a final success line. |
| PDF inspection | `docs/AquaTrace UI.pdf` located and opened in the browser as a one-page Figma frame; the browser PDF renderer exposed a blank canvas, so extracted project text was used for the screen inventory. |

### Outstanding / blockers
- End-to-end live Firebase admin writes, permission-denied behavior, and real technician directory selection require authenticated Firebase accounts and current Firestore data; demo identities remain local mock auth.
- The five-status shared contract has no `rejected` or `correctionRequested` enum, so correction is represented by a pending status plus an audit note. Member 3/6/7/8 integration should preserve this contract.
- Local commit created after scoped diff review; push status is recorded in the handoff response because the remote requires an explicit authentication check.

| `dart format lib\features\map\presentation\shared_map_view.dart test\map_view_test.dart` | Pass — no formatting changes required. |
| `flutter test test\map_view_test.dart` | Pass — **11/11**, including map filters, search, coordinate validation, zoom, location permissions, settings-plugin failure, and technician directions handoff. |
| `flutter test` | Pass — **33/33**. |
| `flutter analyze` | No Dart diagnostics; exits nonzero only for the existing missing `assets/icons/` directory declared in `pubspec.yaml`. |
| `flutter build web --no-wasm-dry-run` | Pass — release web bundle built. Flutter reports the same missing `assets/icons/` warning. |
| Release browser smoke (`http://127.0.0.1:5175/#/map`) | OSM map/tiles, attribution, map controls, empty state, and location-permission message verified. Clicking **App settings** now shows browser-settings guidance without a page error. |
| `git diff --check` | Pass. |

### Outstanding / blockers
- No authenticated Firebase session was available, so live Firestore marker reads were not verified; the configured unauthenticated map correctly shows an empty state instead of sample reports.
- No physical mobile device/emulator was available. Permission grant/denial and plugin failure behavior is covered by mocked geolocator tests; device permission prompts/settings screens were not verified on hardware.
- No geocoder is configured; search is intentionally limited to report data already loaded by the app.
- Existing `assets/icons/` directory is missing although declared in `pubspec.yaml`; analyzer/build emit this pre-existing warning.

## 2026-11-10 21:21:00 +0530 (UTC+0530) — Member 2 final regression and handoff

### Completed
- Re-read repository Markdown guidance, the latest update history, current profile/auth/theme/storage contracts, and inspected the profile/settings cluster in `docs/AquaTrace UI.pdf`.
- Fixed profile header fallbacks for whitespace-only names and service areas; mapped Firebase Storage `unauthorized` and retry-limit/network failures to clear user guidance.
- Added final regression coverage for malformed account fields, invalid profile name/phone, photo-library permission denial, upload denial/network failure, unsupported/empty/oversized images, user-scoped preferences, appearance persistence, save/cancel flows, and role-specific account details.
- Reviewed privacy exposure: profile uses only the authenticated `AuthProvider.currentUser`; Firestore edits continue through the existing safe `AuthProvider.updateProfile` contract; sign-out remains delegated to `AuthProvider.signOut`.

### Checks and outcomes
| Command / exercise | Result |
|--------------------|--------|
| `dart format lib test` | Pass — 55 files, no formatting changes |
| `flutter analyze` | Pass — no issues found |
| `flutter test` | Pass — 36/36 |
| `flutter build web --release` | Pass — release bundle generated |
| `flutter run -d web-server --release --web-port 5177` | Pass — release app served; demo citizen profile, appearance control, Edit Profile, Help & Support, and About rendered |
| `git diff --check` | Pass |

### Remaining work / cross-module dependencies
- Profile avatar rules are present in `storage.rules` and deployed configuration, but live bucket upload and Storage-rule emulator validation remain unverified; the local shell has no `firebase` or `java` executable. Enable Storage and deploy the reviewed rules before relying on cloud uploads.
- Notification delivery, weekly email, GPS permission enforcement, anonymous reporting, community verification, usage analytics, and data export depend on other services/modules and remain explicitly marked as local-only or unavailable in the UI.
- Windows desktop build remains unavailable because Windows desktop support is not configured in this checkout; release web build/launch passed.

## 2026-11-10 12:40:24 +0530 (UTC+0530) — Member 2 profile integration QA

### Completed
- Fast-forwarded `sasundi` to the integrated remote state `3a597e0`, including Member 3's reporting module and Firebase Storage rules configuration.
- Rechecked the AquaTrace UI PDF and current profile/settings implementation against its profile, edit-profile, notification, location, privacy, accessibility, help/support, and about screens.
- Added an owner-only Storage rule for `users/{uid}/profile/avatar`, matching the existing profile upload path; reads require sign-in, writes require matching Auth UID, image MIME type, and a 5 MB limit. Existing report-evidence rules are unchanged.
- Aligned profile-photo validation with the Storage MIME allowlist and added tests for unsupported, empty, and oversized photos, blank profile fields, and persisted appearance.

### Checks and outcomes
| Command / exercise | Result |
|--------------------|--------|
| `dart format lib test` | Pass — 55 files; no formatting changes |
| `flutter analyze` | Pass — no issues found |
| `flutter test test/widget_test.dart` | Pass — 21/21 |
| `flutter test` | Pass — 33/33, including report-submission tests |
| `flutter run -d web-server --release --web-port 5176` | Pass — built and served `build/web`; citizen Profile and Accessibility screens rendered |
| Firebase Storage emulator/rules validation | Not run — `firebase` and `java` executables are unavailable in this shell |

### Remaining work / blockers
- `storage.rules` now contains the profile-avatar rule and `firebase.json` includes Storage rules, but rules have not been deployed and the live Storage bucket/upload path was not exercised. Enable/configure Firebase Storage and deploy the reviewed rules before relying on cloud uploads.
- Notification delivery, weekly email, GPS permission enforcement, anonymous reporting, community verification, usage analytics, and data export remain local-only or unavailable, as noted in the UI.
- Windows desktop build remains unavailable because the Windows desktop project is not configured; web release launch is verified.

## 2026-11-09 13:19:39 +0530 (UTC+0530) — Member 2 profile and settings

### Completed
- Replaced the profile placeholder with authenticated-user account details, role-specific employee ID, profile editing, photo selection/upload flow, appearance preference, and navigation to notification, location, privacy, accessibility, help, and about screens.
- Added UID-scoped local preference persistence for notification categories, location area/access choice, privacy choices, text size, and contrast. Text scaling and high-contrast styling are applied app-wide; appearance remains persisted by `ThemeProvider`.
- Added Firebase Storage upload to `users/{uid}/profile/avatar`, image type/size checks, and user-facing picker/upload failure handling. Profile edits still use the existing safe `AuthProvider` update contract.
- Added widget coverage for preference isolation, role-specific profile fields, all settings navigation, save/cancel, persistence, accessibility settings, and simulated upload-denial behavior.
- Aligned the Dart SDK minimum with the documented Dart 3.13+ support/current 3.13.0 SDK, added the Firebase Storage dependency/plugin registration, and removed the unused `assets/icons/` directory declaration that prevented Flutter asset bundling.

### Files / modules changed
- `lib/features/profile/presentation/shared_profile_view.dart`
- `lib/features/profile/presentation/profile_settings_screens.dart`
- `lib/features/profile/profile_photo_service.dart`
- `lib/core/services/preferences_service.dart`
- `lib/main.dart` (app-wide text scale and contrast application)
- `test/widget_test.dart`
- `pubspec.yaml`, `pubspec.lock`, `macos/Flutter/GeneratedPluginRegistrant.swift`

### Checks and outcomes
| Command | Result |
|---------|--------|
| `flutter pub get` | Pass |
| `dart format lib test` | Pass — 51 files formatted, no changes needed |
| `flutter analyze` | Pass — no issues found |
| `flutter test test/widget_test.dart` | Pass — 18/18 |
| `flutter run -d web-server --release --web-port 5175` | Pass — web release compiled and served; Profile and Notification Settings rendered in browser |
| `flutter build windows --debug` | Not available — Windows desktop project is not configured in this checkout |
| `git diff --check` | Pass; generated macOS Swift file reports only a line-ending normalization warning |

### Remaining work / blockers
- Firebase Storage is not enabled/configured with storage rules in this repository. Real cloud photo upload is not verified; enable Storage and coordinate a self-only rule for `users/{uid}/profile/avatar` before production use. Upload denial is surfaced in the UI.
- Push delivery, weekly email, GPS permission enforcement, anonymous reporting, community verification, usage analytics, and data export are not connected in this build. Their settings are persisted locally and explicitly identified as not connected.
- Windows desktop launch/build remains unavailable until desktop support is added to the project. Web release startup is verified.

### Git
- 2026-11-09 13:23:07 +0530 (UTC+0530): committed on `sasundi` as `133eeecadadcd523013354251d5c47ba3b9e33c4` (`feat(profile): implement profile and settings module`).
- The initial push attempt was rejected, then completed after Git Credential Manager browser authentication. `git ls-remote origin refs/heads/sasundi` verified the branch at `5f155f1fd6ecbe85af2f98533a3c910ac992f594` on 2026-11-09.
## 2026-11-09 12:48:59 +05:30 (Asia/Colombo, UTC+05:30) — Member 3 citizen fault reporting

### Completed
- Replaced the citizen home reporting placeholder with a routed fault-report form for fault type, description, severity, street/landmark, GPS coordinates, and evidence photo.
- Added camera/gallery selection, image type/size checks, location permission/GPS error states, coordinate review/confirmation, required-field validation, and protection against duplicate taps or leaving during submission.
- Added Firebase Storage evidence upload and idempotent Firestore report creation using the agreed `ReportModel` fields, authenticated reporter UID, UUID-based report ID, numeric coordinates, UTC creation time, `pending` initial status, and evidence download URL.
- Added report snapshot synchronization to the shared repository and owner-restricted `storage.rules` configuration.
- Added focused success, validation, permission, picker cancellation, upload failure, Firestore failure, and duplicate-submission tests.
- Files changed: `firebase.json`, `lib/core/navigation/app_router.dart`, `lib/core/services/data_repository.dart`, `lib/core/services/report_submission_gateway.dart`, `lib/features/citizen/presentation/citizen_home_view.dart`, `lib/features/reports/presentation/citizen_report_form_screen.dart`, `lib/features/reports/services/citizen_report_input_provider.dart`, `macos/Flutter/GeneratedPluginRegistrant.swift`, `pubspec.yaml`, `pubspec.lock`, `storage.rules`, `test/report_submission_test.dart`.

### Checks
| Command | Result |
|---------|--------|
| `dart format lib test` | Pass — formatted reporting changes. |
| `flutter analyze` | No Dart issues; existing warning: configured asset directory `assets/icons/` is missing. |
| `flutter test test/report_submission_test.dart` | Pass — 12/12. |
| `flutter test` | Pass — 22/22. |
| `flutter build web` | Pass — `build/web` generated; existing missing `assets/icons/` warning and non-blocking wasm dry-run notice. |
| Browser smoke (`http://localhost:5173/#/reports/new`) | Pass — form rendered at desktop/mobile sizes; empty submit showed required-field errors. |

### Outstanding / blockers
- Live Storage upload and Firestore persistence were not verified: Firebase Storage is not enabled/configured for the project in this environment, and no authenticated Firebase citizen account was available. Demo-role identities are intentionally rejected by the submission gateway. Deploy/enable the owner-scoped Storage rules only after the project Storage bucket is enabled and authorized.
- Camera and physical GPS permission behavior is covered through injected platform-provider tests; no mobile device/emulator was available for a physical permission prompt test.
- Existing `assets/icons/` folder is missing although declared in `pubspec.yaml`; analysis/build report this warning.
- Citizen-home shared report-card background/overflow console warnings observed during smoke test are outside this module's changes.
- Exact checks: `dart format lib test`; `flutter analyze`; `flutter test test/report_submission_test.dart`; `flutter test`; `flutter build web`.

## 2026-11-03 18:29:44 +0530 (UTC+0530) — Member 1 remaining cloud hardening complete

### Completed
- Deployed `firestore.rules` to `aquatrace-92e2e` (compiled clean; unused `isStaff` removed).
- Enabled Authentication **Email/Password**.
- Applied Google Cloud API key **application restrictions**:
  - Android: `com.aquatrace.aquatrace` + debug SHA-1
  - iOS: bundle `com.aquatrace.aquatrace`
  - Browser: localhost + Firebase Hosting referrers
- Seeded staff Auth users + `/users/{uid}` docs: `admin@aquatrace.lk` (admin), `tech@aquatrace.lk` (technician).
- Added `scripts/member1_cloud_hardening.py`; gitignored `scripts/.seed_credentials.local.json`.
- Verified: `flutter analyze` clean; `flutter test` **10/10**.

### Not done (out of automated scope / intentional)
- GitHub Secret Scanning alerts **not** auto-dismissed (expected client keys — dismiss manually as false positive if desired).
- API keys **not rotated** (not required; restrictions applied instead).
- Release Android SHA-1 not added yet (debug only).
- Google/Apple OAuth still stubbed.

---

## 2026-11-03 18:12:33 +0530 (UTC+0530) — Member 1 prompts 1A–1C complete

### Completed tasks (Member 1)
- **1A:** Confirmed feature-first foundation, theme/widgets/routing/README remain intact; documented Firebase project + OAuth/setup gaps.
- **1B:** Public registration hard-locked to **citizen**; removed privileged role ChoiceChips from `RegisterScreen`.
- **1B:** `AuthService.updateProfile` patches only safe fields (never `role`/`email`/`uid`/`employeeId`).
- **1B:** Documented role security model + `firestore.rules` in README §7; Google/Apple remain graceful stubs with setup notes.
- **1C:** Added `docs/MEMBER1_HANDOFF.md` for Members 2–8; reviewed init/auth/routing contracts.

### Files / modules changed
- `lib/core/services/auth_service.dart`
- `lib/features/auth/providers/auth_provider.dart`
- `lib/features/auth/presentation/register_screen.dart`
- `lib/features/auth/presentation/login_screen.dart`
- `test/widget_test.dart`
- `README.md`
- `docs/MEMBER1_HANDOFF.md`
- `firestore.rules` / `firestore.indexes.json` / `firebase.json` (from prior rules work; included in this handoff)

### Tests / commands
| Command | Result |
|---------|--------|
| `dart format lib test` | Pass |
| `flutter analyze` | Pass — no issues |
| `flutter test` | Pass — **10/10** |
| `flutter run -d chrome` | Pass — debug service connected; Flutter run key commands shown |

### Remaining / blockers (not Member 1 feature scope)
- Deploy `firestore.rules` only when explicitly authorized.
- Enable Email/Password + create Firestore DB in Console if not already.
- Seed first admin/technician via Admin SDK.
- Members 3–8 still own Firestore sync for reports, Storage, FCM, verification Functions.
- macOS Firebase SPM cold build can be slow; Chrome smoke used for launch verification.

---

## 2026-11-03 18:03:41 +0530 (UTC+0530) — Firestore security rules (proposed, not deployed)

### Completed tasks
- Reviewed README contracts, models, `AuthService`, `DataRepository`, register UI, and UI verify/dispute references.
- Added production-oriented `firestore.rules` covering users, notifications, reports, activity, verifications, disputes.
- Wired `firebase.json` → `firestore.rules` + empty `firestore.indexes.json`.
- Documented required backend/client changes (force citizen registration, Admin SDK role seed, Cloud Functions for counters).

### Explicitly not done
- **No deploy** to Firebase Console / `aquatrace-92e2e`.
- Console security rules **unchanged**.
- Emulator syntax load blocked: Java runtime missing on this machine (`firebase emulators:exec` failed locating JRE).

### Validate later
1. Install a JRE, then `firebase emulators:exec --only firestore --project aquatrace-92e2e "echo ok"`.
2. Or paste `firestore.rules` into Console → Firestore → Rules Playground.
3. Deploy only when authorized: `firebase deploy --only firestore:rules --project aquatrace-92e2e`.

---

## 2026-11-03 15:08:14 +0530 (UTC+0530) — Firebase project configuration

### Completed tasks
- Installed Firebase CLI (`15.34.2`) and FlutterFire CLI (`1.4.1`).
- Authenticated Firebase CLI as `geenodsaniru@gmail.com`.
- Connected the Flutter app to the **existing** Firebase project **AquaTrace** (`aquatrace-92e2e`) — no new Firebase project created.
- Registered Firebase apps for Android, iOS, and Web (macOS reuses the iOS app / same bundle id `com.aquatrace.aquatrace`).
- Generated real `lib/core/config/firebase_options.dart` for project `aquatrace-92e2e` (kept `DefaultFirebaseOptions.isConfigured` for the existing `FirebaseService` architecture).
- Added/confirmed native client configs:
  - `android/app/google-services.json`
  - `ios/Runner/GoogleService-Info.plist`
  - `macos/Runner/GoogleService-Info.plist`
- Confirmed Android Google Services Gradle plugin wiring in `android/settings.gradle.kts` and `android/app/build.gradle.kts` (FlutterFire partial apply).
- Added `.firebaserc` (default `aquatrace-92e2e`) and `firebase.json` FlutterFire platform map.
- Hardened `.gitignore` for service-account / private-key patterns (no admin SDK JSON committed).
- Preserved existing `FirebaseService.initialize()` startup flow in `lib/main.dart` (still uses `DefaultFirebaseOptions`).
- Fixed demo-role widget test navigation stubbing so auth assertions do not mount role shells.
- Added unit coverage asserting Firebase options target `aquatrace-92e2e`.

### Configuration changes
| Item | Value |
|------|--------|
| Firebase project ID | `aquatrace-92e2e` |
| Android applicationId | `com.aquatrace.aquatrace` |
| iOS / macOS bundle ID | `com.aquatrace.aquatrace` |
| Android app ID | `1:298509402653:android:db2fc54fac90b6b5b47cf4` |
| iOS app ID | `1:298509402653:ios:e62995a1bb869e46b47cf4` |
| Web app ID | `1:298509402653:web:cca7d1291ccb34d9b47cf4` |

### Firebase services configured in the app (dependencies / init)
- **Firebase Core** — configured and initialized via `FirebaseService` + generated options.
- **Firebase Auth** / **Cloud Firestore** — already depended on in `pubspec.yaml` and used by `AuthService` when `FirebaseService.isRealFirebase == true`.
- **Not enabled/deployed in this run:** Firebase Storage rules, FCM, Analytics product toggles, unrestricted Firestore/Storage security rules (intentionally avoided).

### Tests and build results
| Check | Result |
|-------|--------|
| `dart format lib test` | Pass (no formatting changes required) |
| `flutter analyze` | Pass — no issues found |
| `flutter test` | Pass — **8/8** tests |
| `flutter build apk --debug` | Pass — `build/app/outputs/flutter-apk/app-debug.apk` |
| macOS / web debug builds | Attempted; stopped after long Firebase iOS SPM / toolchain fetch with no completion in-session. Android APK remains the verified native build. |
| Firebase options unit test | Pass — project/app IDs match `aquatrace-92e2e` |
| Runtime `Firebase.initializeApp` console log | Wired in `FirebaseService` (logs projectId/appId). Full device/emulator sign-in against live Auth/Firestore still blocked until Console products are enabled (see remaining steps). |

### Notes / environment blockers during FlutterFire CLI
- `flutterfire configure` registered apps and wrote native config files, but failed on Ruby `xcodeproj` gem dependency chain (`rexml`/`nkf`) under Homebrew Ruby 4.0.
- Completed `firebase_options.dart` and remaining wiring from `firebase apps:sdkconfig` outputs for the registered apps (same project, no duplicate Firebase project).

### Remaining manual steps (Firebase Console / Google Cloud)
1. **Enable Email/Password** in Firebase Authentication → Sign-in method.
2. **Enable Cloud Firestore API** for `aquatrace-92e2e` (CLI reported API unused/disabled: enable at Google Cloud Console → Firestore API, then create the Firestore database).
3. Apply **locked-down** Firestore security rules (do **not** use open `allow read, write: if true`).
4. Optionally enable **Storage** / **FCM** later when Members 3/8 need them — not required for Core init.
5. Optionally add `GoogleService-Info.plist` to the Xcode target membership if native iOS/macOS tooling requires it beyond Dart `Firebase.initializeApp(options:)` (Dart options path is active).
6. Create at least one real Auth user + `/users/{uid}` profile doc with a valid `role` for end-to-end sign-in testing outside demo buttons.

### Git
- Target branch: `geenod` (not `main`).
