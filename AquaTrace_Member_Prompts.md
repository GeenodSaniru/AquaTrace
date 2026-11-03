# AquaTrace — AI Coding Prompt Pack

**Purpose:** Copy the prompts for the assigned team member into the coding agent working inside the AquaTrace repository.

**Important execution order:** Member 1 must create and push the foundation first. Members 2–8 should begin their implementation prompts only after Member 1's foundation branch/PR is available and the team has agreed on shared Firestore models and interfaces. Each prompt is a separate run and is designed to inspect the current repository state before acting.

**Source UI:** The AquaTrace proposal and UI reference PDF supplied with the project. The prompts require the coding agent to locate and inspect the actual PDF in the repository/project files before implementation.

## Mandatory rules included in every prompt

MANDATORY EXECUTION RULES — apply these in every prompt:
• Work in the existing AquaTrace repository; do not create a parallel app or replace the project wholesale.
• Preflight is mandatory: inspect the repository tree; read all relevant `*.md` files (including README, architecture/specification/data-contract docs and the latest `update.md`); inspect `pubspec.yaml`, current implementation, Git status and recent history; locate and inspect the UI PDF stored in the project files/repository. Render/inspect every PDF page and its embedded screens, not just extracted text. Use the proposal and UI PDF as the source of truth for scope and visual design. If the PDF or required docs cannot be found/read, state that clearly and pause any UI-dependent assumptions.
• Reuse established architecture, dependencies, naming, theme, data models and interfaces. Do not overwrite another member's work or shared files without coordination. Do not add credentials/secrets to Git.
• Implement the assigned scope end-to-end, including UI, state, backend integration, validation, loading/empty/error states and accessibility. Avoid placeholder/mock behavior in real workflows unless explicitly labelled as demo data.
• QA is mandatory on every run: format code; run static analysis; run relevant automated tests; build/launch the app on an available target; exercise the assigned feature and key failure paths; fix every reproducible bug in scope and rerun checks. If a device, Firebase project, emulator, credentials or external service is unavailable, run all remaining checks and record the exact environmental blocker—never claim success falsely.
• At the end of every run, create/update repository-root `update.md`. Append a dated entry with actual completed tasks, files/modules changed, remaining tasks/blockers, exact commands and outcomes, and current date/time in `Asia/Colombo` with UTC offset. Obtain the timestamp from the system clock at execution time; do not invent or reuse an old timestamp.
• Before committing, inspect `git diff` and `git status`; stage only the changes belonging to this task. Make a descriptive Git commit. Push the current working branch if a remote and valid authentication are configured. Never force-push, rewrite shared history, commit unrelated files, or claim a push/commit/test succeeded unless verified. If GitHub access is unavailable, leave a clean local commit if possible and report the exact blocker.
• Final response must summarize implementation, tests actually run and results, update.md entry, commit hash/branch, push status and remaining blockers. Do not say “all bugs fixed” unless checks support that claim.


# Member 1 — Project Foundation & Authentication

## Prompt 1A — Repository, Flutter foundation and project structure

```text
MANDATORY EXECUTION RULES — apply these in every prompt:
• Work in the existing AquaTrace repository; do not create a parallel app or replace the project wholesale.
• Preflight is mandatory: inspect the repository tree; read all relevant `*.md` files (including README, architecture/specification/data-contract docs and the latest `update.md`); inspect `pubspec.yaml`, current implementation, Git status and recent history; locate and inspect the UI PDF stored in the project files/repository. Render/inspect every PDF page and its embedded screens, not just extracted text. Use the proposal and UI PDF as the source of truth for scope and visual design. If the PDF or required docs cannot be found/read, state that clearly and pause any UI-dependent assumptions.
• Reuse established architecture, dependencies, naming, theme, data models and interfaces. Do not overwrite another member's work or shared files without coordination. Do not add credentials/secrets to Git.
• Implement the assigned scope end-to-end, including UI, state, backend integration, validation, loading/empty/error states and accessibility. Avoid placeholder/mock behavior in real workflows unless explicitly labelled as demo data.
• QA is mandatory on every run: format code; run static analysis; run relevant automated tests; build/launch the app on an available target; exercise the assigned feature and key failure paths; fix every reproducible bug in scope and rerun checks. If a device, Firebase project, emulator, credentials or external service is unavailable, run all remaining checks and record the exact environmental blocker—never claim success falsely.
• At the end of every run, create/update repository-root `update.md`. Append a dated entry with actual completed tasks, files/modules changed, remaining tasks/blockers, exact commands and outcomes, and current date/time in `Asia/Colombo` with UTC offset. Obtain the timestamp from the system clock at execution time; do not invent or reuse an old timestamp.
• Before committing, inspect `git diff` and `git status`; stage only the changes belonging to this task. Make a descriptive Git commit. Push the current working branch if a remote and valid authentication are configured. Never force-push, rewrite shared history, commit unrelated files, or claim a push/commit/test succeeded unless verified. If GitHub access is unavailable, leave a clean local commit if possible and report the exact blocker.
• Final response must summarize implementation, tests actually run and results, update.md entry, commit hash/branch, push status and remaining blockers. Do not say “all bugs fixed” unless checks support that claim.

You are Member 1 of the AquaTrace team. Own the initial repository and technical foundation. Before changing anything, inspect the entire existing repository: read every relevant README, architecture note, setup guide, specification and other *.md file; inspect the project tree, pubspec.yaml, existing source code, configuration and Git history. Locate and inspect the AquaTrace UI PDF in the project files/repository. Render and inspect every page, including embedded screen designs; compare the screens with the proposal/specification. Do not assume a file path: search for the PDF. If the UI PDF or required project documentation is missing or inaccessible, report that clearly and do not invent its contents.

Implement the foundation: create/initialize the Flutter app if needed; establish a clean, scalable feature-first folder structure; configure environment-safe Firebase initialization; add shared theme, colours, typography, reusable widgets, route/navigation conventions, error handling and app-level configuration. Keep platform setup consistent with the repository. Create a clear README with setup/run instructions, architecture, Firebase setup requirements and team branch/PR workflow. Do not commit secrets, private keys, service-account files or real credentials. Do not overwrite existing working code without understanding it.

Before finishing, run formatter, static analysis and available tests; run the app on an available target and verify startup/navigation. Fix every issue you can reproduce. If Firebase credentials or a device/emulator are unavailable, distinguish environmental blockers from code defects and still run all available checks. Create/update `update.md` at the repository root with the actual completed tasks, remaining tasks/blockers, test commands/results, and the current date and time in `Asia/Colombo` (include UTC offset). Stage only your own intended changes, inspect `git diff` and `git status`, commit with a clear message, and push the branch if the remote and authentication are configured. Never claim a push or test succeeded unless it actually did. Report commit hash, push status, run/test results and blockers.
```

## Prompt 1B — Firebase Authentication and role-based access

```text
MANDATORY EXECUTION RULES — apply these in every prompt:
• Work in the existing AquaTrace repository; do not create a parallel app or replace the project wholesale.
• Preflight is mandatory: inspect the repository tree; read all relevant `*.md` files (including README, architecture/specification/data-contract docs and the latest `update.md`); inspect `pubspec.yaml`, current implementation, Git status and recent history; locate and inspect the UI PDF stored in the project files/repository. Render/inspect every PDF page and its embedded screens, not just extracted text. Use the proposal and UI PDF as the source of truth for scope and visual design. If the PDF or required docs cannot be found/read, state that clearly and pause any UI-dependent assumptions.
• Reuse established architecture, dependencies, naming, theme, data models and interfaces. Do not overwrite another member's work or shared files without coordination. Do not add credentials/secrets to Git.
• Implement the assigned scope end-to-end, including UI, state, backend integration, validation, loading/empty/error states and accessibility. Avoid placeholder/mock behavior in real workflows unless explicitly labelled as demo data.
• QA is mandatory on every run: format code; run static analysis; run relevant automated tests; build/launch the app on an available target; exercise the assigned feature and key failure paths; fix every reproducible bug in scope and rerun checks. If a device, Firebase project, emulator, credentials or external service is unavailable, run all remaining checks and record the exact environmental blocker—never claim success falsely.
• At the end of every run, create/update repository-root `update.md`. Append a dated entry with actual completed tasks, files/modules changed, remaining tasks/blockers, exact commands and outcomes, and current date/time in `Asia/Colombo` with UTC offset. Obtain the timestamp from the system clock at execution time; do not invent or reuse an old timestamp.
• Before committing, inspect `git diff` and `git status`; stage only the changes belonging to this task. Make a descriptive Git commit. Push the current working branch if a remote and valid authentication are configured. Never force-push, rewrite shared history, commit unrelated files, or claim a push/commit/test succeeded unless verified. If GitHub access is unavailable, leave a clean local commit if possible and report the exact blocker.
• Final response must summarize implementation, tests actually run and results, update.md entry, commit hash/branch, push status and remaining blockers. Do not say “all bugs fixed” unless checks support that claim.

You are Member 1 continuing AquaTrace foundation/authentication. First re-read all repository *.md files and the current `update.md`; inspect the current code, architecture, dependency versions and Git status. Locate and inspect the UI PDF in the project files again before implementation: inspect the login, registration, forgot-password and demo-role-access screens and follow their layout and visual language. Do not assume a PDF path. If missing, state the blocker rather than guessing.

Implement Firebase Authentication using the project's existing conventions: email/password registration and sign-in, sign-out, password reset, auth-state persistence, validation, loading/error states and safe session handling. Implement role-aware routing for Citizen, Technician and Admin. Define a clear user profile/role data contract in Firestore, document it, and enforce role checks in the app's navigation/UI. Do not treat hiding a button as security; explain the required Firestore security rules and ensure client code does not grant users their own privileged role. Add Google/Apple sign-in only if the project configuration and dependencies support it; otherwise document exact setup requirements and keep unavailable providers disabled gracefully. Preserve Member 1's ownership of shared auth/routing files and coordinate interfaces with other modules.

Run formatting, static analysis, relevant tests and an app launch. Test invalid credentials, loading/error states, signed-out navigation, each role route and sign-out where test configuration permits. Fix reproducible bugs. Update root `update.md` with completed tasks, outstanding items, exact test outcomes and current `Asia/Colombo` date/time with UTC offset. Review `git diff`/status, commit only intended changes with a descriptive message and push if configured. Report commit hash, push result and any environment-only blockers.
```

