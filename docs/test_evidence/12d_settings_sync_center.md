# Sprint 12D Automated Test Evidence

## Scope

Sprint 12D reorganizes Settings and adds a unified five-module manual Sync
Center. Automated evidence does not close the manual product gates.

## Version Boundaries

| Boundary | Result |
|---|---|
| Sprint baseline | `a303dcbb11de05133844a380513bd1a3dd8e355e` |
| Flutter schemaVersion | 9, unchanged |
| API Version | 1, unchanged |
| Sync Protocol | 2, unchanged |
| PostgreSQL / Alembic | unchanged |
| Server runtime | unchanged |
| Automatic/background sync | not added |

## Local Evidence

| Check | Result |
|---|---|
| `flutter analyze --no-pub` | PASS, no issues |
| Sprint 12D targeted Flutter tests | PASS |
| `flutter pub get` | PASS |
| Full `flutter test` | PASS, 1027 passed / 2 skipped |
| Server pytest | PASS, 173 passed / 9 skipped |
| Windows release build | PASS |
| Windows startup smoke | PASS, process remained running and responsive |
| Android split release build | PASS, armeabi-v7a / arm64-v8a / x86_64 |

Targeted coverage includes:

- Settings top-level information architecture and hidden technical fields
- Account and Developer Options boundaries
- stable module IDs and immutable registry
- Journal two-entity grouping
- unified result aggregation
- deterministic sequential Sync All
- module failure/conflict continuation
- global failure short-circuit and skipped results
- Sync Center single-flight and transient rebuild semantics
- Profile two-way sync
- Profile generic conflict registration
- conflict module filters
- 320-1200px layouts and text scale 2.0
- presentation import privacy boundaries

## GitHub Evidence

| Check | Result |
|---|---|
| Implementation SHA | `7bbb9979c2dd0f416a1c7b5c2cf6f528df734a8d` |
| Quality run | [30475825477](https://github.com/wellinglan/Rebirth/actions/runs/30475825477), PASS |
| Flutter Analyze And Test | PASS |
| Android Debug Build | PASS |
| Server SQLite | PASS |
| Server PostgreSQL Multiprocess And Multiworker | PASS |
| Alembic upgrade | PASS |
| PostgreSQL marker | PASS |
| Multi-worker verification | PASS |
| Publish Alpha Images | NOT RUN |

`Publish Alpha Images` did not run because Sprint 12D changed neither
`server/**` nor the image publishing workflow.

The Android release build emitted the existing non-blocking CupertinoIcons
font-asset warning. All three APKs were produced successfully; Sprint 12D did
not change font dependencies.

## Manual Status

All rows in
`docs/manual_tests/39_settings_information_architecture_and_sync_center.md`
remain `NOT EXECUTED`.

- Settings Information Architecture Product Gate: OPEN
- Unified Sync Center Product Gate: OPEN
- Profile Unified Sync UX Gate: OPEN
- Account Boundary Isolation Gate: CLOSED / ACCEPTED
