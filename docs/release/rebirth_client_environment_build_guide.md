# Rebirth Client Environment Build Guide

Client environment is selected at compile time and cannot be changed by normal
runtime UI. Replace `<endpoint>` locally with the intended HTTP/HTTPS Server
origin. Never commit a private endpoint or credential.

## Production

```powershell
flutter build windows --release `
  --dart-define=REBIRTH_ENV=production `
  --dart-define=REBIRTH_ENABLE_DEV_LOGIN=false `
  --dart-define=REBIRTH_SERVER_ENDPOINT=<endpoint>

flutter build apk --split-per-abi --release `
  --dart-define=REBIRTH_ENV=production `
  --dart-define=REBIRTH_ENABLE_DEV_LOGIN=false `
  --dart-define=REBIRTH_SERVER_ENDPOINT=<endpoint>
```

Production requires `REBIRTH_SERVER_ENDPOINT`. It always disables Developer
Login, even if a conflicting true value is supplied. The UI shows public login
and registration without an Alpha badge, endpoint, or developer route.

## Alpha

```powershell
flutter build windows --release `
  --dart-define=REBIRTH_ENV=alpha `
  --dart-define=REBIRTH_ENABLE_DEV_LOGIN=true `
  --dart-define=REBIRTH_SERVER_ENDPOINT=<endpoint>

flutter build apk --split-per-abi --release `
  --dart-define=REBIRTH_ENV=alpha `
  --dart-define=REBIRTH_ENABLE_DEV_LOGIN=true `
  --dart-define=REBIRTH_SERVER_ENDPOINT=<endpoint>
```

Alpha keeps public login and registration as the primary entry. It additionally
shows the Alpha badge and low-priority Developer Login link.

## Development And CI

Local development may use the loopback default:

```powershell
flutter run -d windows `
  --dart-define=REBIRTH_ENV=development `
  --dart-define=REBIRTH_ENABLE_DEV_LOGIN=true `
  --dart-define=REBIRTH_SERVER_ENDPOINT=http://127.0.0.1:8000
```

GitHub Quality declares the development environment explicitly for its Android
debug build. Tests inject `AppConfig.test()` where environment behavior matters
and never contact Alpha.

## Artifact Separation

Build Alpha and Production artifacts in separate verification steps. Record the
environment with each result and do not infer it from a reused output filename.
The Android arm64 release file remains:

`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

Rebuilding another environment overwrites that path, so archive or rename
verified artifacts outside Git before starting the next build. APKs and Windows
build output must not be committed.
