# Sprint 12D Settings and Sync Center Manual Acceptance

Automated tests never become manual PASS. Every row starts as
`NOT EXECUTED`.

Test both the Windows release build and the Android arm64 release APK with a
real Alpha account only when the release artifacts are ready.

## A. Settings Top Level

| ID | Check | Status |
|---|---|---|
| A1 | Open Settings | NOT EXECUTED |
| A2 | Top-level structure is clear | NOT EXECUTED |
| A3 | Account section is understandable | NOT EXECUTED |
| A4 | Data & Sync entry is visible | NOT EXECUTED |
| A5 | Personal Data & Privacy entries are visible | NOT EXECUTED |
| A6 | Journal prompt management is visible | FAIL |
| A7 | Advanced Settings placement is reasonable | NOT EXECUTED |
| A8 | Endpoint is not shown | NOT EXECUTED |
| A9 | Device ID is not shown | NOT EXECUTED |
| A10 | User Key is not shown | NOT EXECUTED |
| A11 | Upload Profile is not shown | NOT EXECUTED |
| A12 | Pull Profile is not shown | NOT EXECUTED |
| A13 | WeChat placeholder is absent | NOT EXECUTED |
| A14 | Sync-settings placeholder is absent | NOT EXECUTED |

## B. Developer Options

| ID | Check | Status |
|---|---|---|
| B1 | Development build can enter Developer Options | NOT EXECUTED |
| B2 | Non-development configuration hides the entry | NOT EXECUTED |
| B3 | Development User Key login works | NOT EXECUTED |
| B4 | Server Endpoint can be edited | NOT EXECUTED |
| B5 | Default Endpoint can be restored | NOT EXECUTED |
| B6 | Backend connection check is explicit | NOT EXECUTED |
| B7 | Opening the page does not check the network | NOT EXECUTED |
| B8 | Endpoint switch requires confirmation | NOT EXECUTED |
| B9 | Endpoint switch logs out | NOT EXECUTED |
| B10 | Local data remains after switching | NOT EXECUTED |
| B11 | Tokens are not displayed | NOT EXECUTED |
| B12 | Journal and Health private content is not displayed | NOT EXECUTED |

## C. Profile Unified Sync

| ID | Check | Status |
|---|---|---|
| C1 | Only Sync Profile is shown | NOT EXECUTED |
| C2 | Upload Profile is absent | NOT EXECUTED |
| C3 | Pull Profile is absent | NOT EXECUTED |
| C4 | Local Profile change uploads | NOT EXECUTED |
| C5 | Remote Profile change pulls | NOT EXECUTED |
| C6 | No-change result is accurate | NOT EXECUTED |
| C7 | Conflict enters Pending Issues | NOT EXECUTED |
| C8 | Keep Local converges | NOT EXECUTED |
| C9 | Adopt Remote converges | NOT EXECUTED |

## D. Independent Module Sync

| ID | Check | Status |
|---|---|---|
| D1 | Profile sync | NOT EXECUTED |
| D2 | Plan sync | NOT EXECUTED |
| D3 | Today sync | NOT EXECUTED |
| D4 | Journal sync | NOT EXECUTED |
| D5 | Health sync | NOT EXECUTED |
| D6 | Each module state is accurate | NOT EXECUTED |
| D7 | Upload count is accurate | NOT EXECUTED |
| D8 | Pull count is accurate | NOT EXECUTED |
| D9 | Delete count is accurate | NOT EXECUTED |
| D10 | Conflict count is accurate | NOT EXECUTED |
| D11 | Failed-item wording is accurate | FAIL |
| D12 | Journal exposes no sixth technical module | NOT EXECUTED |

## E. Sync All Order

