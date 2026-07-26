# Manual Test: Legacy Local Data Ownership Resolution

> Sprint: 10B.2-B
> Initial status: all rows are `NOT EXECUTED`
> Flutter schema: 6
> Environment: Development + Fake Provider + Tailscale private Alpha

This matrix verifies explicit ownership resolution and sync quarantine.
Automated tests do not replace it. Never record Development User Keys, tokens,
complete Endpoint or identity values, Journal/Goal text, health values, AI
report content, raw JSON, or database copies as evidence.

## Preconditions

1. Use Windows and Android release clients from the same Sprint commit.
2. Confirm `/health` remains API `1`, Sync Protocol `2`.
3. Prepare disposable accounts A and B without recording their Keys.
4. Prepare a backed-up schema 5 database with one or more unbound Profiles,
   representative records, tombstones, sync versions, conflict history, and
   an AI pending row.
5. Record only build SHA, platform/version, test date, redacted Endpoint type,
   and PASS/FAIL evidence.

## A. Windows Legacy Claim

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Upgrade the schema 5 database without uninstalling or clearing data | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 2 | Login A enters `bindingRequired` and cannot open business routes | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 3 | Every unbound Profile has a stable anonymous summary | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 4 | Summary contains counts/flags but no private text or complete identifiers | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 5 | Cancel claim and verify no binding or active Profile changes | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 6 | Confirm one selected legacy space and enter its original local data | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 7 | Other unbound spaces remain inaccessible and unmodified | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 8 | Existing `serverVersion`, tombstones, and conflict history remain | NOT EXECUTED | - | PLAN-SYNC-CLOUD-SCOPE-TOMBSTONE-001 |
| 9 | Settings shows owned space and legacy sync review status | NOT EXECUTED | - | ACCOUNT-SYNC-REVIEW-001 |
| 10 | Profile and Plan manual sync controls are disabled | NOT EXECUTED | - | ACCOUNT-SYNC-REVIEW-001 |
| 11 | Restart restores the same claimed space without another binding | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 12 | Logout hides local data without deleting it | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 13 | Re-login A restores the same claimed space | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 14 | Login B cannot see or modify A's claimed data | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |

Windows legacy claim total: `0 PASS / 0 FAIL / 14 NOT EXECUTED`.

## B. Windows Fresh Space

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Login unbound B and choose create fresh space | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 2 | Cancel fresh confirmation and verify no new Profile | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 3 | Confirm fresh space and enter an empty local data space | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 4 | Legacy Profiles and records remain on disk but inaccessible to B | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 5 | No legacy record, sync version, conflict, or AI pending row is copied | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 6 | Settings reports manual sync eligibility ready | NOT EXECUTED | - | - |
| 7 | Explicit Profile and Plan manual sync remains usable | NOT EXECUTED | - | - |
| 8 | Repeated click/restart creates no duplicate Profile or binding | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 9 | B data does not appear under A | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 10 | Re-login A restores A's original space | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |

Windows fresh space total: `0 PASS / 0 FAIL / 10 NOT EXECUTED`.

## C. Android

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Upgrade and complete one legacy claim | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 2 | Complete one fresh-space flow | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 3 | Logout/re-login restores the correct space | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 4 | App restart during/after confirmation remains recoverable | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 5 | Multiple spaces can be scrolled and selected | NOT EXECUTED | - | - |
| 6 | Maximum font size keeps summaries and confirmations usable | NOT EXECUTED | - | - |
| 7 | Android Back cannot bypass Auth Gate or silently confirm | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 8 | Busy operations reject repeated taps | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 9 | Error preserves the page and allows retry | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 10 | No crash, horizontal overflow, or hidden primary action | NOT EXECUTED | - | - |

Android total: `0 PASS / 0 FAIL / 10 NOT EXECUTED`.

## D. Cross-device And Sync Quarantine

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Clean/fresh A can manually sync Plan between Windows and Android | NOT EXECUTED | - | - |
| 2 | Claimed legacy space cannot start Profile push or pull | NOT EXECUTED | - | ACCOUNT-SYNC-REVIEW-001 |
| 3 | Claimed legacy space cannot start Plan two-way sync | NOT EXECUTED | - | ACCOUNT-SYNC-REVIEW-001 |
| 4 | Quarantine leaves cursor and active conflict count unchanged | NOT EXECUTED | - | ACCOUNT-SYNC-REVIEW-001 |
| 5 | Account scope mismatch still produces no network request | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 6 | Account A and B remain isolated on both devices | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 7 | Same cloud user under a different Endpoint remains isolated | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 8 | Installation IDs remain device-specific | NOT EXECUTED | - | - |
| 9 | Same ready cloud account uses each device's local cache safely | NOT EXECUTED | - | - |
| 10 | Today, Journal, and Health have no new cloud sync | NOT EXECUTED | - | - |

Cross-device total: `0 PASS / 0 FAIL / 10 NOT EXECUTED`.

## E. Data Protection And Failure

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | No legacy Profile or Goal is deleted | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 2 | No `serverVersion`, `lastSyncedAt`, or `syncStatus` is reset | NOT EXECUTED | - | PLAN-SYNC-CLOUD-SCOPE-TOMBSTONE-001 |
| 3 | No SharedPreferences cursor is cleared or reassigned | NOT EXECUTED | - | ACCOUNT-SYNC-REVIEW-001 |
| 4 | Conflict rows and snapshots remain preserved | NOT EXECUTED | - | PLAN-SYNC-CLOUD-SCOPE-TOMBSTONE-001 |
| 5 | AI pending rows and AI Consent remain unchanged | NOT EXECUTED | - | - |
| 6 | Session/Endpoint change before confirmation is rejected | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 7 | Forced transaction failure leaves no partial binding or two active Profiles | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 8 | Multiple taps do not create duplicate Profile or binding | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |

Data protection total: `0 PASS / 0 FAIL / 8 NOT EXECUTED`.

## Final Gate

| Area | PASS | FAIL | NOT EXECUTED |
|---|---:|---:|---:|
| Windows legacy claim | 0 | 0 | 14 |
| Windows fresh space | 0 | 0 | 10 |
| Android | 0 | 0 | 10 |
| Cross-device | 0 | 0 | 10 |
| Data protection | 0 | 0 | 8 |
| **Total** | **0** | **0** | **52** |

Release Gate: `OPEN / NOT EXECUTED`.

Do not mark Sprint 10B.2-B manually accepted, enable legacy cloud sync, or
start Sprint 10C until all required rows pass or each failure has an approved
defect disposition.
