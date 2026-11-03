# Member 1 — Foundation handoff (for Members 2–8)

**Branch:** `geenod` (merge to `main` when the team agrees)  
**Firebase project:** `aquatrace-92e2e`  
**Do not duplicate:** `lib/main.dart` bootstrap, `FirebaseService`, `AppTheme`, `AppRouter`, shared models under `lib/core/models/`, or `AuthService` / `AuthProvider` without coordination.

## What Member 1 owns (stable contracts)

| Area | Location |
|------|----------|
| App bootstrap + `RoleGate` | `lib/main.dart` |
| Firebase init (safe) | `lib/core/services/firebase_service.dart` |
| Auth + citizen-only register | `lib/core/services/auth_service.dart` |
| Theme / colors / typography | `lib/core/theme/`, `lib/core/constants/app_colors.dart` |
| Roles & fault enums | `lib/core/constants/app_roles.dart`, `fault_constants.dart` |
| Models | `UserModel`, `ReportModel`, `NotificationItem`, `ActivityTimelineEvent` |
| Shared widgets | `lib/core/widgets/` |
| Routing | `lib/core/navigation/app_router.dart` |
| In-memory data (until Firestore sync) | `lib/core/services/data_repository.dart` |
| Proposed security rules | `firestore.rules` (**not deployed until approved**) |

## Role shells (entry points)

- Citizen → `CitizenMainShell` (`/citizen`)
- Technician → `TechnicianMainShell` (`/technician`)
- Admin → `AdminMainShell` (`/admin`)

Shared tabs already host map / reports / notifications / profile stubs — extend **inside** `lib/features/<your-module>/`, reuse models and `DataRepository` APIs.

## Integration notes by member

| Member | Build on | Do not break |
|--------|----------|--------------|
| **2 Profile** | `SharedProfileView`, `PreferencesService`, `AuthProvider.updateProfile` | Auth/routing; do not write `role` from client |
| **3 Reporting** | `ReportModel`, `DataRepository.addReport`, `image_picker` / `geolocator` in pubspec | Keep `reporterUid == auth.uid`, status `pending` on create |
| **4 Map** | `SharedMapView`, `AppConfig` map defaults | Report status colors from `FaultStatus` |
| **5 Admin** | `AdminDashboardView`, `assignTechnician` | Privilege from Firestore `role == admin`, not UI alone |
| **6 Technician** | `TechnicianHomeView`, `getReportsForTechnician` | Only mutate assigned jobs |
| **7 Verify/Dispute** | Planned subcollections in `firestore.rules` | Counters via Cloud Functions, not client increments |
| **8 Notifications** | `NotificationItem`, path `/users/{uid}/notifications` | Prefer server-written creates; client marks `isRead` only |

## Security requirements (status)

1. Public sign-up → **citizen only** (implemented in client).
2. Staff seeded: `admin@aquatrace.lk` / `tech@aquatrace.lk` (passwords in local gitignored seed file — rotate on first use).
3. `firestore.rules` **deployed** to `aquatrace-92e2e`.
4. Firebase client API keys restricted (add release SHA-1 for Play builds).
5. Demo role buttons are **local mock auth**, not production identities.
6. GitHub “Google API key” alerts are expected client config — dismiss manually if the team agrees; do not delete `firebase_options.dart` / native config files.

## QA baseline Member 1 expects others to keep green

```bash
dart format lib test
flutter analyze
flutter test
```

## Known limitations at handoff

- Reports/notifications still primarily **in-memory** (`DataRepository`); Firestore sync stubs remain for feature owners.
- Google/Apple sign-in buttons are UI stubs until OAuth packages + Console providers are configured.
- Firestore rules emulator validation needs a local JRE; Console Rules Playground is an alternative.
- Admin “Activity” tab currently reuses notifications UI — Member 8 owns timeline UX.
