# AquaTrace — Update Log

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
