# Sprint 12C Automated Test Evidence

> Automated evidence does not close manual product gates.
>
> Baseline: `5903266540da0e0ef89d49e8b8a85e82586f5c40`

## Scope

The automated suite covers schema 9 creation and migration, deterministic
legacy backfill, prompt catalog and repository behavior, snapshot persistence,
dynamic form binding, Apply Latest Prompts, payload v1/v2 compatibility,
configuration aggregate sync, OCC acknowledgement, account scope, privacy
regressions, and server validation.

Relative to the Sprint baseline, the suite adds 21 Flutter test declarations
(1 migration, 8 prompt repository/domain, 8 codec/adapter/conflict, and 4
widget/controller) plus 6 Server contract tests.

## Local Results

| Verification | Result |
|---|---|
| Flutter pub get | PASS |
| Flutter analyze | PASS, no issues |
| Flutter tests | PASS, 1036 passed / 2 skipped |
| Server pytest | PASS, 173 passed / 9 skipped |
| Windows release build | PASS |
| Windows startup smoke | PASS |
| Android split release build | PASS, 3 APKs |

The two skipped Server-independent Flutter tests retain their existing
environment-dependent status. The nine skipped Server tests retain their
existing PostgreSQL/environment markers.

The Android build emitted the existing CupertinoIcons asset warning while
successfully producing `armeabi-v7a`, `arm64-v8a`, and `x86_64` release APKs.
PostgreSQL marker, multi-worker, and Alembic evidence is delegated to GitHub
Quality and remains pending until the implementation commit runs in CI.

## GitHub Evidence

| Evidence | Result |
|---|---|
| Implementation SHA | `df0ca0dd94cfb6ec28425bba389cf7edbce363d6` |
| GitHub Quality Run | PASS, [30461654412](https://github.com/wellinglan/Rebirth/actions/runs/30461654412) |
| Publish Alpha Images Run | PASS, [30461654100](https://github.com/wellinglan/Rebirth/actions/runs/30461654100) |
| API image tags | full SHA, `df0ca0dd`, and `alpha-latest` |
| API image digest | `sha256:67205d50ce01af212635911ec17d83d1f2a71392fa955d8ac9ddf2c9956af7b0` |

Quality passed all four jobs:

- Flutter Analyze And Test;
- Android Debug Build;
- Server SQLite;
- Server PostgreSQL Multiprocess And Multiworker, including Alembic upgrade,
  PostgreSQL marker tests, and two-worker verification.

GitHub emitted only its Node.js 20 action deprecation annotation. It did not
change the successful result.

No Alpha server deployment is part of Sprint 12C.

## Manual Status

Manual acceptance remains distinct from the automated evidence above. On
2026-07-30, user acceptance passed all 93 checks in
`docs/manual_tests/38_journal_prompt_system.md` with no reported failure or
anomaly. The Journal Prompt System Product, Journal Migration, and Journal
Prompt Sync gates are `CLOSED / ACCEPTED`.
