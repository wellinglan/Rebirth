# Legacy Sync Re-entry Remediation

> Sprint: 10B.3.1
> Baseline: `52e60b33febb1bc2e94cafbae50927b4cefd4292`
> Status: implemented; automated verification passed; manual gate partially accepted
> API: 1
> Sync Protocol: 2
> Flutter schema: 7

## Sprint Contract

This blocker-only Sprint fixes two defects discovered by the 10B.3 manual
matrix:

1. `PROFILE-LEGACY-REENTRY-CONFLICT-001`: an existing Profile conflict could
   survive pull and retry without a visible, durable recovery action.
2. `LEGACY-OWNERSHIP-STALE-EVIDENCE-001`: a legitimate second device could be
   rejected after another device advanced the same Goal on the same account.

The Sprint does not add automatic sync, field-level merge, a new sync domain,
authentication behavior, database tables, migrations, API versions, or
protocol versions. It does not clear local or Server data.

## Ownership Evidence

The client now prefers synced Goal evidence. Profile evidence is used only
when there is no synced Goal because the canonical Profile record ID is shared
by every account and is not a stable cross-account identity proof.

The Server still derives identity only from the authenticated JWT. For Goal
evidence:

- exact metadata under the current account is verified;
- the same Goal UUID under the current account at a newer server version is
  verified as legitimate stale same-owner evidence;
- the same Goal UUID under another account is rejected;
- future versions and same-version fingerprint mismatches are rejected.

For Profile-only evidence:

- exact current-account metadata is verified;
- exact metadata owned by another account is rejected;
- stale current-account metadata is unknown because the Server stores only
  the latest Profile state and the canonical `profile` ID is not unique across
  accounts.

The request and response wire contract are unchanged. No Profile or Goal
business payload is uploaded by ownership verification.

## Profile Conflict Recovery

Profile conflict status is read from the local Profile row and exposed after
restart. Settings shows:

- `保留本地 Profile`;
- `采用云端 Profile`.

Each action requires a confirmation dialog and explicitly states which side
will be replaced. There is no silent last-write-wins behavior.

### Adopt Cloud

After confirmation, the client performs a Profile-only pull from server
version `0`, independent of the incremental cursor. The local Profile is
replaced only after the response is decoded and validated. A successful local
transaction then advances the existing Profile cursor.

### Keep Local

After confirmation, the client performs the same bounded full Profile pull to
obtain the current remote optimistic-concurrency version while retaining all
local business fields. It then submits the local Profile through the normal
push path with that current version. Server acknowledgement clears the
conflict.

If no current remote Profile can be confirmed, the conflict remains. Network,
payload, apply, or push failure preserves local content and leaves the action
retryable.

## Cursor And Safety Rules

- Full pull is available only to the two explicit Profile conflict modes.
- Conflict modes reject push and two-way Coordinator runs.
- The stored cursor is not cleared before recovery.
- The cursor advances only after remote apply succeeds.
- Verification never changes cursor, conflict, tombstone, or business data.
- Today, Journal, Health, Growth, and AI remain outside synchronization.
- Plan conflict behavior and hierarchy semantics are unchanged.

## Database And Deployment

Flutter `schemaVersion` remains `7`. PostgreSQL models and Alembic revisions
are unchanged. API remains `1`; Sync Protocol remains `2`.

Because Server ownership verification changed, deployment requires the new API
image but must reuse the existing PostgreSQL container and volume. Do not
delete Alpha data to validate this remediation.

## Release Gate

Automated tests prove state transitions and preservation, but do not prove the
existing Alpha account history. The available Windows, Android, cross-device,
restart, and network-failure scenarios in
`docs/manual_tests/30_legacy_sync_reentry_remediation.md` produced
`27 PASS / 0 FAIL / 7 NOT EXECUTED`.

The two reported remediation defects passed in every exercised scenario.
The gate remains open because there was no independent legacy local space or
spare installation for account B rejection checks, and one database-internal
preservation audit was not manually observable. Automated coverage for those
paths remains green but is not counted as manual PASS.

## Local Verification

Executed on 2026-07-28:

| Check | Result |
|---|---|
| Flutter analyzer | PASS, no issues |
| Flutter tests | PASS, `897 passed / 2 skipped` |
| Server tests | PASS, `148 passed / 9 skipped` |
| Ownership verification tests | PASS, `9 passed` |
| Windows release build | PASS |
| Windows release startup smoke | PASS |
| Android split release build | PASS, armv7 + arm64 + x86_64 |
| Flutter schemaVersion | unchanged at `7` |
| PostgreSQL schema and Alembic | unchanged |
| Manual remediation matrix | PARTIAL, `27 PASS / 0 FAIL / 7 NOT EXECUTED` |
| Deployed API image | PASS, exact commit tag deployed with existing PostgreSQL volume |
| GitHub Quality | PASS, run `30327537109` |
| Alpha image publication | PASS, run `30327537091` |

Android build retains the existing non-blocking CupertinoIcons asset warning.
The published API digest is
`sha256:ae6eb94068de34e1c6ea323dcf0666cfe11ea3f4260e476d4cea9f3f78284b00`.