## Prompt 1C — Foundation integration, hardening and handoff

```text
MANDATORY EXECUTION RULES — apply these in every prompt:
• Work in the existing AquaTrace repository; do not create a parallel app or replace the project wholesale.
• Preflight is mandatory: inspect the repository tree; read all relevant `*.md` files (including README, architecture/specification/data-contract docs and the latest `update.md`); inspect `pubspec.yaml`, current implementation, Git status and recent history; locate and inspect the UI PDF stored in the project files/repository. Render/inspect every PDF page and its embedded screens, not just extracted text. Use the proposal and UI PDF as the source of truth for scope and visual design. If the PDF or required docs cannot be found/read, state that clearly and pause any UI-dependent assumptions.
• Reuse established architecture, dependencies, naming, theme, data models and interfaces. Do not overwrite another member's work or shared files without coordination. Do not add credentials/secrets to Git.
• Implement the assigned scope end-to-end, including UI, state, backend integration, validation, loading/empty/error states and accessibility. Avoid placeholder/mock behavior in real workflows unless explicitly labelled as demo data.
• QA is mandatory on every run: format code; run static analysis; run relevant automated tests; build/launch the app on an available target; exercise the assigned feature and key failure paths; fix every reproducible bug in scope and rerun checks. If a device, Firebase project, emulator, credentials or external service is unavailable, run all remaining checks and record the exact environmental blocker—never claim success falsely.
• At the end of every run, create/update repository-root `update.md`. Append a dated entry with actual completed tasks, files/modules changed, remaining tasks/blockers, exact commands and outcomes, and current date/time in `Asia/Colombo` with UTC offset. Obtain the timestamp from the system clock at execution time; do not invent or reuse an old timestamp.
• Before committing, inspect `git diff` and `git status`; stage only the changes belonging to this task. Make a descriptive Git commit. Push the current working branch if a remote and valid authentication are configured. Never force-push, rewrite shared history, commit unrelated files, or claim a push/commit/test succeeded unless verified. If GitHub access is unavailable, leave a clean local commit if possible and report the exact blocker.
• Final response must summarize implementation, tests actually run and results, update.md entry, commit hash/branch, push status and remaining blockers. Do not say “all bugs fixed” unless checks support that claim.

Act as Member 1 and perform a foundation handoff review for AquaTrace. Before edits, read all relevant repository *.md files, the latest `update.md`, Git history and current source structure. Locate and inspect the UI PDF again, especially the login/registration and navigation patterns, and compare the running app against it. Do not assume paths or fabricate missing requirements.

Review the foundation and authentication implementation for maintainability, route correctness, role separation, Firebase initialization order, error handling, null safety, dependency compatibility, secret leakage and clean startup. Verify that feature modules can integrate without duplicating app initialization, themes, routing or data contracts. Add or refine shared interfaces/documentation only where necessary; do not absorb another member's feature work. Verify README setup steps from a clean checkout as far as the environment allows. Run formatter, analyzer, tests and launch/build checks; fix all reproducible defects and report external blockers separately.

Update `update.md` with completed handoff items, known limitations, exact checks/results and the actual current `Asia/Colombo` timestamp including offset. Inspect staged diff and status, commit the intended changes and push if configured. Report the commit hash, branch, push status, test results and concise integration notes for Members 2–8.
```


# Member 2 — User Profile & Settings

## Prompt 2A — Build profile and settings module

```text
MANDATORY EXECUTION RULES — apply these in every prompt:
• Work in the existing AquaTrace repository; do not create a parallel app or replace the project wholesale.
• Preflight is mandatory: inspect the repository tree; read all relevant `*.md` files (including README, architecture/specification/data-contract docs and the latest `update.md`); inspect `pubspec.yaml`, current implementation, Git status and recent history; locate and inspect the UI PDF stored in the project files/repository. Render/inspect every PDF page and its embedded screens, not just extracted text. Use the proposal and UI PDF as the source of truth for scope and visual design. If the PDF or required docs cannot be found/read, state that clearly and pause any UI-dependent assumptions.
• Reuse established architecture, dependencies, naming, theme, data models and interfaces. Do not overwrite another member's work or shared files without coordination. Do not add credentials/secrets to Git.
• Implement the assigned scope end-to-end, including UI, state, backend integration, validation, loading/empty/error states and accessibility. Avoid placeholder/mock behavior in real workflows unless explicitly labelled as demo data.
• QA is mandatory on every run: format code; run static analysis; run relevant automated tests; build/launch the app on an available target; exercise the assigned feature and key failure paths; fix every reproducible bug in scope and rerun checks. If a device, Firebase project, emulator, credentials or external service is unavailable, run all remaining checks and record the exact environmental blocker—never claim success falsely.
• At the end of every run, create/update repository-root `update.md`. Append a dated entry with actual completed tasks, files/modules changed, remaining tasks/blockers, exact commands and outcomes, and current date/time in `Asia/Colombo` with UTC offset. Obtain the timestamp from the system clock at execution time; do not invent or reuse an old timestamp.
• Before committing, inspect `git diff` and `git status`; stage only the changes belonging to this task. Make a descriptive Git commit. Push the current working branch if a remote and valid authentication are configured. Never force-push, rewrite shared history, commit unrelated files, or claim a push/commit/test succeeded unless verified. If GitHub access is unavailable, leave a clean local commit if possible and report the exact blocker.
• Final response must summarize implementation, tests actually run and results, update.md entry, commit hash/branch, push status and remaining blockers. Do not say “all bugs fixed” unless checks support that claim.

You are Member 2. Own only AquaTrace's user profile and settings module. Before coding, inspect the repository completely enough to understand its conventions: read all relevant *.md files (README, architecture, setup, API/data contracts and `update.md`), inspect folder structure, routes, theme, shared widgets, Firebase setup, user model and Git status. Locate and inspect the AquaTrace UI PDF in the project files; inspect all profile, edit-profile, preferences, notification settings, location settings, privacy, accessibility, help/support and about screens. Follow the actual visual design, labels, navigation and states shown; do not invent a different UI. If the PDF is unavailable, state that blocker.

Implement profile viewing/editing, profile photo selection/upload using the established storage conventions, account details display, dark/light appearance preference, notification preferences UI, location preference UI, privacy controls UI, accessibility/text-size/high-contrast options if represented, Help & Support and About AquaTrace. Persist supported preferences safely (use the project's agreed storage/data model); do not claim a preference works if it is only a visual toggle. Do not change authentication or shared routing architecture without coordinating with Member 1. Respect role-specific profile information and avoid exposing other users' private details.

Run formatter, analyzer, module tests and app launch/build checks. Exercise every screen, navigation, save/cancel flows, image upload/error states and persisted preferences. Fix all reproducible bugs. Update root `update.md` with completed tasks, outstanding work, test commands/results and current `Asia/Colombo` date/time including UTC offset. Inspect `git diff` and status, commit only your module changes with a descriptive message and push if configured. Report commit hash, push status and blockers.
```

## Prompt 2B — Profile integration and data persistence

```text
MANDATORY EXECUTION RULES — apply these in every prompt:
• Work in the existing AquaTrace repository; do not create a parallel app or replace the project wholesale.
• Preflight is mandatory: inspect the repository tree; read all relevant `*.md` files (including README, architecture/specification/data-contract docs and the latest `update.md`); inspect `pubspec.yaml`, current implementation, Git status and recent history; locate and inspect the UI PDF stored in the project files/repository. Render/inspect every PDF page and its embedded screens, not just extracted text. Use the proposal and UI PDF as the source of truth for scope and visual design. If the PDF or required docs cannot be found/read, state that clearly and pause any UI-dependent assumptions.
• Reuse established architecture, dependencies, naming, theme, data models and interfaces. Do not overwrite another member's work or shared files without coordination. Do not add credentials/secrets to Git.
• Implement the assigned scope end-to-end, including UI, state, backend integration, validation, loading/empty/error states and accessibility. Avoid placeholder/mock behavior in real workflows unless explicitly labelled as demo data.
• QA is mandatory on every run: format code; run static analysis; run relevant automated tests; build/launch the app on an available target; exercise the assigned feature and key failure paths; fix every reproducible bug in scope and rerun checks. If a device, Firebase project, emulator, credentials or external service is unavailable, run all remaining checks and record the exact environmental blocker—never claim success falsely.
• At the end of every run, create/update repository-root `update.md`. Append a dated entry with actual completed tasks, files/modules changed, remaining tasks/blockers, exact commands and outcomes, and current date/time in `Asia/Colombo` with UTC offset. Obtain the timestamp from the system clock at execution time; do not invent or reuse an old timestamp.
• Before committing, inspect `git diff` and `git status`; stage only the changes belonging to this task. Make a descriptive Git commit. Push the current working branch if a remote and valid authentication are configured. Never force-push, rewrite shared history, commit unrelated files, or claim a push/commit/test succeeded unless verified. If GitHub access is unavailable, leave a clean local commit if possible and report the exact blocker.
• Final response must summarize implementation, tests actually run and results, update.md entry, commit hash/branch, push status and remaining blockers. Do not say “all bugs fixed” unless checks support that claim.

Continue as Member 2. Before changing code, read all relevant repository *.md files and `update.md`, inspect current profile implementation, user data contract, authentication state, shared theme/routes and Git status. Re-open and inspect the AquaTrace UI PDF's profile/settings screens; verify the implemented screens against the visual reference.

Integrate the module with the current authenticated user and the established Firebase/Firestore/Storage contracts. Verify that profile edits update the correct user's record, profile image uploads use safe paths and loading/error states, settings persist after app restart, and role-specific fields are displayed correctly. Ensure sign-out is delegated to the existing authentication flow. Check that toggles and controls have real behavior or are clearly marked as not yet supported. Add tests for validation, persistence and error cases where practical. Do not modify other members' modules except through agreed interfaces.

Run formatter, analyzer, tests and app launch/build. Navigate through all profile/settings screens and fix every reproducible bug. Update `update.md` with completed integration tasks, remaining blockers, test results and current `Asia/Colombo` timestamp with offset. Review diff/status, commit intended changes and push if configured. Report commit hash and test/push status.
```

## Prompt 2C — Profile regression and handoff

