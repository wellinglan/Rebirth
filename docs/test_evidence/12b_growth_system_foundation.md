# Sprint 12B Automated Safety Evidence

> Evidence type: automated; not manual acceptance
> Baseline: `5b832d492b00be5508e080f134ad79cf94300411`
> Implementation commit: `dc92b39b686f9298243146febc04d89465083e87`
> CI-only test fix: `e7bd65124e65b94626f761ea1bd7362261c0db12`
> GitHub Quality: AUTOMATED PASS
> Quality Run: `30439158262`
> Run URL: https://github.com/wellinglan/Rebirth/actions/runs/30439158262

No test connects to the Alpha business PostgreSQL database. No User Key,
token, complete Endpoint, Journal body, Health note/metric, raw payload, or
database copy is recorded.

## Automated Invariants

| Internal invariant | Evidence | Result |
|---|---|---|
| Growth uses Personal Data Aggregation instead of business repositories or Drift | `growth_repository_impl_test.dart` | AUTOMATED PASS |
| Registry rejects duplicate IDs and supports future capabilities | `growth_aggregator_test.dart` | AUTOMATED PASS |
| Projection Engine isolates contributor failure | `growth_aggregator_test.dart` | AUTOMATED PASS |
| Unknown future dimensions render without UI branching | `growth_projection_overview_test.dart` | AUTOMATED PASS |
| Provider failure preserves healthy dimensions | `growth_repository_impl_test.dart` | AUTOMATED PASS |
| Null and explicit zero remain distinct | `growth_repository_impl_test.dart` | AUTOMATED PASS |
| Reflection emits missing, draft, and completed semantics | Growth and Personal Data provider tests | AUTOMATED PASS |
| Journal draft and complete persist content and state atomically | `journal_repository_impl_test.dart` | AUTOMATED PASS |
| Reopen preserves content and sync version metadata | `journal_repository_impl_test.dart` | AUTOMATED PASS |
| Journal controller completes the draft/completed/reopen lifecycle | `journal_today_controller_test.dart` | AUTOMATED PASS |
| Journal UI preserves edits, confirms reopen, and blocks empty content | `journal_page_test.dart` | AUTOMATED PASS |
| Existing Journal payload and sync path preserve typed status | `journal_sync_adapter_test.dart` | AUTOMATED PASS |
| Growth UI remains responsive and accessible | Growth presentation tests | AUTOMATED PASS |
| Account-scoped Personal Data providers remain isolated | Personal Data provider tests | AUTOMATED PASS |
| No Growth persistence and schemaVersion remains 8 | architecture tests | AUTOMATED PASS |

## Local Verification

Executed on 2026-07-29:

| Check | Result |
|---|---|
| Sprint 12B targeted tests | PASS, `198 passed` |
| `flutter analyze` | PASS, no issues |
| `flutter test` | PASS, `1015 passed / 2 skipped` |
| Server `pytest` | PASS, `167 passed / 9 skipped` |
| Windows release build | PASS |
| Windows release startup smoke | PASS, process remained alive for 8 seconds |
| Android split release build | PASS, armv7 + arm64 + x86_64 |
| Flutter schemaVersion | `8` |
| API / Sync Protocol | unchanged at `1 / 2` |
| PostgreSQL schema / Alembic | unchanged |
| Server runtime | unchanged |

## GitHub Quality Verification

Quality Run `30439158262` completed successfully for
`e7bd65124e65b94626f761ea1bd7362261c0db12`:

| Job or required step | Result |
|---|---|
| Flutter Analyze And Test | AUTOMATED PASS |
| `flutter analyze` step | AUTOMATED PASS |
| `flutter test` step | AUTOMATED PASS |
| Android Debug Build | AUTOMATED PASS |
| Server SQLite | AUTOMATED PASS |
| Server PostgreSQL Multiprocess And Multiworker | AUTOMATED PASS |
| Alembic upgrade | AUTOMATED PASS |
| PostgreSQL marker tests | AUTOMATED PASS |
| Multi-worker verification with 2 workers | AUTOMATED PASS |

The first implementation run, `30438605754`, exposed a test-only timezone
assumption in the deterministic Growth clock fixture. The follow-up commit
uses an explicit UTC fixture. No production date, Growth, or aggregation
semantics changed.

Publish Alpha Images is `NOT RUN` because Sprint 12B changes no Server runtime
or image workflow.

This automated evidence remains distinct from manual acceptance. On
2026-07-29, the user reported 71 manual checks as `PASS` with no anomaly. The
six partial-availability checks remain honestly recorded as `NOT EXECUTED`
because no safe product-level Provider or Contributor fault injection is
available. See `docs/manual_tests/37_growth_system_foundation.md`.

The Android release build retains the existing non-blocking CupertinoIcons
asset warning.
