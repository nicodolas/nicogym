# NicoGym Core Completion Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ship a reliable `v1.1.1+5` Android/web base and complete NicoGym's admin-managed exercise catalog, schedule-first recommendation flow, and beginner-friendly guidance.

**Architecture:** Keep Better Auth and Neon as the trusted backend, add persisted application roles and catalog/planner data behind Hono endpoints, and consume those endpoints from a cached Flutter client shared by Android and web. Release configuration is fail-closed so no production APK can point at localhost.

**Tech Stack:** Flutter/Dart, Hono/TypeScript, Better Auth, Drizzle/PostgreSQL/Neon, Vitest, Netlify, Vercel, GitHub Actions, Shorebird.

---

## Delivery structure

- PR A: release reliability and `v1.1.1+5` hotfix.
- PR B: stacked core-feature PR based on PR A until PR A is merged, then retargeted to `main`.
- Each PR follows `.codex/skills/pr-review-loop/SKILL.md`: current-head CI, current-head Cubic review, recorded dispositions, and at most three remediation rounds. Neither PR is auto-merged.

## Task 1: Lock release configuration behavior

**Files:**
- Create: `scripts/validate-release-config.mjs`
- Create: `apps/api/test/release-config.test.ts`
- Modify: `.github/workflows/ci-release.yml`
- Modify: `.github/workflows/ota-patch.yml`

1. Write failing tests for rejecting empty, localhost, non-HTTPS, and malformed production API URLs and for accepting the deployed HTTPS API.
2. Run `npm test -- --run test/release-config.test.ts` in `apps/api` and confirm failure.
3. Implement the reusable validation script and make both release workflows validate inputs before Shorebird.
4. Pass `API_BASE_URL` and base version as Dart defines to the release; keep patches targeted at an explicit existing release.
5. Re-run the focused test and inspect workflow YAML.
6. Commit with a Lore-format message.

## Task 2: Ship the compact base-version footer

**Files:**
- Modify: `apps/client/pubspec.yaml`
- Modify: `apps/client/lib/app.dart`
- Modify: relevant shared shell/footer widget under `apps/client/lib/`
- Create/modify: corresponding widget test under `apps/client/test/`

1. Write a widget test asserting the exact visible text `v1.1.1+5` and no OTA status/control.
2. Run the focused Flutter test and confirm failure.
3. Set `version: 1.1.1+5`, inject a compile-time base label, and render it once in the shared footer/account surface.
4. Run the focused test, `flutter analyze`, and existing navigation tests.
5. Commit with a Lore-format message.

## Task 3: Remove web font and stale-bootstrap failures

**Files:**
- Modify: `apps/client/pubspec.yaml`
- Add: licensed font files under `apps/client/assets/fonts/`
- Modify: app theme under `apps/client/lib/`
- Modify: `scripts/netlify-build.sh`
- Modify: `netlify.toml`
- Modify: `apps/client/web/index.html`
- Create/modify: release/web config tests under `apps/api/test/`

1. Add failing assertions that the web build disables generated PWA caching and boot assets receive no-cache headers.
2. Bundle the required Noto Sans family with its license and configure Flutter to use it locally.
3. Build with `--pwa-strategy=none` and remove obsolete service-worker registration/caches safely at startup.
4. Keep CSP restrictive; allow only resources actually required by catalog media.
5. Run tests and `flutter build web --release --no-web-resources-cdn` with production defines.
6. Commit and open PR A; run CI/Cubic review loop before proceeding to the stacked feature branch.

## Task 4: Add persisted roles and audited admin grant

**Files:**
- Modify: `apps/api/src/db/schema.ts`
- Add: Drizzle migration under `apps/api/drizzle/`
- Modify: session/auth context in `apps/api/src/production-app.ts`
- Add: admin authorization module under `apps/api/src/admin/`
- Add: `apps/api/scripts/grant-admin.ts`
- Add: API tests under `apps/api/test/`

1. Write failing tests for default user role, admin-only mutation, spoofed client role rejection, idempotent exact-email grant, and audit creation.
2. Add `profiles.role` enum/default and admin audit table/indexes.
3. Resolve role from the authenticated user ID on the server for each protected request.
4. Implement the `DIRECT_URL`-only grant command with zero/multiple/mismatch hard failures and no password handling.
5. Run focused tests, typecheck, and migration validation.
6. Commit with migration notes.

## Task 5: Build the canonical exercise catalog API

**Files:**
- Modify: `apps/api/src/db/schema.ts`
- Add: Drizzle migration
- Add: `apps/api/src/catalog/` domain/schema/repository modules
- Modify: `apps/api/src/app.ts`
- Add: catalog/import API tests
- Modify: `apps/client/assets/data/exercises.vi.json`

1. Write failing tests for public authenticated listing/detail, immutable reserved slug, archive behavior, bounded validation, and user/admin boundaries.
2. Define the canonical exercise schema and align bundled fallback JSON by slug/schema version.
3. Implement authenticated read endpoints and admin create/update/archive endpoints.
4. Add cursor/conditional metadata suitable for client caching.
5. Run focused tests and typecheck.
6. Commit.