```text
MANDATORY EXECUTION RULES — apply these in every prompt:
• Work in the existing AquaTrace repository; do not create a parallel app or replace the project wholesale.
• Preflight is mandatory: inspect the repository tree; read all relevant `*.md` files (including README, architecture/specification/data-contract docs and the latest `update.md`); inspect `pubspec.yaml`, current implementation, Git status and recent history; locate and inspect the UI PDF stored in the project files/repository. Render/inspect every PDF page and its embedded screens, not just extracted text. Use the proposal and UI PDF as the source of truth for scope and visual design. If the PDF or required docs cannot be found/read, state that clearly and pause any UI-dependent assumptions.
• Reuse established architecture, dependencies, naming, theme, data models and interfaces. Do not overwrite another member's work or shared files without coordination. Do not add credentials/secrets to Git.
• Implement the assigned scope end-to-end, including UI, state, backend integration, validation, loading/empty/error states and accessibility. Avoid placeholder/mock behavior in real workflows unless explicitly labelled as demo data.
• QA is mandatory on every run: format code; run static analysis; run relevant automated tests; build/launch the app on an available target; exercise the assigned feature and key failure paths; fix every reproducible bug in scope and rerun checks. If a device, Firebase project, emulator, credentials or external service is unavailable, run all remaining checks and record the exact environmental blocker—never claim success falsely.
• At the end of every run, create/update repository-root `update.md`. Append a dated entry with actual completed tasks, files/modules changed, remaining tasks/blockers, exact commands and outcomes, and current date/time in `Asia/Colombo` with UTC offset. Obtain the timestamp from the system clock at execution time; do not invent or reuse an old timestamp.
• Before committing, inspect `git diff` and `git status`; stage only the changes belonging to this task. Make a descriptive Git commit. Push the current working branch if a remote and valid authentication are configured. Never force-push, rewrite shared history, commit unrelated files, or claim a push/commit/test succeeded unless verified. If GitHub access is unavailable, leave a clean local commit if possible and report the exact blocker.
• Final response must summarize implementation, tests actually run and results, update.md entry, commit hash/branch, push status and remaining blockers. Do not say “all bugs fixed” unless checks support that claim.

Act as Member 2 performing final QA and handoff. First inspect all repository *.md files, latest `update.md`, current implementation, project structure and Git status. Inspect the AquaTrace UI PDF again and compare all profile/settings screens and states against it.

Perform a regression pass on profile display/edit, profile picture, preferences, theme, privacy/accessibility controls, help/support and about screens. Check small/large text, dark/light theme, empty or malformed profile fields, network failures, permission denial, upload failures and app restart persistence. Check that no private data or credentials are exposed and that profile functionality does not break other roles. Fix all reproducible issues within your module; document issues that require another owner's change rather than silently editing their module.

Run formatter, analyzer, tests and app launch/build checks. Update root `update.md` with final module status, test commands/results, known limitations and actual `Asia/Colombo` date/time including offset. Review diff/status, commit and push if configured. Report commit hash, final status and any cross-module dependencies.
```


# Member 3 — Fault Reporting System

## Prompt 3A — Build fault reporting

```text
MANDATORY EXECUTION RULES — apply these in every prompt:
• Work in the existing AquaTrace repository; do not create a parallel app or replace the project wholesale.
• Preflight is mandatory: inspect the repository tree; read all relevant `*.md` files (including README, architecture/specification/data-contract docs and the latest `update.md`); inspect `pubspec.yaml`, current implementation, Git status and recent history; locate and inspect the UI PDF stored in the project files/repository. Render/inspect every PDF page and its embedded screens, not just extracted text. Use the proposal and UI PDF as the source of truth for scope and visual design. If the PDF or required docs cannot be found/read, state that clearly and pause any UI-dependent assumptions.
• Reuse established architecture, dependencies, naming, theme, data models and interfaces. Do not overwrite another member's work or shared files without coordination. Do not add credentials/secrets to Git.
• Implement the assigned scope end-to-end, including UI, state, backend integration, validation, loading/empty/error states and accessibility. Avoid placeholder/mock behavior in real workflows unless explicitly labelled as demo data.
• QA is mandatory on every run: format code; run static analysis; run relevant automated tests; build/launch the app on an available target; exercise the assigned feature and key failure paths; fix every reproducible bug in scope and rerun checks. If a device, Firebase project, emulator, credentials or external service is unavailable, run all remaining checks and record the exact environmental blocker—never claim success falsely.
• At the end of every run, create/update repository-root `update.md`. Append a dated entry with actual completed tasks, files/modules changed, remaining tasks/blockers, exact commands and outcomes, and current date/time in `Asia/Colombo` with UTC offset. Obtain the timestamp from the system clock at execution time; do not invent or reuse an old timestamp.
• Before committing, inspect `git diff` and `git status`; stage only the changes belonging to this task. Make a descriptive Git commit. Push the current working branch if a remote and valid authentication are configured. Never force-push, rewrite shared history, commit unrelated files, or claim a push/commit/test succeeded unless verified. If GitHub access is unavailable, leave a clean local commit if possible and report the exact blocker.
• Final response must summarize implementation, tests actually run and results, update.md entry, commit hash/branch, push status and remaining blockers. Do not say “all bugs fixed” unless checks support that claim.

You are Member 3 and own AquaTrace's citizen fault-reporting module. Before coding, read all relevant repository *.md files including README, architecture, Firestore/data contracts and `update.md`; inspect the current app structure, routing, shared widgets, Firebase setup, authentication/user model and Git status. Locate and inspect the AquaTrace UI PDF in the project files. Study the citizen home and report-water-fault/report form screens, including fields, buttons, layout, statuses and visual style. Do not assume the PDF path. If unavailable, state that blocker.

Implement the reporting flow: select fault type, enter description, choose severity, capture/select evidence photo, request location permission and obtain GPS coordinates, allow the user to review/confirm location, upload evidence to Firebase Storage, and create a Firestore report with a unique ID, reporter UID, coordinates, description, type, severity, timestamps and initial status. Use the agreed data model and status values. Validate required fields, handle denied permissions, unavailable GPS, camera/gallery cancellation, upload failures and duplicate submissions. Do not fake coordinates or silently submit incomplete evidence. Keep the UI faithful to the PDF and make the flow accessible.

Run formatter, analyzer, tests and app launch/build. Test success and failure paths and verify saved Firestore/storage data when credentials are available. Fix every reproducible bug. Update root `update.md` with completed tasks, outstanding items, test commands/results and actual current `Asia/Colombo` date/time with UTC offset. Inspect diff/status, commit only your module changes and push if configured. Report commit hash, push status and blockers.
```

## Prompt 3B — Reporting integration and validation

```text
MANDATORY EXECUTION RULES — apply these in every prompt:
• Work in the existing AquaTrace repository; do not create a parallel app or replace the project wholesale.
• Preflight is mandatory: inspect the repository tree; read all relevant `*.md` files (including README, architecture/specification/data-contract docs and the latest `update.md`); inspect `pubspec.yaml`, current implementation, Git status and recent history; locate and inspect the UI PDF stored in the project files/repository. Render/inspect every PDF page and its embedded screens, not just extracted text. Use the proposal and UI PDF as the source of truth for scope and visual design. If the PDF or required docs cannot be found/read, state that clearly and pause any UI-dependent assumptions.
• Reuse established architecture, dependencies, naming, theme, data models and interfaces. Do not overwrite another member's work or shared files without coordination. Do not add credentials/secrets to Git.
• Implement the assigned scope end-to-end, including UI, state, backend integration, validation, loading/empty/error states and accessibility. Avoid placeholder/mock behavior in real workflows unless explicitly labelled as demo data.
• QA is mandatory on every run: format code; run static analysis; run relevant automated tests; build/launch the app on an available target; exercise the assigned feature and key failure paths; fix every reproducible bug in scope and rerun checks. If a device, Firebase project, emulator, credentials or external service is unavailable, run all remaining checks and record the exact environmental blocker—never claim success falsely.
• At the end of every run, create/update repository-root `update.md`. Append a dated entry with actual completed tasks, files/modules changed, remaining tasks/blockers, exact commands and outcomes, and current date/time in `Asia/Colombo` with UTC offset. Obtain the timestamp from the system clock at execution time; do not invent or reuse an old timestamp.
• Before committing, inspect `git diff` and `git status`; stage only the changes belonging to this task. Make a descriptive Git commit. Push the current working branch if a remote and valid authentication are configured. Never force-push, rewrite shared history, commit unrelated files, or claim a push/commit/test succeeded unless verified. If GitHub access is unavailable, leave a clean local commit if possible and report the exact blocker.
• Final response must summarize implementation, tests actually run and results, update.md entry, commit hash/branch, push status and remaining blockers. Do not say “all bugs fixed” unless checks support that claim.

Continue as Member 3. First read all relevant repository *.md files and `update.md`; inspect current reporting code, Firestore schema, storage path conventions, auth identity, map/location interfaces and Git status. Inspect the AquaTrace UI PDF's report form again and compare every field and interaction.

Integrate report creation with the shared app and agreed Firestore model. Ensure each report is associated with the authenticated reporter; generate stable unique report IDs; store coordinates in a consistent numeric representation; save image download/storage references rather than embedding image bytes in Firestore; include created/updated timestamps and initial status. Ensure the report appears in the user's report list/map using the shared contract. Validate size/type limits for images and all form inputs. Prevent repeated taps from creating duplicate reports. Do not alter map/admin modules; communicate required contract changes.

Run formatter, analyzer, tests and app launch/build. Verify report creation, data retrieval and failure recovery. Fix all reproducible bugs. Update `update.md` with integration completion, remaining tasks, exact test results and current `Asia/Colombo` timestamp with offset. Inspect diff/status, commit and push if configured. Report commit hash and blockers.
```

## Prompt 3C — Reporting regression and handoff