| ID | Check | Status |
|---|---|---|
| E1 | Profile runs first | NOT EXECUTED |
| E2 | Plan runs second | NOT EXECUTED |
| E3 | Today runs third | NOT EXECUTED |
| E4 | Journal runs fourth | NOT EXECUTED |
| E5 | Health runs fifth | NOT EXECUTED |
| E6 | Journal configuration precedes entry | NOT EXECUTED |
| E7 | Current module is visible | NOT EXECUTED |
| E8 | Progress moves from 0/5 to 5/5 | NOT EXECUTED |
| E9 | Modules do not run concurrently | NOT EXECUTED |
| E10 | Repeated taps do not duplicate sync | NOT EXECUTED |
| E11 | Final aggregate is accurate | NOT EXECUTED |

## F. Partial Success

| ID | Check | Status |
|---|---|---|
| F1 | Safely create a single-module failure | NOT EXECUTED |
| F2 | Later modules continue | NOT EXECUTED |
| F3 | Earlier successful results remain | NOT EXECUTED |
| F4 | Conflict does not block later modules | NOT EXECUTED |
| F5 | Partial state is clear | NOT EXECUTED |
| F6 | Local data is not lost | NOT EXECUTED |
| F7 | Failed module can be retried independently | FAIL |
| F8 | Conflict is not resolved automatically | NOT EXECUTED |

Leave fault-injection rows `NOT EXECUTED` when no safe product operation exists.

## G. Global Failure

| ID | Check | Status |
|---|---|---|
| G1 | Offline behavior | NOT EXECUTED |
| G2 | Endpoint unavailable behavior | NOT EXECUTED |
| G3 | Signed-out behavior | NOT EXECUTED |
| G4 | Device-not-ready behavior | NOT EXECUTED |
| G5 | Account scope mismatch behavior | NOT EXECUTED |
| G6 | Later modules show Not Executed | NOT EXECUTED |
| G7 | One prerequisite error is not repeated five times | NOT EXECUTED |
| G8 | Local data remains | NOT EXECUTED |
| G9 | Manual retry succeeds after recovery | NOT EXECUTED |

## H. Pending Issues

| ID | Check | Status |
|---|---|---|
| H1 | All filter | NOT EXECUTED |
| H2 | Profile filter | NOT EXECUTED |
| H3 | Plan filter | NOT EXECUTED |
| H4 | Today filter | NOT EXECUTED |
| H5 | Journal filter | NOT EXECUTED |
| H6 | Health filter | NOT EXECUTED |
| H7 | Journal configuration conflict is grouped into Journal | NOT EXECUTED |
| H8 | Journal entry conflict is grouped into Journal | NOT EXECUTED |
| H9 | Count refreshes after resolution | FAIL |
| H10 | List leaks no body text or UUID | NOT EXECUTED |

## I. Account Boundary

| ID | Check | Status |
|---|---|---|
| I1 | Account A state is correct | NOT EXECUTED |
| I2 | Account A conflict is visible only to A | NOT EXECUTED |
| I3 | Logout succeeds | NOT EXECUTED |
| I4 | Account B does not see A state | NOT EXECUTED |
| I5 | Account B has independent state | NOT EXECUTED |
| I6 | Re-login A restores canonical state | NOT EXECUTED |
| I7 | Authenticated-offline can inspect local state | NOT EXECUTED |
| I8 | Authenticated-offline loses no data | NOT EXECUTED |
| I9 | Binding-required cannot sync | NOT EXECUTED |
| I10 | Session-rejected shows no prior account state | NOT EXECUTED |

## J. UI and Accessibility

| ID | Check | Status |
|---|---|---|
| J1 | Windows release | NOT EXECUTED |
| J2 | Android arm64 release | NOT EXECUTED |
| J3 | 320px width | NOT EXECUTED |
| J4 | 360px width | NOT EXECUTED |
| J5 | 412px width | NOT EXECUTED |
| J6 | Maximum font size | NOT EXECUTED |
| J7 | Windows narrow window | NOT EXECUTED |
| J8 | Windows wide window | NOT EXECUTED |
| J9 | Tab | NOT EXECUTED |
| J10 | Shift+Tab | NOT EXECUTED |
| J11 | Enter | NOT EXECUTED |
| J12 | Space | NOT EXECUTED |
| J13 | Android Back | NOT EXECUTED |
| J14 | Pages scroll | NOT EXECUTED |
| J15 | No overflow | NOT EXECUTED |
| J16 | No crash | NOT EXECUTED |
| J17 | Status is not color-only | NOT EXECUTED |
| J18 | Primary actions remain reachable | NOT EXECUTED |