## Task 6: Implement transactional JSON preview/apply

**Files:**
- Add: `apps/api/src/catalog/import-service.ts`
- Add/modify: catalog routes
- Add: import tests

1. Write failing tests for 512 KB/100-item limits, duplicate slugs, explicit modes, validation paths, stale catalog revision, stale `updatedAt`, replayed/expired preview tokens, and all-or-nothing rollback.
2. Implement normalized preview output and signed short-lived preview tokens.
3. Implement revision-checked transactional apply without fetching remote media.
4. Record audit events for applied imports.
5. Run focused tests, full API tests, and typecheck.
6. Commit.

## Task 7: Persist schedule, completion history, and recovery preferences

**Files:**
- Modify: database schema/migration as needed
- Add/modify: planner domain and repository modules
- Modify: `apps/api/src/app.ts` and `production-app.ts`
- Add: planner integration tests

1. Write failing tests for weekly schedule CRUD, stable exercise slugs, idempotent completion IDs, per-muscle recovery settings, request-scoped local date/IANA time zone, travel/DST boundaries, and missed-session behavior.
2. Implement repositories and authenticated endpoints.
3. Preserve schedule entries when a day is missed; atomically upsert keep/change decisions under a unique `(profile_id, local_date)` key and make concurrent/retried confirmations idempotent.
4. Run focused and full API verification.
5. Commit.

## Task 8: Complete the deterministic recommendation engine

**Files:**
- Modify: `apps/api/src/domain/recommend-workout.ts`
- Modify/add: recommendation route/service
- Expand: `apps/api/test/recommend-workout.test.ts`

1. Add failing cases for no history/default disclosure, ready scheduled workout, unrecovered scheduled workout, no alternative, stable tie-breaking, rest/remaining-hour reasons, multi-device travel, IANA-zone DST boundaries, concurrent confirmation, and successful-commit retries.
2. Implement schedule-first evaluation and one fully recovered alternative.
3. Return explicit keep/change actions and explanation fields; never shift the future schedule.
4. Run focused property/edge tests and full API suite.
5. Commit.

## Task 9: Add client catalog, details, media, and resilient cache

**Files:**
- Modify/add: `apps/client/lib/workouts/`
- Add: catalog API/cache repository
- Modify: exercise list/detail widgets
- Add: local placeholders/assets
- Add/modify: Flutter tests

1. Write failing repository and widget tests for database data, bundled fallback, slug identity, per-user cache ownership, logout/session-expiry/account-switch invalidation, loading/error/offline states, image fallback, instructional sections, and desktop clicks.
2. Implement cache-first catalog sync and full logged-in body-region list.
3. Build responsive exercise detail with muscle illustration/image, instructions, cues, mistakes, and inline approved YouTube embed with an accessible external fallback.
4. Verify Android-sized and desktop viewports and run visual-verdict.
5. Commit.

## Task 10: Build admin exercise management and import UX

**Files:**
- Add: `apps/client/lib/admin/`
- Modify: authenticated navigation/routing
- Add: admin widget/repository tests

1. Write failing tests for hidden user navigation, server-enforced unauthorized errors, form validation, JSON preview, itemized errors, apply confirmation, stale preview recovery, and archive action.
2. Implement role-aware navigation while treating the API as authoritative.
3. Implement friendly single-exercise form and bulk JSON preview/apply flow.
4. Add help content and responsive layouts.
5. Run focused tests, analyze, and visual-verdict.
6. Commit.

## Task 11: Build schedule-first Today experience

**Files:**
- Modify/add: `apps/client/lib/member/`
- Modify: planner API/cache models
- Add: planner/recommendation widget tests

1. Write failing tests for schedule editing, recovery preference editing, today's scheduled card, default-data disclosure, explanation copy, keep action, confirmed change action, and missed-session message.
2. Implement weekly scheduling and history-backed Today recommendation.
3. Require a confirmation sheet before applying an alternative.
4. Remove nonfunctional drag affordances and provide correct touch/click behavior.
5. Verify mobile and web layouts with visual-verdict.
6. Commit.

## Task 12: Add contextual help and complete release verification

**Files:**
- Add: centralized help registry/widget under `apps/client/lib/help/`
- Modify: planner, recommendation, exercise, logging, and admin screens
- Add: help widget tests
- Modify: README/deployment documentation

1. Write failing tests that every core screen exposes a semantic `?` action and correct concise content.
2. Implement reusable contextual bottom sheet/dialog behavior.
3. Document database migration, admin grant, Netlify/Vercel variables, Shorebird base release, OTA patch rules, and public-repo secret hygiene.
4. Apply additive Neon migrations using a non-pooled `DIRECT_URL`; verify schema and health endpoints without printing credentials.
5. Run API typecheck/tests, Flutter analyze/tests, production web build, APK/Shorebird dry validation where supported, and secret scan.
6. Open/update PR B and complete current-head CI/Cubic review loop. Record all AI review dispositions and leave the PR open.
