# AquaTrace — Community-Verified Water Pipe Repair Tracker

> **REPORT • REPAIR • VERIFY**  
> *A community-powered municipal water infrastructure monitoring platform for the National Water Board of Sri Lanka.*

---

## 1. Project Overview

Municipal water pipe failures often suffer from delayed reporting, vague fault details, and costly road excavations. Crucially, traditional management systems lack a mechanism to audit the quality of repairs post-completion, leading to recurrent leaks and water loss.

**AquaTrace** unites citizens, technicians, and water board administrators within a unified, map-based, role-aware framework:
- **Citizens** submit geo-tagged fault reports with photographic evidence and verify completed repairs in their neighborhood.
- **Water Board Dispatchers/Admins** authenticate reports, triage priorities, assign field technicians, and monitor resolution timelines.
- **Field Technicians** receive assigned jobs, navigate directly to pipe coordinates, and submit verifiable after-repair evidence.
- **Community Verification & Automatic Reopening**: Nearby residents audit the resolution; disputes automatically reopen the case for investigation.

---

## 2. Technology Stack

| Layer | Technology | Purpose |
|---|---|---|
| **Frontend Framework** | Flutter 3.47+ / Dart 3.13+ | Cross-platform client (iOS, Android, macOS, Web) |
| **State Management** | Provider | Reactive state & dependency injection |
| **Backend & Cloud** | Firebase Core & Cloud Firestore | Real-time database & document storage |
| **Authentication** | Firebase Authentication | Email/password & role-aware session management |
| **Media Storage** | Firebase Storage | Before-and-after photographic evidence |
| **Mapping Engine** | OpenStreetMap (`flutter_map` + `latlong2`) | Free, tile-based interactive map visualization |
| **Location Services** | `geolocator` | GPS coordinate retrieval & proximity verification |
| **Camera & Media** | `image_picker` | Photo capture for leaks and repair proof |
| **Persistence** | `shared_preferences` | Local preferences (theme, location, alerts) |

---

## 3. Architecture & Feature-First Folder Structure

AquaTrace follows a **feature-first, modular architecture** where shared core services, models, and design components are isolated from role-specific modules:

```text
AquaTrace/
├── android/                        # Android platform configuration & permissions
├── assets/
│   ├── icons/                      # App launcher and status icons
│   └── images/                     # Branded graphic assets (aquatrace_logo.png)
├── docs/                           # Project documentation & visual references
│   ├── 12_Proposal.pdf             # Approved academic proposal
│   ├── AquaTrace UI.pdf            # High-fidelity Figma design specification
│   └── AquaTrace_Team_Task_Distribution.pdf # Team member distribution
├── ios/                            # iOS platform configuration & Info.plist permissions
├── lib/
│   ├── core/                       # Shared foundation owned by Member 1
│   │   ├── config/                 # App configuration & safe Firebase options
│   │   │   ├── app_config.dart
│   │   │   └── firebase_options.dart
│   │   ├── constants/              # Central design tokens & enums
│   │   │   ├── app_assets.dart
│   │   │   ├── app_colors.dart     # Figma palette (Navy, Cyan, Statuses)
│   │   │   ├── app_roles.dart      # Citizen, Technician, Admin enums
│   │   │   └── fault_constants.dart # Status (5), Severity (4), FaultType (7)
│   │   ├── errors/                 # Exception handling & user-facing messages
│   │   │   ├── app_exception.dart
│   │   │   └── error_handler.dart
│   │   ├── models/                 # Agreed shared Firestore schemas
│   │   │   ├── activity_timeline_event.dart
│   │   │   ├── mock_data.dart      # Figma reference prototype dataset
│   │   │   ├── notification_item.dart
│   │   │   ├── report_model.dart
│   │   │   └── user_model.dart
│   │   ├── navigation/             # App routing & guards
│   │   │   ├── app_router.dart
│   │   │   └── navigation_service.dart
│   │   ├── services/               # Infrastructure services
│   │   │   ├── auth_service.dart
│   │   │   ├── data_repository.dart # Reactive state & Firestore sync
│   │   │   ├── firebase_service.dart # Safe initialization fallback
│   │   │   └── preferences_service.dart
│   │   ├── theme/                  # Typography & Light/Dark themes
│   │   │   ├── app_theme.dart
│   │   │   ├── app_typography.dart
│   │   │   └── theme_provider.dart
│   │   └── widgets/                # Reusable UI component library
│   │       ├── app_button.dart
│   │       ├── app_card.dart
│   │       ├── app_empty_state.dart
│   │       ├── app_error_widget.dart
│   │       ├── app_header_bar.dart
│   │       ├── app_loading_indicator.dart
│   │       ├── app_metric_card.dart
│   │       ├── app_priority_badge.dart
│   │       ├── app_report_card_tile.dart
│   │       ├── app_status_badge.dart
│   │       └── app_text_field.dart
│   ├── features/                   # Team Feature Modules (Members 1–8)
│   │   ├── admin/                  # Member 5: Admin Dashboard & Reports
│   │   ├── auth/                   # Member 1: Authentication & Role Gates
│   │   ├── citizen/                # Member 1 & 3: Citizen Dashboard & Shell
│   │   ├── map/                    # Member 4: Interactive Fault Map
│   │   ├── notifications/          # Member 8: Notifications & Activity Timeline
│   │   ├── profile/                # Member 2: User Profile & Preferences
│   │   ├── reports/                # Member 3 & 5: Report Details & Submission
│   │   └── technician/             # Member 6: Technician Job Queue
│   └── main.dart                   # Application bootstrap & MultiProvider
├── macos/                          # macOS desktop platform configuration
├── test/                           # Automated test suite
│   └── widget_test.dart
├── web/                            # Web platform support
└── pubspec.yaml                    # Project dependencies
```