```text
MANDATORY EXECUTION RULES — apply these in every prompt:
• Work in the existing AquaTrace repository; do not create a parallel app or replace the project wholesale.
• Preflight is mandatory: inspect the repository tree; read all relevant `*.md` files (including README, architecture/specification/data-contract docs and the latest `update.md`); inspect `pubspec.yaml`, current implementation, Git status and recent history; locate and inspect the UI PDF stored in the project files/repository. Render/inspect every PDF page and its embedded screens, not just extracted text. Use the proposal and UI PDF as the source of truth for scope and visual design. If the PDF or required docs cannot be found/read, state that clearly and pause any UI-dependent assumptions.
• Reuse established architecture, dependencies, naming, theme, data models and interfaces. Do not overwrite another member's work or shared files without coordination. Do not add credentials/secrets to Git.
• Implement the assigned scope end-to-end, including UI, state, backend integration, validation, loading/empty/error states and accessibility. Avoid placeholder/mock behavior in real workflows unless explicitly labelled as demo data.
• QA is mandatory on every run: format code; run static analysis; run relevant automated tests; build/launch the app on an available target; exercise the assigned feature and key failure paths; fix every reproducible bug in scope and rerun checks. If a device, Firebase project, emulator, credentials or external service is unavailable, run all remaining checks and record the exact environmental blocker—never claim success falsely.
• At the end of every run, create/update repository-root `update.md`. Append a dated entry with actual completed tasks, files/modules changed, remaining tasks/blockers, exact commands and outcomes, and current date/time in `Asia/Colombo` with UTC offset. Obtain the timestamp from the system clock at execution time; do not invent or reuse an old timestamp.
• Before committing, inspect `git diff` and `git status`; stage only the changes belonging to this task. Make a descriptive Git commit. Push the current working branch if a remote and valid authentication are configured. Never force-push, rewrite shared history, commit unrelated files, or claim a push/commit/test succeeded unless verified. If GitHub access is unavailable, leave a clean local commit if possible and report the exact blocker.
• Final response must summarize implementation, tests actually run and results, update.md entry, commit hash/branch, push status and remaining blockers. Do not say “all bugs fixed” unless checks support that claim.

Act as Member 3 for final reporting QA. Before edits, read all relevant repository *.md files and `update.md`, inspect the reporting module and current Git status, and inspect the report-flow screens in the AquaTrace UI PDF.

Test the complete reporting journey from citizen login to successful submission and confirmation. Cover camera/gallery permissions, no GPS signal, denied location permission, invalid/missing fields, low connectivity, image upload failure, Firestore failure, duplicate submission, app restart and report ownership. Confirm that the saved report can be consumed by the map and admin modules using the documented schema. Compare layout and interaction with the UI PDF. Fix every reproducible issue in your module and record cross-module blockers clearly.

Run formatter, analyzer, tests and app launch/build. Update root `update.md` with final status, test commands/results, known limitations and actual `Asia/Colombo` timestamp with offset. Review diff/status, commit intended changes and push if configured. Report commit hash and handoff notes.
```


# Member 4 — Interactive Map & Location Services

## Prompt 4A — Build interactive fault map

```text
MANDATORY EXECUTION RULES — apply these in every prompt:
• Work in the existing AquaTrace repository; do not create a parallel app or replace the project wholesale.
• Preflight is mandatory: inspect the repository tree; read all relevant `*.md` files (including README, architecture/specification/data-contract docs and the latest `update.md`); inspect `pubspec.yaml`, current implementation, Git status and recent history; locate and inspect the UI PDF stored in the project files/repository. Render/inspect every PDF page and its embedded screens, not just extracted text. Use the proposal and UI PDF as the source of truth for scope and visual design. If the PDF or required docs cannot be found/read, state that clearly and pause any UI-dependent assumptions.
• Reuse established architecture, dependencies, naming, theme, data models and interfaces. Do not overwrite another member's work or shared files without coordination. Do not add credentials/secrets to Git.
• Implement the assigned scope end-to-end, including UI, state, backend integration, validation, loading/empty/error states and accessibility. Avoid placeholder/mock behavior in real workflows unless explicitly labelled as demo data.
• QA is mandatory on every run: format code; run static analysis; run relevant automated tests; build/launch the app on an available target; exercise the assigned feature and key failure paths; fix every reproducible bug in scope and rerun checks. If a device, Firebase project, emulator, credentials or external service is unavailable, run all remaining checks and record the exact environmental blocker—never claim success falsely.
• At the end of every run, create/update repository-root `update.md`. Append a dated entry with actual completed tasks, files/modules changed, remaining tasks/blockers, exact commands and outcomes, and current date/time in `Asia/Colombo` with UTC offset. Obtain the timestamp from the system clock at execution time; do not invent or reuse an old timestamp.
• Before committing, inspect `git diff` and `git status`; stage only the changes belonging to this task. Make a descriptive Git commit. Push the current working branch if a remote and valid authentication are configured. Never force-push, rewrite shared history, commit unrelated files, or claim a push/commit/test succeeded unless verified. If GitHub access is unavailable, leave a clean local commit if possible and report the exact blocker.
• Final response must summarize implementation, tests actually run and results, update.md entry, commit hash/branch, push status and remaining blockers. Do not say “all bugs fixed” unless checks support that claim.

You are Member 4 and own AquaTrace's interactive map and location-services module. Before coding, inspect the repository and read all relevant *.md files, including README, architecture, data contracts and `update.md`; inspect routes, theme, Firebase setup, report model and Git status. Locate and inspect the AquaTrace UI PDF. Study the citizen fault map, map markers, status legend, search, filters, zoom controls and technician navigation/map screens. Do not assume the PDF path or invent UI requirements if it is missing.

Implement OpenStreetMap with the repository's selected Flutter map package (use existing dependencies where possible). Display report markers from the shared Firestore schema; distinguish pending, assigned, ongoing, completed and disputed statuses; show useful report details on marker selection; show current location with permission/error handling; provide map zoom controls, location search if a suitable configured service exists, and status filters matching the design. Avoid hard-coded sample reports in production flows. Handle loading, empty, offline and permission-denied states. Use a configurable tile source and respect its usage policy; do not add secret API keys to source control.

Run formatter, analyzer, tests and app launch/build. Verify marker rendering, status filtering, permissions and navigation. Fix every reproducible bug. Update root `update.md` with completed tasks, blockers, test commands/results and actual current `Asia/Colombo` date/time with UTC offset. Review diff/status, commit only intended changes and push if configured. Report commit hash and blockers.
```

## Prompt 4B — Map data integration and location behavior

```text
MANDATORY EXECUTION RULES — apply these in every prompt:
• Work in the existing AquaTrace repository; do not create a parallel app or replace the project wholesale.
• Preflight is mandatory: inspect the repository tree; read all relevant `*.md` files (including README, architecture/specification/data-contract docs and the latest `update.md`); inspect `pubspec.yaml`, current implementation, Git status and recent history; locate and inspect the UI PDF stored in the project files/repository. Render/inspect every PDF page and its embedded screens, not just extracted text. Use the proposal and UI PDF as the source of truth for scope and visual design. If the PDF or required docs cannot be found/read, state that clearly and pause any UI-dependent assumptions.
• Reuse established architecture, dependencies, naming, theme, data models and interfaces. Do not overwrite another member's work or shared files without coordination. Do not add credentials/secrets to Git.
• Implement the assigned scope end-to-end, including UI, state, backend integration, validation, loading/empty/error states and accessibility. Avoid placeholder/mock behavior in real workflows unless explicitly labelled as demo data.
• QA is mandatory on every run: format code; run static analysis; run relevant automated tests; build/launch the app on an available target; exercise the assigned feature and key failure paths; fix every reproducible bug in scope and rerun checks. If a device, Firebase project, emulator, credentials or external service is unavailable, run all remaining checks and record the exact environmental blocker—never claim success falsely.
• At the end of every run, create/update repository-root `update.md`. Append a dated entry with actual completed tasks, files/modules changed, remaining tasks/blockers, exact commands and outcomes, and current date/time in `Asia/Colombo` with UTC offset. Obtain the timestamp from the system clock at execution time; do not invent or reuse an old timestamp.
• Before committing, inspect `git diff` and `git status`; stage only the changes belonging to this task. Make a descriptive Git commit. Push the current working branch if a remote and valid authentication are configured. Never force-push, rewrite shared history, commit unrelated files, or claim a push/commit/test succeeded unless verified. If GitHub access is unavailable, leave a clean local commit if possible and report the exact blocker.
• Final response must summarize implementation, tests actually run and results, update.md entry, commit hash/branch, push status and remaining blockers. Do not say “all bugs fixed” unless checks support that claim.

Continue as Member 4. Before editing, read all relevant repository *.md files and `update.md`; inspect map implementation, report model, Firestore query patterns, location permission setup, routing and Git status. Re-inspect the AquaTrace UI PDF map screens and status legend.

Integrate map queries with real Firestore report data and the agreed status/coordinate fields. Ensure marker positions use latitude/longitude correctly; update the map when data changes where practical; avoid unbounded reads and handle query/index errors. Ensure map filters match the actual status enum and do not hide data incorrectly. Make current-location behavior clear and permission-safe. Provide a reliable route handoff for technician navigation without falsely claiming turn-by-turn navigation if only an external map launch is implemented. Coordinate required schema changes with Members 3, 5 and 6 rather than changing their code unilaterally.

Run formatter, analyzer, tests and app launch/build. Verify map with multiple statuses and edge cases; fix all reproducible bugs. Update `update.md` with integration results, remaining items, exact test outcomes and current `Asia/Colombo` timestamp with offset. Inspect diff/status, commit and push if configured. Report commit hash and blockers.
```

## Prompt 4C — Map regression and handoff