## Summary

| Result | Count |
|---|---:|
| PASS | 0 |
| FAIL | 4 |
| NOT EXECUTED | 109 |

## Android Conflict Recovery Blocker

Observed on 2026-07-30 after creating concurrent Today, Journal, and Health
updates on two devices:

- Health exposed both explicit resolution actions and converged.
- Today remained at `awaiting remote snapshot`. Retrying reported that the
  conflict operation completed, but the remote snapshot and resolution actions
  did not appear and the conflict count did not change.
- Journal had a remote snapshot, but Continue Processing reported success
  without changing the state or conflict count.
- Local Today and Journal content remained intact.

The automated fix candidate:

- permits conflict-recovery full pulls to read a server version below a stale
  local cursor without moving that cursor backwards;
- applies the explicitly requested Today or Journal resolution while preserving
  other unresolved conflicts;
- no longer reports a non-throwing pull failure as a completed operation.

The Android arm64 release candidate must be installed over the existing app.
Retest the existing Today and Journal conflicts without clearing app data.
Keep D11, F7, and H9 as `FAIL` until both records converge and the conflict
count decreases.

## Journal Secondary Regression

Observed on 2026-07-30 while the Android Journal conflict remained unresolved:

- Reopen reported a generic retry-later failure.
- Delete reported that the local record was unchanged.
- Both operations were correctly blocked by the repository because the Journal
  still had `syncStatus = conflict`, but the UI did not explain the required
  recovery action.
- On both tested devices, Settings > Manage Reflection Questions opened only
  the Journal shell branch. The title and bottom navigation remained visible,
  while the page body was blank and the prompt-management page never rendered.

The follow-up fix candidate:

- keeps conflicted Journal mutation protection unchanged and replaces the
  generic reopen/delete error with guidance to resolve the conflict in Sync
  Center first;
- moves `/journal/prompts` out of the stateful Journal shell branch so Settings
  and Journal can both open it as a standalone page;
- exposes prompt-configuration conflict status instead of labeling it synced;
- includes the sync failure reason and phase in unsuccessful conflict-action
  messages so remaining server or apply failures can be identified without
  exposing private content.

Install the next Android arm64 release candidate over the existing app without
clearing data. Confirm that Manage Reflection Questions renders, Back returns
normally, and conflicted Journal reopen/delete show the Sync Center guidance.
Then retry the existing Today and Journal conflicts and record the exact
parenthesized failure reason and phase if either operation still fails.

The first follow-up APK reported `applyFailed / apply` for both Today and
Journal. This confirms that authentication, transport, pull decoding, and the
server cursor completed, while the local apply transaction rolled back. It
does not yet distinguish a SQLite constraint failure from an unexpected local
state failure.

The next diagnostic candidate adds only a privacy-safe local failure
fingerprint to the existing message:

- `sqlite-<extended-code>` identifies the SQLite constraint family without
  exposing SQL, parameters, IDs, or record content;
- `state`, `format`, or `type` identifies a non-SQL local apply category;
- no token, payload, note, prompt answer, or database statement is displayed.

Keep D11, F7, H9, and A6 open until the existing records are retested. Do not
clear app data before capturing the new fingerprint.

The diagnostic APK produced the following existing-data results:

- Today Retry Cloud Version: `applyFailed / apply / state`;
- Journal Continue Processing: `applyFailed / apply`, without a diagnostic
  code.

The Today fingerprint identified a repository assumption that was not enforced
by the database: multiple active local conflicts can reference the same remote
record, while remote lookup previously required exactly one row. Historical
retries can therefore throw `StateError` before the requested conflict is
applied.

The follow-up candidate:

