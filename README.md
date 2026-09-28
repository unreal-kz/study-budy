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

## Checks

```sh
flutter analyze
flutter test
cd server && uv run pytest
```
