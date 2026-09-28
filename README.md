# Study Budy

A Flutter mobile app (Android, iOS, Web). Scaffold stage — concept and feature spec to follow.

## Stack

- Flutter 3.47.5 (stable channel), Dart 3.13.4
- Targets: Android, iOS, Web
- `applicationId` / iOS bundle ID prefix: `kz.unreal.*` (placeholder, may change before store release)

## Getting started

```sh
flutter pub get
flutter run -d chrome      # web
flutter run -d macos       # or any connected/simulated device
```

## Checks

```sh
flutter analyze
flutter test
flutter build web
flutter build apk --debug
flutter build ios --simulator --debug
```