```text
MANDATORY EXECUTION RULES — apply these in every prompt:
• Work in the existing AquaTrace repository; do not create a parallel app or replace the project wholesale.
• Preflight is mandatory: inspect the repository tree; read all relevant `*.md` files (including README, architecture/specification/data-contract docs and the latest `update.md`); inspect `pubspec.yaml`, current implementation, Git status and recent history; locate and inspect the UI PDF stored in the project files/repository. Render/inspect every PDF page and its embedded screens, not just extracted text. Use the proposal and UI PDF as the source of truth for scope and visual design. If the PDF or required docs cannot be found/read, state that clearly and pause any UI-dependent assumptions.
• Reuse established architecture, dependencies, naming, theme, data models and interfaces. Do not overwrite another member's work or shared files without coordination. Do not add credentials/secrets to Git.
• Implement the assigned scope end-to-end, including UI, state, backend integration, validation, loading/empty/error states and accessibility. Avoid placeholder/mock behavior in real workflows unless explicitly labelled as demo data.
• QA is mandatory on every run: format code; run static analysis; run relevant automated tests; build/launch the app on an available target; exercise the assigned feature and key failure paths; fix every reproducible bug in scope and rerun checks. If a device, Firebase project, emulator, credentials or external service is unavailable, run all remaining checks and record the exact environmental blocker—never claim success falsely.
• At the end of every run, create/update repository-root `update.md`. Append a dated entry with actual completed tasks, files/modules changed, remaining tasks/blockers, exact commands and outcomes, and current date/time in `Asia/Colombo` with UTC offset. Obtain the timestamp from the system clock at execution time; do not invent or reuse an old timestamp.
• Before committing, inspect `git diff` and `git status`; stage only the changes belonging to this task. Make a descriptive Git commit. Push the current working branch if a remote and valid authentication are configured. Never force-push, rewrite shared history, commit unrelated files, or claim a push/commit/test succeeded unless verified. If GitHub access is unavailable, leave a clean local commit if possible and report the exact blocker.
• Final response must summarize implementation, tests actually run and results, update.md entry, commit hash/branch, push status and remaining blockers. Do not say “all bugs fixed” unless checks support that claim.

Act as Member 4 for final map QA. First read all relevant repository *.md files and `update.md`, inspect current map code and Git status, and inspect the map-related screens in the AquaTrace UI PDF.

Perform a regression pass on tile loading, marker placement, marker status colours, report detail selection, filters, search, zoom, current-location permissions, location unavailable/offline states and navigation handoff. Test invalid/out-of-range coordinates and reports with missing coordinates; handle them safely without crashing. Verify performance with many markers and avoid unnecessary repeated Firestore reads. Fix all reproducible issues in your module and document external blockers.

Run formatter, analyzer, tests and app launch/build. Update root `update.md` with final module status, checks/results, limitations and actual `Asia/Colombo` timestamp with UTC offset. Review diff/status, commit and push if configured. Report commit hash and integration notes.
```


# Member 5 — Admin Dashboard & Report Management

## Prompt 5A — Build admin dashboard and report review

```text
MANDATORY EXECUTION RULES — apply these in every prompt:
• Work in the existing AquaTrace repository; do not create a parallel app or replace the project wholesale.
• Preflight is mandatory: inspect the repository tree; read all relevant `*.md` files (including README, architecture/specification/data-contract docs and the latest `update.md`); inspect `pubspec.yaml`, current implementation, Git status and recent history; locate and inspect the UI PDF stored in the project files/repository. Render/inspect every PDF page and its embedded screens, not just extracted text. Use the proposal and UI PDF as the source of truth for scope and visual design. If the PDF or required docs cannot be found/read, state that clearly and pause any UI-dependent assumptions.
• Reuse established architecture, dependencies, naming, theme, data models and interfaces. Do not overwrite another member's work or shared files without coordination. Do not add credentials/secrets to Git.
• Implement the assigned scope end-to-end, including UI, state, backend integration, validation, loading/empty/error states and accessibility. Avoid placeholder/mock behavior in real workflows unless explicitly labelled as demo data.
• QA is mandatory on every run: format code; run static analysis; run relevant automated tests; build/launch the app on an available target; exercise the assigned feature and key failure paths; fix every reproducible bug in scope and rerun checks. If a device, Firebase project, emulator, credentials or external service is unavailable, run all remaining checks and record the exact environmental blocker—never claim success falsely.
• At the end of every run, create/update repository-root `update.md`. Append a dated entry with actual completed tasks, files/modules changed, remaining tasks/blockers, exact commands and outcomes, and current date/time in `Asia/Colombo` with UTC offset. Obtain the timestamp from the system clock at execution time; do not invent or reuse an old timestamp.
• Before committing, inspect `git diff` and `git status`; stage only the changes belonging to this task. Make a descriptive Git commit. Push the current working branch if a remote and valid authentication are configured. Never force-push, rewrite shared history, commit unrelated files, or claim a push/commit/test succeeded unless verified. If GitHub access is unavailable, leave a clean local commit if possible and report the exact blocker.
• Final response must summarize implementation, tests actually run and results, update.md entry, commit hash/branch, push status and remaining blockers. Do not say “all bugs fixed” unless checks support that claim.

You are Member 5 and own AquaTrace's admin dashboard and report-management module. Before coding, read all relevant repository *.md files including README, architecture, Firestore schema/security notes and `update.md`; inspect app routes, theme, role model, Firebase services, report model and Git status. Locate and inspect the AquaTrace UI PDF. Study the admin dashboard, report list/review, status filters, priority cards, quick actions, assign-technician flow and activity-history design. Do not assume the PDF path or invent missing screens.

Implement an admin-only dashboard with real counts for total, pending, assigned, ongoing, completed and disputed reports; report list/filter/search; report detail/review; approve/reject or request correction according to the documented workflow; severity/priority display and admin quick actions. Implement analytics/trend visualizations only using available real data and meaningful date ranges. Restrict access to Admin role using the established auth/rules approach. Do not create fake statistics or allow client-side role spoofing. Coordinate technician assignment with Member 6 and data contracts with Member 3.

Run formatter, analyzer, tests and app launch/build. Verify role access, empty/loading/error states, report review and data refresh. Fix every reproducible bug. Update root `update.md` with completed tasks, outstanding items, exact test results and actual `Asia/Colombo` date/time with offset. Review diff/status, commit only your module changes and push if configured. Report commit hash and blockers.
```

## Prompt 5B — Admin assignment and workflow integration

```text
MANDATORY EXECUTION RULES — apply these in every prompt:
• Work in the existing AquaTrace repository; do not create a parallel app or replace the project wholesale.
• Preflight is mandatory: inspect the repository tree; read all relevant `*.md` files (including README, architecture/specification/data-contract docs and the latest `update.md`); inspect `pubspec.yaml`, current implementation, Git status and recent history; locate and inspect the UI PDF stored in the project files/repository. Render/inspect every PDF page and its embedded screens, not just extracted text. Use the proposal and UI PDF as the source of truth for scope and visual design. If the PDF or required docs cannot be found/read, state that clearly and pause any UI-dependent assumptions.
• Reuse established architecture, dependencies, naming, theme, data models and interfaces. Do not overwrite another member's work or shared files without coordination. Do not add credentials/secrets to Git.
• Implement the assigned scope end-to-end, including UI, state, backend integration, validation, loading/empty/error states and accessibility. Avoid placeholder/mock behavior in real workflows unless explicitly labelled as demo data.
• QA is mandatory on every run: format code; run static analysis; run relevant automated tests; build/launch the app on an available target; exercise the assigned feature and key failure paths; fix every reproducible bug in scope and rerun checks. If a device, Firebase project, emulator, credentials or external service is unavailable, run all remaining checks and record the exact environmental blocker—never claim success falsely.
• At the end of every run, create/update repository-root `update.md`. Append a dated entry with actual completed tasks, files/modules changed, remaining tasks/blockers, exact commands and outcomes, and current date/time in `Asia/Colombo` with UTC offset. Obtain the timestamp from the system clock at execution time; do not invent or reuse an old timestamp.
• Before committing, inspect `git diff` and `git status`; stage only the changes belonging to this task. Make a descriptive Git commit. Push the current working branch if a remote and valid authentication are configured. Never force-push, rewrite shared history, commit unrelated files, or claim a push/commit/test succeeded unless verified. If GitHub access is unavailable, leave a clean local commit if possible and report the exact blocker.
• Final response must summarize implementation, tests actually run and results, update.md entry, commit hash/branch, push status and remaining blockers. Do not say “all bugs fixed” unless checks support that claim.

Continue as Member 5. Before edits, read all relevant repository *.md files and `update.md`; inspect admin code, report status model, technician/user schema, Firestore rules and Git status. Inspect the AquaTrace UI PDF's admin review, assign-technician and activity screens again.

Integrate admin review and assignment with the shared Firestore contracts. Ensure only authorized admins can verify reports, change priority and assign technicians. Assignment must persist technician UID, assignment time and relevant status fields, and must not overwrite unrelated report data. Display available/busy technician information only if supported by actual stored data. Ensure status transitions are validated and visible to citizen/technician modules. Implement analytics from actual Firestore data with sensible query limits and error handling. Coordinate interfaces with Members 3, 6, 7 and 8; do not directly rewrite their modules.

Run formatter, analyzer, tests and app launch/build. Test unauthorized access, approving, rejecting, assigning, invalid transitions and data refresh. Fix all reproducible bugs. Update `update.md` with integration tasks, remaining blockers, exact test results and actual `Asia/Colombo` timestamp with offset. Inspect diff/status, commit and push if configured. Report commit hash and blockers.
```

## Prompt 5C — Admin regression and handoff

```text
MANDATORY EXECUTION RULES — apply these in every prompt:
• Work in the existing AquaTrace repository; do not create a parallel app or replace the project wholesale.
• Preflight is mandatory: inspect the repository tree; read all relevant `*.md` files (including README, architecture/specification/data-contract docs and the latest `update.md`); inspect `pubspec.yaml`, current implementation, Git status and recent history; locate and inspect the UI PDF stored in the project files/repository. Render/inspect every PDF page and its embedded screens, not just extracted text. Use the proposal and UI PDF as the source of truth for scope and visual design. If the PDF or required docs cannot be found/read, state that clearly and pause any UI-dependent assumptions.
• Reuse established architecture, dependencies, naming, theme, data models and interfaces. Do not overwrite another member's work or shared files without coordination. Do not add credentials/secrets to Git.
• Implement the assigned scope end-to-end, including UI, state, backend integration, validation, loading/empty/error states and accessibility. Avoid placeholder/mock behavior in real workflows unless explicitly labelled as demo data.
• QA is mandatory on every run: format code; run static analysis; run relevant automated tests; build/launch the app on an available target; exercise the assigned feature and key failure paths; fix every reproducible bug in scope and rerun checks. If a device, Firebase project, emulator, credentials or external service is unavailable, run all remaining checks and record the exact environmental blocker—never claim success falsely.
• At the end of every run, create/update repository-root `update.md`. Append a dated entry with actual completed tasks, files/modules changed, remaining tasks/blockers, exact commands and outcomes, and current date/time in `Asia/Colombo` with UTC offset. Obtain the timestamp from the system clock at execution time; do not invent or reuse an old timestamp.
• Before committing, inspect `git diff` and `git status`; stage only the changes belonging to this task. Make a descriptive Git commit. Push the current working branch if a remote and valid authentication are configured. Never force-push, rewrite shared history, commit unrelated files, or claim a push/commit/test succeeded unless verified. If GitHub access is unavailable, leave a clean local commit if possible and report the exact blocker.
• Final response must summarize implementation, tests actually run and results, update.md entry, commit hash/branch, push status and remaining blockers. Do not say “all bugs fixed” unless checks support that claim.

Act as Member 5 for final admin QA. First read all relevant repository *.md files and `update.md`, inspect admin/report-management implementation and Git status, and inspect the admin screens in the AquaTrace UI PDF.

Test admin dashboard counts, filters, search, report detail, evidence viewing, review decisions, priority updates, technician assignment, analytics and activity history. Verify access is denied to citizens and technicians, and ensure the UI does not rely solely on hidden controls for security. Test empty data, missing fields, network failures, permission errors and stale data. Confirm status changes are consistent with citizen, technician, verification and notification modules. Fix all reproducible bugs in your module and document cross-module blockers.

Run formatter, analyzer, tests and app launch/build. Update root `update.md` with final status, checks/results, known limitations and actual `Asia/Colombo` timestamp with UTC offset. Review diff/status, commit intended changes and push if configured. Report commit hash and handoff notes.
```


