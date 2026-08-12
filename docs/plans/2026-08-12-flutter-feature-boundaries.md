# Flutter Feature Boundaries Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Split the oversized Flutter application file into focused feature modules without changing user-visible behavior.

**Architecture:** Keep `NicoGymApp` and Today composition in `app.dart` while moving shared theme constants, account/header navigation, and workout detail UI behind explicit widgets and callbacks. Preserve the current repository interfaces and navigation behavior; this PR must not change API contracts, database schema, dependencies, or release version.

**Tech Stack:** Flutter 3.44.9, Dart, flutter_test, existing `http`, `flutter_secure_storage`, `url_launcher`, and `youtube_player_iframe` packages.

---

### Task 1: Lock current component behavior

**Files:**
- Modify: `apps/client/test/today_screen_test.dart`
- Create: `apps/client/test/account_header_test.dart`
- Create: `apps/client/test/workout_screen_test.dart`

1. Extract account-state/navigation cases from the broad Today test into a focused header test.
2. Extract exercise guide, embedded-video fallback, and set-entry cases into a focused workout test.
3. Run the focused tests and confirm they pass before moving production code.
4. Commit only after the extracted tests pass.

### Task 2: Extract shared presentation tokens

**Files:**
- Create: `apps/client/lib/app/app_theme.dart`
- Modify: `apps/client/lib/app.dart`

1. Move the NicoGym color constants and `ThemeData` construction to `app_theme.dart`.
2. Keep the rendered typography, colors, spacing, and Material 3 configuration unchanged.
3. Run `flutter analyze` and the Today widget test.

### Task 3: Extract account and primary navigation header

**Files:**
- Create: `apps/client/lib/features/account/account_status_screen.dart`
- Create: `apps/client/lib/features/today/today_header.dart`
- Modify: `apps/client/lib/app.dart`
- Test: `apps/client/test/account_header_test.dart`

1. Move the signed-in status page without changing text or logout semantics.
2. Move header token-state coordination and account/member navigation into `TodayHeader`.
3. Pass callbacks or existing repositories explicitly; do not create a service locator or global mutable state.
4. Verify persisted sessions, delayed reads, throwing storage, logout, and Member Hub entry.

### Task 4: Extract workout detail feature

**Files:**
- Create: `apps/client/lib/features/workout/workout_screen.dart`
- Modify: `apps/client/lib/app.dart`
- Test: `apps/client/test/workout_screen_test.dart`

1. Move `WorkoutScreen` and its private guide/set widgets into the workout feature module.
2. Preserve image fallback, YouTube privacy-enhanced embedding, external source links, validation, and local set-entry behavior.
3. Keep the public `WorkoutScreen(exercise:)` constructor stable for current callers.
4. Run focused workout tests.

### Task 5: Verify the behavior-preserving refactor

**Files:**
- Review: all files changed in Tasks 1–4

1. Run `dart format` on changed Dart files.
2. Run `flutter analyze`; expect no issues.
3. Run `flutter test`; expect all tests to pass.
4. Run the production Flutter web build with the pinned public dart-defines.
5. Run `git diff --check` and review the diff for dependencies, secrets, generated artifacts, and accidental UI changes.
6. Commit with the repository Lore trailers and deliver through the PR review loop.

### Out of scope

- Workout-session persistence, planner schema changes, recommendations, progress history, new dependencies, version bumps, and visual redesign.
- These belong to A2 after the feature boundaries are stable.
