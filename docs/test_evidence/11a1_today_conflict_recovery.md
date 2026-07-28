# Sprint 11A.1 Automated Safety Evidence

> Evidence type: automated; not manual acceptance
> Baseline: `86f0f3ce35e44582374ae1b4863bd2c5f965e7e6`
> Commit: `f4fccc725f12af831f098c3aa8e1defbd104e0ad`
> GitHub Quality Run: PASS,
> [`30345489973`](https://github.com/wellinglan/Rebirth/actions/runs/30345489973)

No test connects to the Alpha business PostgreSQL database. No User Key,
token, complete Endpoint, Today note body, raw payload, or database copy is
recorded.

| Internal invariant | Test location | Result |
|---|---|---|
| v7 to v8 preserves conflicts and adds remote identity | `app_database_migration_test.dart` | AUTOMATED PASS |
| soft delete preserves Health, OCC metadata, and tombstone | `today_repository_impl_test.dart` | AUTOMATED PASS |
| blank placeholder is not uploaded | `today_repository_impl_test.dart` | AUTOMATED PASS |
| conflict cannot be bypassed by direct delete | `today_repository_impl_test.dart` | AUTOMATED PASS |
| remote identity persists and survives reopen | `sync_conflict_repository_test.dart` | AUTOMATED PASS |
| hydration stores snapshot without local overwrite | `today_conflict_resolution_test.dart` | AUTOMATED PASS |
| same UUID keep-local uses OCC baseline and resolves | `today_conflict_resolution_test.dart` | AUTOMATED PASS |
| same-date adopt and keep converge identity and preserve Health | `today_conflict_resolution_test.dart` | AUTOMATED PASS |
| adopt remote tombstone preserves Health | `today_conflict_resolution_test.dart` | AUTOMATED PASS |
| registry has explicit Plan/Today handlers and no fallback | `sync_conflict_resolution_handlers_test.dart` | AUTOMATED PASS |
| Today uses full pull for hydration/adopt and push-only for keep | `today_sync_controller_test.dart` | AUTOMATED PASS |
| different conflict operations cannot overlap | `today_sync_controller_test.dart` | AUTOMATED PASS |
| Today UI dispatches Today handler without Plan wording | `sync_conflict_pages_test.dart` | AUTOMATED PASS |
| tested widths and TextScaler 2.0 have no overflow | `sync_conflict_pages_test.dart` | AUTOMATED PASS |
| malformed Goal reference rolls back Today apply | `today_sync_adapter_test.dart` | AUTOMATED PASS |
| scope and eligibility guards stop before cursor/network | `sync_coordinator_test.dart` | AUTOMATED PASS |
| failed apply does not advance cursor and page replays | `sync_coordinator_test.dart` | AUTOMATED PASS |
| PostgreSQL marker, Alembic, and multi-worker | GitHub Quality | AUTOMATED PASS |

## Local Verification

Executed on 2026-07-28:

| Check | Result |
|---|---|
| `flutter analyze` | PASS, no issues |
| `flutter test` | PASS, `937 passed / 2 skipped` |
| Server `pytest` | PASS, `154 passed / 9 skipped` |
| Windows release build | PASS |
| Android split release build | PASS, armv7 + arm64 + x86_64 |
| Flutter schemaVersion | `8` |
| API / Sync Protocol | unchanged at `1 / 2` |
| PostgreSQL schema / Alembic | unchanged |

The Android build retains the existing non-blocking CupertinoIcons asset
warning. GitHub Quality passed Flutter, Android Debug, Server SQLite, and
Server PostgreSQL/Alembic/multi-worker jobs. The Actions Node.js 20 deprecation
annotation is non-blocking.
`AUTOMATED PASS` does not change the manual 33 matrix.
