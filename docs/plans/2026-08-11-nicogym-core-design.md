# NicoGym Core Completion Design

## Understanding summary

NicoGym is a mobile-first personal gym planner for beginners who do not know what to train today or how to perform an exercise safely. The product must keep a planned schedule as the primary source of truth, offer an explainable alternative when recovery or history suggests a change, and require confirmation before replacing today's workout. Web remains a polished companion and APK download surface; Android is the priority and uses Shorebird without Expo.

This delivery is split into two independently reviewable releases:

1. A reliable `v1.1.1+5` base APK and web hotfix: production API wiring, self-hosted font behavior, stale-cache prevention, and a minimal version footer.
2. The core product: persistent roles, exercise catalog administration, bulk JSON import, complete workout catalog, schedule/history/recovery data, deterministic daily suggestions, contextual help, and refined mobile/web UX.

## Assumptions and constraints

- Initial scale is below 1,000 users and should remain viable on Neon, Vercel, Netlify, GitHub Actions, and Shorebird free tiers.
- PostgreSQL/Neon remains the system of record. Better Auth remains the identity provider.
- Recommendations are deterministic and explainable; no AI dependency is required for the MVP.
- The client may cache exercise data and recent planning state for cold starts and intermittent connectivity.
- Admin access is derived only from a persisted database role, never an email allow-list, environment claim, or client-side flag.
- Exercise images initially use arbitrary HTTPS URLs. The server never fetches these URLs; the client shows a safe fallback on failure. This is an explicit MVP privacy and availability tradeoff.
- Exercise slugs are immutable identities and remain reserved after archival.
- OTA patches may change Dart code but do not redefine the installed base APK version. The UI therefore shows the requested compact base label only: `v1.1.1+5`.

## Approaches considered

### A. Local-only catalog and planner

This is fast and offline-friendly, but cannot support consistent admin imports, shared web/mobile data, persisted roles, or multi-device planning. Rejected because it conflicts with the core product.

### B. AI-first recommendation and generated exercise content

This appears flexible but adds cost, latency, unpredictable output, safety concerns, and weak explainability for a beginner. Rejected for the MVP; curated data plus deterministic rules is safer and cheaper.

### C. Server-backed catalog and deterministic planner with client cache

Chosen. Neon stores canonical users, roles, exercises, schedule, history, preferences, and audit events. The API owns authorization, validation, imports, and recommendation decisions. Flutter uses the same endpoints on Android and web and caches read models for resilience.

## Architecture

### Release and runtime configuration

- GitHub release workflow validates `API_BASE_URL` and a base version before invoking Shorebird.
- Shorebird receives the production API URL through `--dart-define`; a release must fail instead of silently producing a localhost APK.
- The Flutter build reads the public API URL and base display version from compile-time values.
- Netlify builds Flutter web with the production API URL, local web resources, no generated PWA service worker, and no-cache headers on boot artifacts.
- Font assets required by the app ship with the client. CSP remains restrictive and does not depend on `fonts.gstatic.com`.

### Authentication and authorization

- Better Auth owns credentials and sessions.
- `profiles` stores application role (`user` or `admin`) keyed by immutable auth user ID.
- Every admin mutation resolves the server session and reads the persisted role in the same trusted backend.
- A local, one-purpose admin grant command uses `DIRECT_URL`, targets exactly one existing email, is idempotent, and writes an audit event. It never contains or accepts a password.

### Exercise catalog and import

- Canonical exercise records contain immutable slug, localized name, body region, primary and secondary muscles, equipment, difficulty, instructions, cues, common mistakes, media URLs, default set/rep guidance, schema version, timestamps, and archive status.
- Both bundled fallback JSON and database records use the same slugs and schema version.
- Admin form supports individual create/edit/archive.
- Bulk JSON uses preview then apply. Preview validates the entire document and returns a short-lived token bound to normalized content and catalog revision. Apply rejects stale previews.
- Limits: 512 KB body, 100 exercises, bounded strings/arrays, duplicate slug rejection, explicit create/update mode, optimistic `updatedAt`, and all-or-nothing transaction.

### Planner and recommendation

- Users define weekly planned sessions and per-muscle recovery preferences.
- Completed sessions and sets form the actual history; missed sessions do not silently shift the plan.
- The request includes the user's local date and UTC offset; the backend remembers the latest offset.
- The scheduled workout is always evaluated first.
- With no history, the UI states that defaults are being used and does not imply measured recovery.
- If scheduled muscles are recovered, recommend keeping the schedule.
- Otherwise offer one fully recovered alternative ranked by longest rest and then stable slug.
- The response includes plain reasons: time rested, time remaining, missed-session context, and whether the schedule remains unchanged.
- The user explicitly chooses “Giữ lịch hôm nay” or “Đổi sang …”; changing updates today's effective session only after confirmation.

### Contextual help and UX

- A small `?` action is available on planning, recommendation, exercise detail, logging, and admin screens.
- Help content is centralized but screen-specific, answering “what am I seeing?” and “what should I do next?” in one or two short sentences.
- Exercise details include media, target muscles, steps, safety cues, common mistakes, sets/reps, and an embedded YouTube player when an approved video ID exists.
- False drag affordances are removed unless reordering is implemented.
- Mobile uses large touch targets, bottom sheets, concise copy, and single-column flows; web expands cards and panels without creating separate behavior.

## Error handling and safety

- Authentication errors map to actionable Vietnamese messages without leaking server details.
- API contracts use stable error codes and field-level validation errors.
- Admin imports never partially apply and report item index plus field path.
- Remote images and video thumbnails degrade to local placeholders.
- Network failures keep cached catalog/planning data visible and clearly mark actions that need reconnection.
- Recommendation output never presents defaults as medical assessment and includes a general training-safety disclaimer.

## Verification strategy

- Unit tests cover config validation, role authorization, import limits/transactions/concurrency, catalog mapping, and every recommendation branch.
- API integration tests cover user/admin boundaries and authenticated planner flows.
- Flutter widget tests cover version footer, error messages, help sheets, catalog/detail interactions, import preview, and schedule-change confirmation.
- Static analysis, API typecheck, API test suite, Flutter analyze, Flutter tests, and production web build must pass.
- Release workflow configuration is checked so production APKs cannot target localhost.
- Visual checks cover narrow Android-like viewport and desktop web viewport before PR review.

## Decision log

- Accepted: persisted database role is the sole admin authority; an environment email allow-list was rejected as unsafe.
- Accepted: the footer is deliberately the base APK label, not a claim about Shorebird patch state.
- Accepted: immutable slugs and schema versions prevent bundled/database identity drift.
- Accepted: preview tokens, revision checks, optimistic timestamps, and transactions prevent partial or stale imports.
- Accepted with documented risk: external HTTPS images are permitted without server-side fetching for the MVP.
- Accepted: recommendation copy distinguishes recovery defaults from observed history and explains missed sessions.
- Accepted: warm-path latency targets are aspirational; cached UI handles free-tier cold starts.
- Accepted: contextual help remains concise and centralized to reduce stale duplicate content.

