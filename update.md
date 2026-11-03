# AquaTrace — Update Log

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
