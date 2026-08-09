# NicoGym

NicoGym is a mobile-first workout planner for beginners who do not always know what to train, which machine to use, or how long a muscle group should recover.

**Web preview:** [nicodolasgym.netlify.app](https://nicodolasgym.netlify.app/)

The project prioritizes a simple daily flow: show the scheduled workout, explain why a change may be useful, require confirmation before changing the plan, and make sets quick to record.

> **Project status:** early MVP. The current build demonstrates the Today experience, workout logging UI, authentication screens, and the rule-based recommendation foundation. Scheduling, exercise media, progress history, and full client-to-API workout synchronization are still being developed.

## Features

- Mobile-first Today screen with the planned muscle group and recovery status.
- Two explicit choices when a recommendation differs from the schedule: keep the original plan or confirm the suggested change.
- Fast set logging with weight, repetitions, and set count.
- Beginner-oriented exercise and equipment guidance foundation.
- Email/password registration and sign-in through Better Auth.
- Explainable, deterministic workout recommendation rules.
- Android APK distribution through GitHub Releases.
- Shorebird OTA patches for compatible Dart-only updates.
- Flutter web build with an APK download action.

## Tech stack

| Area | Technology |
| --- | --- |
| Android and web client | Flutter / Dart |
| API | Hono / TypeScript |
| Authentication | Better Auth |
| Database | Neon PostgreSQL |
| Schema and migrations | Drizzle ORM / Drizzle Kit |
| Validation | Zod |
| OTA updates | Shorebird |
| Automation | GitHub Actions |

## Repository structure

```text
nicogym/
├── apps/
│   ├── api/       # Hono API, authentication, recommendation rules and Drizzle schema
│   └── client/    # Flutter Android and web application
├── .github/
│   └── workflows/ # Verification, APK release and Shorebird patch workflows
└── .env.example   # Safe environment-variable template
```

## Requirements

- Node.js 24 or a compatible current LTS release.
- npm 11 or later.
- Flutter `3.44.9` stable.
- JDK 17 and an Android SDK for APK builds.
- A PostgreSQL database; Neon is the configured provider.
- Shorebird CLI for OTA releases and patches.

## Local setup

Clone the repository and install API dependencies:

```powershell
git clone https://github.com/nicodolas/nicogym.git
cd nicogym
npm install
```

Copy the environment template without committing the resulting file:

```powershell
Copy-Item .env.example .env
```

Configure these values in `.env`:

```dotenv
DATABASE_URL=postgresql://USER:PASSWORD@POOLED_HOST/DATABASE?sslmode=require
DIRECT_URL=postgresql://MIGRATION_USER:PASSWORD@DIRECT_HOST/DATABASE?sslmode=require
BETTER_AUTH_SECRET=replace-with-at-least-32-random-characters
BETTER_AUTH_URL=http://localhost:3000
ALLOWED_ORIGINS=http://localhost:8080
```

- `DATABASE_URL` is the pooled runtime connection.
- `DIRECT_URL` must be a non-pooled connection and is required for migrations.
- Generate `BETTER_AUTH_SECRET` locally and never reuse the example value.
- Separate multiple allowed origins with commas.

Run the API:

```powershell
npm run api:dev
```

Run the Flutter client in another terminal:

```powershell
cd apps/client
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

When testing on a physical phone, replace `localhost` with the development computer's LAN address and allow the port through the local firewall.

## Database migrations

Generate a migration after changing the Drizzle schema:

```powershell
npm run db:generate --workspace @nicogym/api
```

Apply migrations using the direct Neon connection:

```powershell
npm run db:migrate --workspace @nicogym/api
```

The migration command intentionally refuses to fall back to a pooled Neon URL.

## Quality checks

From the repository root:

```powershell
npm run api:test
npm run api:typecheck

cd apps/client
flutter analyze
flutter test
flutter build web --release
flutter build apk --release
```

## Android releases

The app uses versions in `major.minor.patch+build` format. A new native dependency, Flutter engine, Android configuration, or bundled asset requires a new base release and build number.

Tags matching `v*`, for example `v1.0.0+1`, trigger the APK workflow and publish:

- `nicogym-android.apk`
- `nicogym-android.apk.sha256`

Android signing credentials are stored only in GitHub Actions Secrets. Keystores and `key.properties` must never be committed.

## Shorebird OTA

Initialize Shorebird once from the Flutter project:

```powershell
cd apps/client
shorebird login
shorebird init
shorebird release android
```

The installed application must originate from a Shorebird base release to receive patches. An APK produced only by `flutter build apk` is not OTA-enabled.

Publish a compatible patch to beta first:

```powershell
shorebird patch android --release-version 1.0.0+1 --channel beta
```

After validation, publish to stable through the same command or the manual **Publish Shorebird OTA patch** GitHub workflow. OTA is intended for compatible Dart changes; native code, assets, plugins, and engine changes require a new base release.

For CI, create an API key in the [Shorebird Console](https://console.shorebird.dev) and save it as the `SHOREBIRD_TOKEN` repository secret. Do not put it in `.env` or source control.

## GitHub Actions secrets

The release workflows expect:

```text
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
SHOREBIRD_TOKEN
```

Repository secrets are configured under **Settings → Secrets and variables → Actions**.

## Security

- Never commit `.env`, database URLs, API keys, tokens, keystores, or signing passwords.
- Rotate any credential that has been pasted into chat, logs, screenshots, or issue reports.
- Use a least-privilege database role for the runtime API and reserve the direct owner connection for migrations.
- Report security issues privately to the repository owner instead of opening a public issue containing credentials.

## Roadmap

- Editable weekly workout schedules and recovery-frequency configuration.
- Exercise library with reviewed instructions, common mistakes, and video references.
- Persistent workout sessions and offline-friendly set logging.
- Progress history and explainable load/progression suggestions.
- Optional private friend messaging after the core workout experience is complete.

## Contributing

Issues and focused pull requests are welcome. Please run the API and Flutter quality checks before submitting a change, keep behavior changes covered by tests, and avoid committing generated build artifacts or secrets.

## License

No open-source license has been selected yet. The source is publicly visible, but reuse and redistribution rights are not granted until a license file is added.
