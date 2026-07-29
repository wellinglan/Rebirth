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
| Implementation SHA | PENDING |
| GitHub Quality Run | PENDING |
| Publish Alpha Images Run | PENDING |
| API image tag | PENDING |
| API image digest | PENDING |

No Alpha server deployment is part of Sprint 12C.

## Manual Status

All items in `docs/manual_tests/38_journal_prompt_system.md` remain
`NOT EXECUTED`. The three Journal Prompt gates remain open.