---

## 4. Shared Data Contracts (Firestore)

All team members must conform to these shared document collections:

### 4.1 `/users/{uid}`
```json
{
  "uid": "demo-citizen-001",
  "email": "citizen@demo.com",
  "displayName": "Amal Perera",
  "phoneNumber": "+94 77 123 4567",
  "role": "citizen", // "citizen" | "technician" | "admin"
  "assignedArea": "Colombo 03",
  "employeeId": "WB-2024-087", // Technicians only
  "photoUrl": null,
  "createdAt": "2026-01-15T00:00:00.000Z",
  "updatedAt": null
}
```

### 4.2 `/reports/{reportId}`
```json
{
  "reportId": "AT-2026-00124",
  "reporterUid": "demo-citizen-001",
  "reporterName": "Amal Perera",
  "faultType": "pipeLeak", // pipeLeak | burstPipe | damagedPipe | roadWaterFlow | lowPressure | waterContamination | other
  "description": "Water leaking rapidly from municipal pipe joint along the pavement.",
  "severity": "high", // low | medium | high | critical
  "status": "ongoing", // pending | assigned | ongoing | completed | disputed
  "latitude": 6.8912,
  "longitude": 79.8554,
  "address": "Galle Road, Colombo 03",
  "beforeImageUrl": "https://storage.googleapis.com/...",
  "afterImageUrl": null,
  "assignedTechnicianUid": "demo-tech-002",
  "assignedTechnicianName": "Kasun Jayawardena",
  "assignedArea": "Colombo 03",
  "isEmergency": false,
  "verificationCount": 3,
  "disputeCount": 0,
  "repairNotes": "Excavation and pipe sealing underway.",
  "createdAt": "2026-09-24T10:32:00.000Z",
  "updatedAt": "2026-09-24T13:15:00.000Z"
}
```

### 4.3 `/reports/{reportId}/activity/{activityId}`
```json
{
  "id": "act-001",
  "reportId": "AT-2026-00124",
  "title": "Report Submitted",
  "description": "Citizen submitted report for pipe leak at Galle Road.",
  "actorName": "Amal Perera",
  "actorRole": "Citizen",
  "status": "pending",
  "timestamp": "2026-09-24T10:32:00.000Z"
}
```

### 4.4 `/users/{uid}/notifications/{notificationId}`
```json
{
  "id": "notif-001",
  "recipientUid": "demo-citizen-001",
  "title": "Technician Assigned",
  "body": "Your report AT-2026-00124 has been assigned to Kasun Jayawardena.",
  "reportId": "AT-2026-00124",
  "type": "assignment", // assignment | verification | approval | dispute | update
  "isRead": false,
  "createdAt": "2026-11-03T11:15:00.000Z"
}
```

---

## 5. Team Development Responsibilities

| Member | Module Scope | Suggested Branch |
|---|---|---|
| **Member 1** *(Lead)* | Project Foundation, Shared Theme, Routing, Reusable Widgets & Authentication | `main` / `feature/project-foundation` |
| **Member 2** | User Profile, Edit Profile, Preferences (Dark Mode, Text Size) & Settings | `feature/profile-settings` |
| **Member 3** | Citizen Fault Reporting, Camera/Gallery, Geolocation, Storage Upload | `feature/fault-reporting` |
| **Member 4** | Interactive Fault Map, OpenStreetMap integration, Markers, Filtering & Legend | `feature/fault-map` |
| **Member 5** | Admin Dashboard, Report Review/Verification, Technician Assignment & Analytics | `feature/admin-dashboard` |
| **Member 6** | Field Technician Dashboard, Assigned Job Queue, Repair Notes & Photos | `feature/technician` |
| **Member 7** | Community Repair Verification, Dispute Management & Auto-Reopening | `feature/community-verification` |
| **Member 8** | FCM Push Notifications, Notification Center & Report Activity Timeline | `feature/notifications-history` |

---

## 6. Environment-Safe Firebase Setup & Quick Run

AquaTrace includes an **environment-safe initialization architecture** via `FirebaseService`. With valid `DefaultFirebaseOptions`, the app initializes the configured project (`aquatrace-92e2e`). If options were missing, it would fall back to demo mode.

### 6.1 Running locally
```bash
flutter pub get
flutter analyze
flutter test
flutter run -d macos
# OR
flutter run -d chrome
```