# Member 6 — Technician Management System

## Prompt 6A — Build technician dashboard and job queue

```text
MANDATORY EXECUTION RULES — apply these in every prompt:
• Work in the existing AquaTrace repository; do not create a parallel app or replace the project wholesale.
• Preflight is mandatory: inspect the repository tree; read all relevant `*.md` files (including README, architecture/specification/data-contract docs and the latest `update.md`); inspect `pubspec.yaml`, current implementation, Git status and recent history; locate and inspect the UI PDF stored in the project files/repository. Render/inspect every PDF page and its embedded screens, not just extracted text. Use the proposal and UI PDF as the source of truth for scope and visual design. If the PDF or required docs cannot be found/read, state that clearly and pause any UI-dependent assumptions.
• Reuse established architecture, dependencies, naming, theme, data models and interfaces. Do not overwrite another member's work or shared files without coordination. Do not add credentials/secrets to Git.
• Implement the assigned scope end-to-end, including UI, state, backend integration, validation, loading/empty/error states and accessibility. Avoid placeholder/mock behavior in real workflows unless explicitly labelled as demo data.
• QA is mandatory on every run: format code; run static analysis; run relevant automated tests; build/launch the app on an available target; exercise the assigned feature and key failure paths; fix every reproducible bug in scope and rerun checks. If a device, Firebase project, emulator, credentials or external service is unavailable, run all remaining checks and record the exact environmental blocker—never claim success falsely.
• At the end of every run, create/update repository-root `update.md`. Append a dated entry with actual completed tasks, files/modules changed, remaining tasks/blockers, exact commands and outcomes, and current date/time in `Asia/Colombo` with UTC offset. Obtain the timestamp from the system clock at execution time; do not invent or reuse an old timestamp.
• Before committing, inspect `git diff` and `git status`; stage only the changes belonging to this task. Make a descriptive Git commit. Push the current working branch if a remote and valid authentication are configured. Never force-push, rewrite shared history, commit unrelated files, or claim a push/commit/test succeeded unless verified. If GitHub access is unavailable, leave a clean local commit if possible and report the exact blocker.
• Final response must summarize implementation, tests actually run and results, update.md entry, commit hash/branch, push status and remaining blockers. Do not say “all bugs fixed” unless checks support that claim.

You are Member 6 and own AquaTrace's technician-side job-management module. Before coding, read all relevant repository *.md files including README, architecture, data contracts and `update.md`; inspect routes, role model, theme, Firebase setup, report schema and Git status. Locate and inspect the AquaTrace UI PDF. Study technician dashboard, job queue, job detail, map/navigation, status controls, repair evidence and technician profile screens. Do not assume the PDF path; report if it is missing.

Implement technician-only dashboard with counts for new/ongoing/completed jobs, assigned job queue, job details, location/address and severity, job acceptance/start/progress/completion actions, repair notes and after-repair photo upload to Firebase Storage. Save updates against the correct report and technician UID, preserving status history and timestamps. Provide a map/location handoff using Member 4's interface or agreed navigation method. Do not let technicians access unassigned jobs or change admin-only fields. Follow the existing UI and shared data contracts.

Run formatter, analyzer, tests and app launch/build. Verify role gating, job queue, status transitions and photo upload. Fix every reproducible bug. Update root `update.md` with completed tasks, outstanding items, test commands/results and actual current `Asia/Colombo` date/time with UTC offset. Review diff/status, commit only intended changes and push if configured. Report commit hash and blockers.
```

## Prompt 6B — Technician workflow integration

```text
MANDATORY EXECUTION RULES — apply these in every prompt:
• Work in the existing AquaTrace repository; do not create a parallel app or replace the project wholesale.
• Preflight is mandatory: inspect the repository tree; read all relevant `*.md` files (including README, architecture/specification/data-contract docs and the latest `update.md`); inspect `pubspec.yaml`, current implementation, Git status and recent history; locate and inspect the UI PDF stored in the project files/repository. Render/inspect every PDF page and its embedded screens, not just extracted text. Use the proposal and UI PDF as the source of truth for scope and visual design. If the PDF or required docs cannot be found/read, state that clearly and pause any UI-dependent assumptions.
• Reuse established architecture, dependencies, naming, theme, data models and interfaces. Do not overwrite another member's work or shared files without coordination. Do not add credentials/secrets to Git.
• Implement the assigned scope end-to-end, including UI, state, backend integration, validation, loading/empty/error states and accessibility. Avoid placeholder/mock behavior in real workflows unless explicitly labelled as demo data.
• QA is mandatory on every run: format code; run static analysis; run relevant automated tests; build/launch the app on an available target; exercise the assigned feature and key failure paths; fix every reproducible bug in scope and rerun checks. If a device, Firebase project, emulator, credentials or external service is unavailable, run all remaining checks and record the exact environmental blocker—never claim success falsely.
• At the end of every run, create/update repository-root `update.md`. Append a dated entry with actual completed tasks, files/modules changed, remaining tasks/blockers, exact commands and outcomes, and current date/time in `Asia/Colombo` with UTC offset. Obtain the timestamp from the system clock at execution time; do not invent or reuse an old timestamp.
• Before committing, inspect `git diff` and `git status`; stage only the changes belonging to this task. Make a descriptive Git commit. Push the current working branch if a remote and valid authentication are configured. Never force-push, rewrite shared history, commit unrelated files, or claim a push/commit/test succeeded unless verified. If GitHub access is unavailable, leave a clean local commit if possible and report the exact blocker.
• Final response must summarize implementation, tests actually run and results, update.md entry, commit hash/branch, push status and remaining blockers. Do not say “all bugs fixed” unless checks support that claim.

Continue as Member 6. Before changing code, read all relevant repository *.md files and `update.md`; inspect technician implementation, assignment fields, report status enum, storage conventions, map/navigation interfaces and Git status. Re-inspect the AquaTrace UI PDF's technician job screens.

Integrate the job queue with admin assignments. Query only jobs assigned to the signed-in technician; ensure assignment changes appear correctly; implement safe transitions such as Assigned → Ongoing → Completed according to the agreed workflow. Persist technician identity, timestamps, repair notes and after-repair evidence. Do not allow arbitrary report status changes or completion without required evidence if the agreed requirements require it. Ensure citizens/admins can see relevant updates through shared report records. Coordinate notifications with Member 8 and map handoff with Member 4.

Run formatter, analyzer, tests and app launch/build. Test unassigned-job access, assignment changes, invalid transitions, image upload failures and offline/retry behavior. Fix all reproducible bugs. Update `update.md` with integration completion, remaining tasks, exact test results and current `Asia/Colombo` timestamp with offset. Review diff/status, commit and push if configured. Report commit hash and blockers.
```

## Prompt 6C — Technician regression and handoff

```text
MANDATORY EXECUTION RULES — apply these in every prompt:
• Work in the existing AquaTrace repository; do not create a parallel app or replace the project wholesale.
• Preflight is mandatory: inspect the repository tree; read all relevant `*.md` files (including README, architecture/specification/data-contract docs and the latest `update.md`); inspect `pubspec.yaml`, current implementation, Git status and recent history; locate and inspect the UI PDF stored in the project files/repository. Render/inspect every PDF page and its embedded screens, not just extracted text. Use the proposal and UI PDF as the source of truth for scope and visual design. If the PDF or required docs cannot be found/read, state that clearly and pause any UI-dependent assumptions.
• Reuse established architecture, dependencies, naming, theme, data models and interfaces. Do not overwrite another member's work or shared files without coordination. Do not add credentials/secrets to Git.
• Implement the assigned scope end-to-end, including UI, state, backend integration, validation, loading/empty/error states and accessibility. Avoid placeholder/mock behavior in real workflows unless explicitly labelled as demo data.
• QA is mandatory on every run: format code; run static analysis; run relevant automated tests; build/launch the app on an available target; exercise the assigned feature and key failure paths; fix every reproducible bug in scope and rerun checks. If a device, Firebase project, emulator, credentials or external service is unavailable, run all remaining checks and record the exact environmental blocker—never claim success falsely.
• At the end of every run, create/update repository-root `update.md`. Append a dated entry with actual completed tasks, files/modules changed, remaining tasks/blockers, exact commands and outcomes, and current date/time in `Asia/Colombo` with UTC offset. Obtain the timestamp from the system clock at execution time; do not invent or reuse an old timestamp.
• Before committing, inspect `git diff` and `git status`; stage only the changes belonging to this task. Make a descriptive Git commit. Push the current working branch if a remote and valid authentication are configured. Never force-push, rewrite shared history, commit unrelated files, or claim a push/commit/test succeeded unless verified. If GitHub access is unavailable, leave a clean local commit if possible and report the exact blocker.
• Final response must summarize implementation, tests actually run and results, update.md entry, commit hash/branch, push status and remaining blockers. Do not say “all bugs fixed” unless checks support that claim.

Act as Member 6 for final technician QA. First read all relevant repository *.md files and `update.md`, inspect technician code and Git status, and inspect the technician screens in the AquaTrace UI PDF.

Test technician login/role access, assigned job queue, job details, navigation handoff, accept/start/complete workflow, notes, after-repair photo upload, job history and data refresh. Verify a technician cannot view or modify another technician's private/unassigned jobs and cannot perform admin actions. Test missing assignment data, revoked assignment, weak network, denied camera/storage permissions and upload failures. Fix all reproducible bugs in your module and document dependencies on other owners.

Run formatter, analyzer, tests and app launch/build. Update root `update.md` with final status, test commands/results, limitations and actual `Asia/Colombo` timestamp with UTC offset. Review diff/status, commit and push if configured. Report commit hash and handoff notes.
```


