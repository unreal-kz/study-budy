# Study Budy

A Flutter mobile app (Android, iOS, Web). Scaffold stage — concept and feature spec to follow.

## Stack

- Flutter 3.47.5 (stable channel), Dart 3.13.4
- Targets: Android, iOS, Web
- `applicationId` / iOS bundle ID prefix: `kz.unreal.*` (placeholder, may change before store release)

## Getting started

### Backend (required for AI Buddy)

```sh
cd server
cp .env.example .env   # then fill in your real OPENROUTER_API_KEY
uv run uvicorn app.main:app --reload --port 8000
```

### App

```sh
flutter pub get
flutter run -d chrome --dart-define=BACKEND_BASE_URL=http://localhost:8000   # web
flutter run --dart-define=BACKEND_BASE_URL=http://localhost:8000            # any connected/simulated device
```

On Android, `localhost` refers to the device itself, not your host machine — use `http://10.0.2.2:8000` for the emulator, or your host's LAN IP for a physical device.

Every screen except AI Buddy works fully offline (seeded/local data). AI Buddy needs the backend above running.

#### Protecting a public deployment

By default `/buddy/chat` has no auth and CORS allows any `localhost`/`127.0.0.1` origin — fine for local dev. Before exposing the backend publicly, set `APP_TOKEN` and `ALLOWED_ORIGINS` in `server/.env` (see `server/.env.example`), then build the app with the matching token:

```sh
flutter run -d chrome --dart-define=BACKEND_BASE_URL=https://your-host --dart-define=APP_TOKEN=your-shared-token
```

`APP_TOKEN` is not a real secret (it ships inside the built app) — it only stops random traffic from burning the OpenRouter daily quota.

### Deploy (Render)

The backend deploys from `render.yaml` (Blueprint) on the free web service tier — see `docs/adr/0001-backend-hosting.md` for why. Auto-deploy runs on every push to `main` that passes CI (`autoDeployTrigger: checksPass`).

Prod URL: `https://study-buddy-server-pudn.onrender.com` (verified: `/health` public, `/buddy/chat` requires `X-App-Token`).

First-time setup (Render dashboard, not repo-tracked): New → Blueprint → connect the `unreal-kz/study-budy` GitHub repo. Render prompts for `OPENROUTER_API_KEY` and `APP_TOKEN` at that point (`sync: false` in `render.yaml`) — after the initial Blueprint creation, Render no longer prompts for new `sync: false` values, so rotating either one means editing it directly in the service's Environment tab.

Rotating `APP_TOKEN` also requires rebuilding the Flutter app with the new `--dart-define=APP_TOKEN=...` (see ST-30) — the old token stops working the moment the env var changes.

Prod also sets `REQUIRE_APP_TOKEN=1` (`render.yaml`), so a startup with `APP_TOKEN` unset or blank fails the deploy instead of silently reopening `/buddy/chat` with no auth (ST-37); local dev leaves it unset and keeps the fail-open default.

Free tier spins down after 15 min idle; the first request after that takes 30-60s (cold start).

### iOS beta (TestFlight)

Bundle ID `kz.unreal.studybuddy`, distributed to testers as TestFlight internal builds (no Beta App Review). One-time setup, none of it repo-tracked:

- App Store Connect API key (role Admin) at `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`.
- `.env.appstore` in the repo root (gitignored) with `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_TEAM_ID`.
- `.app_token.txt` in the repo root (gitignored), the same value as `APP_TOKEN` on Render.
- The app record created by hand in App Store Connect (`POST /v1/apps` is not supported by the API); testers added as App Store Connect users with role Marketing, then to an internal TestFlight group.

```sh
scripts/ios_testflight.sh            # archive + export IPA to build/ios/testflight/ipa
scripts/ios_testflight.sh --upload   # ... and upload to App Store Connect
```

The build number is `git rev-list --count HEAD`, so it grows with every commit and never repeats. Builds expire in TestFlight after 90 days. Like the APK, the IPA carries `APP_TOKEN` (see above).

## Checks

```sh
flutter analyze
flutter test
cd server && uv run pytest
```