On the Sign In screen, **"demo role access"** loads in-memory mock users (development only — not Firebase Auth accounts):
- **Demo Citizen** (`citizen@demo.com`)
- **Demo Technician** (`tech@demo.com`)
- **Demo Admin** (`admin@demo.com`)

Public **Create Account** always registers a **citizen**. Technician/Admin identities must be provisioned with the Admin SDK (or an approved Cloud Function), never via the client role picker.

### 6.2 Firebase project (current)
| Item | Value |
|---|---|
| Project | `aquatrace-92e2e` (display name AquaTrace) |
| Dart options | `lib/core/config/firebase_options.dart` |
| Proposed rules | `firestore.rules` (see §8 — **not deployed until approved**) |

Console / cloud hardening status (Member 1):
- **Authentication → Email/Password**: enabled for `aquatrace-92e2e`.
- **Cloud Firestore**: `(default)` database exists; `firestore.rules` **deployed**.
- **API keys**: Android / iOS / Browser auto-keys restricted (package/bundle/referrers). Android restriction currently includes the **debug** keystore SHA-1 — add your release SHA-1 before Play builds.
- **Bootstrap staff**: `admin@aquatrace.lk` (admin) and `tech@aquatrace.lk` (technician) seeded; passwords live only in gitignored `scripts/.seed_credentials.local.json` (change on first login).
- Enable **Storage** / **FCM** when Members 3/8 need them.
- Re-run hardening after SHA changes: `python3 scripts/member1_cloud_hardening.py <ANDROID_SHA1>`.

### 6.3 Google / Apple sign-in (not wired)
UI buttons remain visible per the design PDF but are **gracefully disabled** until:
1. **Google:** Firebase Auth Google provider + OAuth client IDs + `google_sign_in` package.
2. **Apple:** Apple Developer “Sign in with Apple”, Firebase Apple provider + `sign_in_with_apple`.

> **Security Reminder**: Never commit service-account JSON keys, `.p8` certificates, or `.env` secrets.

### 6.4 Maps, tile sources, and location
- The shared map observes the repository's `/reports` snapshots, capped at the **500 most recently created reports** per signed-in session. Reports without valid numeric latitude/longitude are not plotted.
- Demo report fixtures are used only when Firebase is not configured. A configured Firebase session never falls back to sample reports.
- Search matches report IDs, addresses, fault descriptions, reporter names, and assigned technician names already loaded by the app. No geocoding service is configured, so arbitrary place-name search is not sent to a third party.
- The default tile URL is OpenStreetMap's standard tile endpoint. The app displays map attribution and identifies its Android/iOS tile client. Do not bulk-download, prefetch, or persistently cache public OSM tiles. For production traffic, configure a tile provider whose usage policy matches the deployment and supply its required attribution:

  ```bash
  flutter run -d chrome \
    --dart-define=AQUATRACE_MAP_TILE_URL=https://tiles.example.org/{z}/{x}/{y}.png \
  --dart-define=AQUATRACE_MAP_TILE_ATTRIBUTION="Example Maps" \
  --dart-define=AQUATRACE_MAP_ATTRIBUTION_URL=https://tiles.example.org/attribution
  ```

  The URL and attribution are configuration, not credentials. Keep provider API keys out of source control; use an approved runtime configuration mechanism if a provider requires a key.
- Current-location access is requested only after the user taps the location control. Directions open an external maps app using the report coordinates; AquaTrace does not provide in-app turn-by-turn routing.

---

## 7. Role security model (Member 1)

Hiding a nav item is **not** security. Authorization is:

1. **Firebase Auth** proves identity (`request.auth.uid`).
2. **`/users/{uid}.role`** stores `citizen` \| `technician` \| `admin`.
3. **Client registration** hard-codes `role: citizen` (`AuthService.registerWithEmailAndPassword`).
4. **Profile updates** patch only safe fields (`displayName`, `phoneNumber`, `assignedArea`, `photoUrl`) — never `role` / `email` / `uid` / `employeeId`.
5. **`firestore.rules`** rejects self-elevation and unauthorized report mutations (proposed file in repo).
6. **UI `RoleGate`** only routes shells; privileged role assignment is an Admin SDK / Cloud Functions operation.

Deploy rules later (do not run until authorized):
```bash
firebase deploy --only firestore:rules --project aquatrace-92e2e
```

Integration notes for Members 2–8: see [`docs/MEMBER1_HANDOFF.md`](docs/MEMBER1_HANDOFF.md).

---

## 8. Team Branch & Pull Request Workflow

1. **Pull the latest `main` branch before starting**:
   ```bash
   git checkout main
   git pull origin main
   ```
2. **Create your feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Develop within your module**: Do not overwrite another member's feature directory or core foundation without team consensus.
4. **Mandatory QA before committing**:
   ```bash
   dart format lib test
   flutter analyze
   flutter test
   ```
5. **Commit with descriptive messages**:
   ```bash
   git commit -m "feat(module): add detailed description of changes"
   ```
6. **Push and create a Pull Request** against `main`. Ensure all CI checks and reviews pass before merging.