# Member 7 — Community Verification & Dispute Management

## Prompt 7A — Build citizen repair verification

```text
MANDATORY EXECUTION RULES — apply these in every prompt:
• Work in the existing AquaTrace repository; do not create a parallel app or replace the project wholesale.
• Preflight is mandatory: inspect the repository tree; read all relevant `*.md` files (including README, architecture/specification/data-contract docs and the latest `update.md`); inspect `pubspec.yaml`, current implementation, Git status and recent history; locate and inspect the UI PDF stored in the project files/repository. Render/inspect every PDF page and its embedded screens, not just extracted text. Use the proposal and UI PDF as the source of truth for scope and visual design. If the PDF or required docs cannot be found/read, state that clearly and pause any UI-dependent assumptions.
• Reuse established architecture, dependencies, naming, theme, data models and interfaces. Do not overwrite another member's work or shared files without coordination. Do not add credentials/secrets to Git.
• Implement the assigned scope end-to-end, including UI, state, backend integration, validation, loading/empty/error states and accessibility. Avoid placeholder/mock behavior in real workflows unless explicitly labelled as demo data.
• QA is mandatory on every run: format code; run static analysis; run relevant automated tests; build/launch the app on an available target; exercise the assigned feature and key failure paths; fix every reproducible bug in scope and rerun checks. If a device, Firebase project, emulator, credentials or external service is unavailable, run all remaining checks and record the exact environmental blocker—never claim success falsely.
• At the end of every run, create/update repository-root `update.md`. Append a dated entry with actual completed tasks, files/modules changed, remaining tasks/blockers, exact commands and outcomes, and current date/time in `Asia/Colombo` with UTC offset. Obtain the timestamp from the system clock at execution time; do not invent or reuse an old timestamp.
• Before committing, inspect `git diff` and `git status`; stage only the changes belonging to this task. Make a descriptive Git commit. Push the current working branch if a remote and valid authentication are configured. Never force-push, rewrite shared history, commit unrelated files, or claim a push/commit/test succeeded unless verified. If GitHub access is unavailable, leave a clean local commit if possible and report the exact blocker.
• Final response must summarize implementation, tests actually run and results, update.md entry, commit hash/branch, push status and remaining blockers. Do not say “all bugs fixed” unless checks support that claim.

You are Member 7 and own AquaTrace's community repair verification and dispute module. Before coding, read all relevant repository *.md files including README, architecture, Firestore schema, workflow/security notes and `update.md`; inspect report status model, auth roles, location services, routes and Git status. Locate and inspect the AquaTrace UI PDF, especially the citizen notification/verify-repair screen, report details, community verification states and admin dispute screens. Do not assume a PDF path or invent absent behavior.

Implement the citizen verification flow for completed repairs. Find eligible completed repairs within the configured radius using the shared location/report model; show repair details and evidence; allow nearby authenticated citizens to confirm resolution or raise a dispute with a reason/evidence if supported. Prevent the reporter/technician or duplicate voters from bypassing agreed eligibility rules if the project specification defines restrictions. Persist each verification/dispute with user UID, report ID and timestamp. Implement threshold-based community confirmation and disputed status using a clearly documented, race-safe approach. Do not trust client-provided distance or vote counts as authoritative; enforce critical rules in Firestore security rules or trusted backend logic where available.

Run formatter, analyzer, tests and app launch/build. Test eligible/ineligible users, duplicate votes, threshold, disputes and failure paths. Fix all reproducible bugs. Update root `update.md` with completed tasks, outstanding items, test results and actual current `Asia/Colombo` date/time with UTC offset. Inspect diff/status, commit only your module changes and push if configured. Report commit hash and blockers.
```

## Prompt 7B — Dispute workflow and automatic reopening

```text
MANDATORY EXECUTION RULES — apply these in every prompt:
• Work in the existing AquaTrace repository; do not create a parallel app or replace the project wholesale.
• Preflight is mandatory: inspect the repository tree; read all relevant `*.md` files (including README, architecture/specification/data-contract docs and the latest `update.md`); inspect `pubspec.yaml`, current implementation, Git status and recent history; locate and inspect the UI PDF stored in the project files/repository. Render/inspect every PDF page and its embedded screens, not just extracted text. Use the proposal and UI PDF as the source of truth for scope and visual design. If the PDF or required docs cannot be found/read, state that clearly and pause any UI-dependent assumptions.
• Reuse established architecture, dependencies, naming, theme, data models and interfaces. Do not overwrite another member's work or shared files without coordination. Do not add credentials/secrets to Git.
• Implement the assigned scope end-to-end, including UI, state, backend integration, validation, loading/empty/error states and accessibility. Avoid placeholder/mock behavior in real workflows unless explicitly labelled as demo data.
• QA is mandatory on every run: format code; run static analysis; run relevant automated tests; build/launch the app on an available target; exercise the assigned feature and key failure paths; fix every reproducible bug in scope and rerun checks. If a device, Firebase project, emulator, credentials or external service is unavailable, run all remaining checks and record the exact environmental blocker—never claim success falsely.
• At the end of every run, create/update repository-root `update.md`. Append a dated entry with actual completed tasks, files/modules changed, remaining tasks/blockers, exact commands and outcomes, and current date/time in `Asia/Colombo` with UTC offset. Obtain the timestamp from the system clock at execution time; do not invent or reuse an old timestamp.
• Before committing, inspect `git diff` and `git status`; stage only the changes belonging to this task. Make a descriptive Git commit. Push the current working branch if a remote and valid authentication are configured. Never force-push, rewrite shared history, commit unrelated files, or claim a push/commit/test succeeded unless verified. If GitHub access is unavailable, leave a clean local commit if possible and report the exact blocker.
• Final response must summarize implementation, tests actually run and results, update.md entry, commit hash/branch, push status and remaining blockers. Do not say “all bugs fixed” unless checks support that claim.

Continue as Member 7. Before edits, read all relevant repository *.md files and `update.md`; inspect verification implementation, report status transitions, admin dispute interface, Firestore security rules and Git status. Re-inspect the AquaTrace UI PDF's verify-repair, dispute and activity-history screens.

Complete integration with the report lifecycle. A valid dispute against a completed repair must move the case into the agreed disputed/reopened state, create an auditable event and notify the admin workflow through the agreed data contract. A successful verification must be recorded with unique voter identity and must not be counted multiple times. Define and document the radius, verification threshold and eligibility assumptions based on project documentation; if unspecified, make them configurable and clearly record the chosen demo defaults rather than silently treating them as proposal requirements. Avoid non-atomic read-modify-write races; use transactions or trusted backend logic as appropriate. Coordinate notification/history events with Member 8 and admin review with Member 5.

Run formatter, analyzer, tests and app launch/build. Test concurrent/duplicate submissions, dispute after completion, reopening and authorization. Fix all reproducible bugs. Update `update.md` with integration details, open questions, exact tests and current `Asia/Colombo` timestamp with offset. Inspect diff/status, commit and push if configured. Report commit hash and blockers.
```

## Prompt 7C — Verification regression and handoff

```text
MANDATORY EXECUTION RULES — apply these in every prompt:
• Work in the existing AquaTrace repository; do not create a parallel app or replace the project wholesale.
• Preflight is mandatory: inspect the repository tree; read all relevant `*.md` files (including README, architecture/specification/data-contract docs and the latest `update.md`); inspect `pubspec.yaml`, current implementation, Git status and recent history; locate and inspect the UI PDF stored in the project files/repository. Render/inspect every PDF page and its embedded screens, not just extracted text. Use the proposal and UI PDF as the source of truth for scope and visual design. If the PDF or required docs cannot be found/read, state that clearly and pause any UI-dependent assumptions.
• Reuse established architecture, dependencies, naming, theme, data models and interfaces. Do not overwrite another member's work or shared files without coordination. Do not add credentials/secrets to Git.
• Implement the assigned scope end-to-end, including UI, state, backend integration, validation, loading/empty/error states and accessibility. Avoid placeholder/mock behavior in real workflows unless explicitly labelled as demo data.
• QA is mandatory on every run: format code; run static analysis; run relevant automated tests; build/launch the app on an available target; exercise the assigned feature and key failure paths; fix every reproducible bug in scope and rerun checks. If a device, Firebase project, emulator, credentials or external service is unavailable, run all remaining checks and record the exact environmental blocker—never claim success falsely.
• At the end of every run, create/update repository-root `update.md`. Append a dated entry with actual completed tasks, files/modules changed, remaining tasks/blockers, exact commands and outcomes, and current date/time in `Asia/Colombo` with UTC offset. Obtain the timestamp from the system clock at execution time; do not invent or reuse an old timestamp.
• Before committing, inspect `git diff` and `git status`; stage only the changes belonging to this task. Make a descriptive Git commit. Push the current working branch if a remote and valid authentication are configured. Never force-push, rewrite shared history, commit unrelated files, or claim a push/commit/test succeeded unless verified. If GitHub access is unavailable, leave a clean local commit if possible and report the exact blocker.
• Final response must summarize implementation, tests actually run and results, update.md entry, commit hash/branch, push status and remaining blockers. Do not say “all bugs fixed” unless checks support that claim.

Act as Member 7 for final verification/dispute QA. First read all relevant repository *.md files and `update.md`, inspect current verification code and Git status, and inspect the relevant UI PDF screens.

Test the full lifecycle: technician completes repair, eligible nearby citizens receive/show verification request, a citizen confirms, duplicate votes are rejected, threshold is reached, a dispute is raised, admin can review it and the case reopens according to the documented workflow. Test GPS unavailable, user outside radius, unauthenticated user, duplicate account actions, concurrent submissions, missing evidence and network errors. Verify the audit trail and report status are consistent. Fix all reproducible defects in your module and list any unresolved security/backend dependency explicitly.

Run formatter, analyzer, tests and app launch/build. Update root `update.md` with final status, checks/results, configured threshold/radius assumptions and actual `Asia/Colombo` timestamp with offset. Review diff/status, commit and push if configured. Report commit hash and handoff notes.
```


