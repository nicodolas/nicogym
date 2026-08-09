# NicoGym

Mobile-first gym guidance for beginners: today's workout, exercise guidance, fast set logging, and explainable recovery suggestions.

## Workspace

- `apps/client`: Flutter Android + web client.
- `apps/api`: Hono API, Better Auth, Drizzle, and Neon PostgreSQL.
- `.omx/specs`: approved product and technical specification.

## Local verification

```powershell
npm install
npm run api:test
npm run api:typecheck

cd apps/client
C:\Users\Admin\Tools\flutter\bin\flutter.bat test
C:\Users\Admin\Tools\flutter\bin\flutter.bat analyze
C:\Users\Admin\Tools\flutter\bin\flutter.bat build web --release
C:\Users\Admin\Tools\flutter\bin\flutter.bat build apk --release
```

## Database

The API reads the pooled Neon connection from `DATABASE_URL`. Migrations require a separate direct connection in `DIRECT_URL`; do not run migrations through the `-pooler` endpoint.

```powershell
npm run db:generate --workspace @nicogym/api
npm run db:migrate --workspace @nicogym/api
```

Before migrating, rotate any credential that has been shared outside the local `.env`, create a least-privilege runtime role, and put the new direct migration URL in `.env`.

## Android release and OTA

- Base APKs use `major.minor.patch+build` and are signed with the same private keystore forever.
- Git tags such as `v1.0.0+1` run the release workflow and attach `nicogym-android.apk` plus its SHA-256 digest.
- The web build gets a link to the latest GitHub Release asset through `APK_DOWNLOAD_URL`.
- Shorebird patches are bound to an exact base release and are promoted through `beta` before `stable`.
- Native/plugin/Flutter-engine or asset changes require a new base APK, not an OTA patch.

GitHub repository secrets required for release:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `SHOREBIRD_TOKEN`

Run `shorebird init` inside `apps/client` once after signing in, then commit the generated `shorebird.yaml` (it contains an app identifier, not a publishing secret).