- selects duplicate remote matches deterministically, preferring an explicit
  Adopt Remote request, then an awaiting snapshot, then an unresolved conflict;
- preserves every non-selected conflict for later review;
- classifies conflict-not-found, conflict-not-ready, conflict-changed, and
  conflict-resolution failures without exposing record content;
- adds repository-level and Today/Journal adapter-level regression coverage for
  duplicate remote conflict identities;
- does not alter the conflict table, schema version, cursor rules, payloads, or
  date semantics.

Install the follow-up Android arm64 release over the existing app without
clearing data. Retry Today first and then Journal. A successful result must
render the remote snapshot or resolve the requested record, reduce or correctly
preserve the remaining conflict count, and keep unrelated local conflicts
intact. If Journal still fails, record all three message components; the third
component should now identify the exact conflict-domain state.

The follow-up APK was installed over the existing app, but both records still
failed on 2026-07-30:

- Today Retry Cloud Version remained
  `applyFailed / apply / state`;
- Journal Continue Processing remained `applyFailed / apply`, with the cloud
  snapshot still visible and local content preserved.

This showed that remote-ID duplicate selection was not the Today exception
site. The existing record first uses local-record conflict lookup, which still
required exactly one row. It also showed that a Journal entry conflict action
was unnecessarily running both Journal entry and prompt-configuration sync, so
an unrelated prompt-configuration apply failure could block the entry action.

The next release candidate:

- applies deterministic selection to both local-record and remote-record
  conflict lookups, including legacy duplicate rows;
- runs Journal entry and prompt-configuration conflict actions independently;
- unwraps Drift database exceptions before classification;
- adds a privacy-safe source fingerprint such as
  `state@today_sync_adapter-321` for state and otherwise-unclassified failures;
- includes regression tests for legacy duplicate local conflicts, wrapped
  apply failures, and Journal prompt/entry action isolation.

Again install over the existing app without clearing data. The old Today and
Journal records are the required acceptance fixtures and must be retained until
both converge or the new source fingerprint is captured.

The retained Android fixtures then produced these more precise fingerprints:

- Today Retry Cloud Version:
  `applyFailed / apply / state@today_sync_adapter-927`;
- Journal Continue Processing:
  `applyFailed / apply / other-driftremoteexception`.

The Today source location identifies the placeholder eligibility query. A
historical Today can have more than one linked soft-deleted Health row, while
the query incorrectly required zero or one row merely to determine whether any
row existed.

The Journal failure is caused by same-date prompt snapshot identity. Two
devices can create different Journal entry IDs for the same date while deriving
the same prompt item IDs from that date and prompt configuration. During Adopt
Remote, the losing local Journal was soft-deleted but retained those child
rows, so inserting the remote Journal prompt snapshots violated their primary
keys inside the Drift background isolate.

The next release candidate:

- limits the Today linked-Health lookup to one row because it is an existence
  check, preserving all Health rows and local Health semantics;
- removes prompt snapshots only from the losing local Journal after an explicit
  Adopt Remote request and before inserting the different remote Journal ID;
- leaves other Journal entries, other users, prompt configuration, cursors, and
  server records unchanged;
- unwraps `DriftRemoteException` so any remaining background-isolate failure
  reports its actual privacy-safe category;
- adds regression tests for multiple historical Health links and colliding
  same-date Journal prompt snapshot IDs.

Install the new arm64 release over the existing Android app without clearing
data. Retry Today Retry Cloud Version and Journal Continue Processing. Both
actions must complete, disappear from the active conflict list, and preserve
the chosen content after app restart. Also confirm that Health content and
unrelated Journal entries remain unchanged.

## Gates

- Settings Information Architecture Product Gate:
  `OPEN / MANUAL ACCEPTANCE REQUIRED`
- Unified Sync Center Product Gate:
  `OPEN / MANUAL ACCEPTANCE REQUIRED`
- Profile Unified Sync UX Gate:
  `OPEN / MANUAL ACCEPTANCE REQUIRED`
- Account Boundary Isolation Gate:
  `CLOSED / ACCEPTED`