# Member 8 — Notifications & Report History

## Prompt 8A — Build notifications and report history

```text
MANDATORY EXECUTION RULES — apply these in every prompt:
• Work in the existing AquaTrace repository; do not create a parallel app or replace the project wholesale.
• Preflight is mandatory: inspect the repository tree; read all relevant `*.md` files (including README, architecture/specification/data-contract docs and the latest `update.md`); inspect `pubspec.yaml`, current implementation, Git status and recent history; locate and inspect the UI PDF stored in the project files/repository. Render/inspect every PDF page and its embedded screens, not just extracted text. Use the proposal and UI PDF as the source of truth for scope and visual design. If the PDF or required docs cannot be found/read, state that clearly and pause any UI-dependent assumptions.
• Reuse established architecture, dependencies, naming, theme, data models and interfaces. Do not overwrite another member's work or shared files without coordination. Do not add credentials/secrets to Git.
• Implement the assigned scope end-to-end, including UI, state, backend integration, validation, loading/empty/error states and accessibility. Avoid placeholder/mock behavior in real workflows unless explicitly labelled as demo data.
• QA is mandatory on every run: format code; run static analysis; run relevant automated tests; build/launch the app on an available target; exercise the assigned feature and key failure paths; fix every reproducible bug in scope and rerun checks. If a device, Firebase project, emulator, credentials or external service is unavailable, run all remaining checks and record the exact environmental blocker—never claim success falsely.
• At the end of every run, create/update repository-root `update.md`. Append a dated entry with actual completed tasks, files/modules changed, remaining tasks/blockers, exact commands and outcomes, and current date/time in `Asia/Colombo` with UTC offset. Obtain the timestamp from the system clock at execution time; do not invent or reuse an old timestamp.
• Before committing, inspect `git diff` and `git status`; stage only the changes belonging to this task. Make a descriptive Git commit. Push the current working branch if a remote and valid authentication are configured. Never force-push, rewrite shared history, commit unrelated files, or claim a push/commit/test succeeded unless verified. If GitHub access is unavailable, leave a clean local commit if possible and report the exact blocker.
• Final response must summarize implementation, tests actually run and results, update.md entry, commit hash/branch, push status and remaining blockers. Do not say “all bugs fixed” unless checks support that claim.

You are Member 8 and own AquaTrace's notification and report-history module. Before coding, read all relevant repository *.md files including README, architecture, data contracts, Firebase setup and `update.md`; inspect routes, auth model, report status schema, existing messaging dependencies and Git status. Locate and inspect the AquaTrace UI PDF. Study citizen notifications, mark-all-read, technician/admin alerts and the report activity timeline. Do not assume a PDF path or invent UI behavior.

Implement notification list UI with unread/read states, mark-one-read and mark-all-read, timestamps and navigation to the related report/job. Integrate Firebase Cloud Messaging for supported foreground/background notification flows, permission request and token lifecycle. Implement notification records and report activity history using the agreed Firestore model. Required event types include report approved/verified, technician assigned, repair status updated and dispute opened. Ensure notifications are generated by trusted workflow events (Cloud Functions/server-side triggers where configured); do not rely only on a client sending itself a notification. If server-side deployment is outside this repo/environment, implement/document the client contract and exact backend trigger requirements instead of claiming end-to-end push works.

Run formatter, analyzer, tests and app launch/build. Test permission denial, token registration, read/unread, deep links and history ordering. Fix every reproducible bug. Update root `update.md` with completed tasks, remaining backend setup, exact test results and actual current `Asia/Colombo` date/time with UTC offset. Inspect diff/status, commit only your module changes and push if configured. Report commit hash and blockers.
```

## Prompt 8B — Notification event integration

```text
MANDATORY EXECUTION RULES — apply these in every prompt:
• Work in the existing AquaTrace repository; do not create a parallel app or replace the project wholesale.
• Preflight is mandatory: inspect the repository tree; read all relevant `*.md` files (including README, architecture/specification/data-contract docs and the latest `update.md`); inspect `pubspec.yaml`, current implementation, Git status and recent history; locate and inspect the UI PDF stored in the project files/repository. Render/inspect every PDF page and its embedded screens, not just extracted text. Use the proposal and UI PDF as the source of truth for scope and visual design. If the PDF or required docs cannot be found/read, state that clearly and pause any UI-dependent assumptions.
• Reuse established architecture, dependencies, naming, theme, data models and interfaces. Do not overwrite another member's work or shared files without coordination. Do not add credentials/secrets to Git.
• Implement the assigned scope end-to-end, including UI, state, backend integration, validation, loading/empty/error states and accessibility. Avoid placeholder/mock behavior in real workflows unless explicitly labelled as demo data.
• QA is mandatory on every run: format code; run static analysis; run relevant automated tests; build/launch the app on an available target; exercise the assigned feature and key failure paths; fix every reproducible bug in scope and rerun checks. If a device, Firebase project, emulator, credentials or external service is unavailable, run all remaining checks and record the exact environmental blocker—never claim success falsely.
• At the end of every run, create/update repository-root `update.md`. Append a dated entry with actual completed tasks, files/modules changed, remaining tasks/blockers, exact commands and outcomes, and current date/time in `Asia/Colombo` with UTC offset. Obtain the timestamp from the system clock at execution time; do not invent or reuse an old timestamp.
• Before committing, inspect `git diff` and `git status`; stage only the changes belonging to this task. Make a descriptive Git commit. Push the current working branch if a remote and valid authentication are configured. Never force-push, rewrite shared history, commit unrelated files, or claim a push/commit/test succeeded unless verified. If GitHub access is unavailable, leave a clean local commit if possible and report the exact blocker.
• Final response must summarize implementation, tests actually run and results, update.md entry, commit hash/branch, push status and remaining blockers. Do not say “all bugs fixed” unless checks support that claim.

Continue as Member 8. Before changing code, read all relevant repository *.md files and `update.md`; inspect notification/history implementation, report workflow event contracts, FCM setup, Firebase rules/functions and Git status. Re-inspect the AquaTrace UI PDF's notification list, notification examples and activity timeline.

Integrate notifications with the real workflow events from Members 3, 5, 6 and 7. Ensure each notification references the correct report/job and recipient UID; prevent duplicate notifications where feasible; order history chronologically; preserve immutable audit events; and handle deleted/invalid references gracefully. Implement token refresh/removal and user notification preferences. Verify that push payloads contain only necessary non-sensitive information and that navigation requires authentication/authorization. Add or document trusted Firebase Cloud Functions triggers if the repository includes that backend; otherwise provide precise event payload contracts and clearly state what remains to deploy. Do not fabricate delivery success.

Run formatter, analyzer, tests and app launch/build. Verify event-to-notification flow, read state, deep links and history. Fix all reproducible bugs. Update `update.md` with integration work, outstanding backend requirements, exact test results and actual `Asia/Colombo` timestamp with offset. Review diff/status, commit and push if configured. Report commit hash and blockers.
```

## Prompt 8C — Notifications/history regression and handoff

```text
MANDATORY EXECUTION RULES — apply these in every prompt:
• Work in the existing AquaTrace repository; do not create a parallel app or replace the project wholesale.
• Preflight is mandatory: inspect the repository tree; read all relevant `*.md` files (including README, architecture/specification/data-contract docs and the latest `update.md`); inspect `pubspec.yaml`, current implementation, Git status and recent history; locate and inspect the UI PDF stored in the project files/repository. Render/inspect every PDF page and its embedded screens, not just extracted text. Use the proposal and UI PDF as the source of truth for scope and visual design. If the PDF or required docs cannot be found/read, state that clearly and pause any UI-dependent assumptions.
• Reuse established architecture, dependencies, naming, theme, data models and interfaces. Do not overwrite another member's work or shared files without coordination. Do not add credentials/secrets to Git.
• Implement the assigned scope end-to-end, including UI, state, backend integration, validation, loading/empty/error states and accessibility. Avoid placeholder/mock behavior in real workflows unless explicitly labelled as demo data.
• QA is mandatory on every run: format code; run static analysis; run relevant automated tests; build/launch the app on an available target; exercise the assigned feature and key failure paths; fix every reproducible bug in scope and rerun checks. If a device, Firebase project, emulator, credentials or external service is unavailable, run all remaining checks and record the exact environmental blocker—never claim success falsely.
• At the end of every run, create/update repository-root `update.md`. Append a dated entry with actual completed tasks, files/modules changed, remaining tasks/blockers, exact commands and outcomes, and current date/time in `Asia/Colombo` with UTC offset. Obtain the timestamp from the system clock at execution time; do not invent or reuse an old timestamp.
• Before committing, inspect `git diff` and `git status`; stage only the changes belonging to this task. Make a descriptive Git commit. Push the current working branch if a remote and valid authentication are configured. Never force-push, rewrite shared history, commit unrelated files, or claim a push/commit/test succeeded unless verified. If GitHub access is unavailable, leave a clean local commit if possible and report the exact blocker.
• Final response must summarize implementation, tests actually run and results, update.md entry, commit hash/branch, push status and remaining blockers. Do not say “all bugs fixed” unless checks support that claim.

Act as Member 8 for final notifications and history QA. First read all relevant repository *.md files and `update.md`, inspect current implementation and Git status, and inspect notification/history screens in the AquaTrace UI PDF.

Test FCM permission granted/denied, token registration/refresh, foreground/background behavior where the environment supports it, notification list loading, read/unread, mark-all-read, related-item navigation and complete report timeline. Verify report submitted, admin verified, technician assigned, repair started/completed, community verified and dispute opened events appear in the correct order for the correct recipients. Check privacy, duplicate delivery, stale references, offline behavior and missing timestamps. Fix every reproducible bug and separate code issues from Firebase console/deployment blockers.

Run formatter, analyzer, tests and app launch/build. Update root `update.md` with final status, exact test outcomes, deployment requirements and actual `Asia/Colombo` timestamp with UTC offset. Review diff/status, commit and push if configured. Report commit hash and handoff notes.
```
