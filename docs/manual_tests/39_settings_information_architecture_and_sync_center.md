# Sprint 12D Settings and Sync Center Manual Acceptance

Automated tests never become manual PASS. The results below record the user's
completed Windows and Android acceptance on 2026-07-30.

Test both the Windows release build and the Android arm64 release APK with a
real Alpha account only when the release artifacts are ready.

## A. Settings Top Level

| ID | Check | Status | Evidence |
|---|---|---|---|
| A1 | Open Settings | PASS | User acceptance, 2026-07-30 |
| A2 | Top-level structure is clear | PASS | User acceptance, 2026-07-30 |
| A3 | Account section is understandable | PASS | User acceptance, 2026-07-30 |
| A4 | Data & Sync entry is visible | PASS | User acceptance, 2026-07-30 |
| A5 | Personal Data & Privacy entries are visible | PASS | User acceptance, 2026-07-30 |
| A6 | Journal prompt management is visible | PASS | User acceptance, 2026-07-30 |
| A7 | Advanced Settings placement is reasonable | PASS | User acceptance, 2026-07-30 |
| A8 | Endpoint is not shown | PASS | User acceptance, 2026-07-30 |
| A9 | Device ID is not shown | PASS | User acceptance, 2026-07-30 |
| A10 | User Key is not shown | PASS | User acceptance, 2026-07-30 |
| A11 | Upload Profile is not shown | PASS | User acceptance, 2026-07-30 |
| A12 | Pull Profile is not shown | PASS | User acceptance, 2026-07-30 |
| A13 | WeChat placeholder is absent | PASS | User acceptance, 2026-07-30 |
| A14 | Sync-settings placeholder is absent | PASS | User acceptance, 2026-07-30 |

## B. Developer Options

| ID | Check | Status | Evidence |
|---|---|---|---|
| B1 | Development build can enter Developer Options | PASS | User acceptance, 2026-07-30 |
| B2 | Non-development configuration hides the entry | PASS | User acceptance, 2026-07-30 |
| B3 | Development User Key login works | PASS | User acceptance, 2026-07-30 |
| B4 | Server Endpoint can be edited | PASS | User acceptance, 2026-07-30 |
| B5 | Default Endpoint can be restored | PASS | User acceptance, 2026-07-30 |
| B6 | Backend connection check is explicit | PASS | User acceptance, 2026-07-30 |
| B7 | Opening the page does not check the network | PASS | User acceptance, 2026-07-30 |
| B8 | Endpoint switch requires confirmation | PASS | User acceptance, 2026-07-30 |
| B9 | Endpoint switch logs out | PASS | User acceptance, 2026-07-30 |
| B10 | Local data remains after switching | PASS | User acceptance, 2026-07-30 |
| B11 | Tokens are not displayed | PASS | User acceptance, 2026-07-30 |
| B12 | Journal and Health private content is not displayed | PASS | User acceptance, 2026-07-30 |

## C. Profile Unified Sync

| ID | Check | Status | Evidence |
|---|---|---|---|
| C1 | Only Sync Profile is shown | PASS | Cross-device acceptance, 2026-07-30 |
| C2 | Upload Profile is absent | PASS | Cross-device acceptance, 2026-07-30 |
| C3 | Pull Profile is absent | PASS | Cross-device acceptance, 2026-07-30 |
| C4 | Local Profile change uploads | PASS | Cross-device acceptance, 2026-07-30 |
| C5 | Remote Profile change pulls | PASS | Cross-device acceptance, 2026-07-30 |
| C6 | No-change result is accurate | PASS | Cross-device acceptance, 2026-07-30 |
| C7 | Conflict enters Pending Issues | PASS | Cross-device acceptance, 2026-07-30 |
| C8 | Keep Local converges | PASS | Cross-device acceptance, 2026-07-30 |
| C9 | Adopt Remote converges | PASS | Cross-device acceptance, 2026-07-30 |

## D. Independent Module Sync

| ID | Check | Status | Evidence |
|---|---|---|---|
| D1 | Profile sync | PASS | Cross-device acceptance, 2026-07-30 |
| D2 | Plan sync | PASS | Cross-device acceptance, 2026-07-30 |
| D3 | Today sync | PASS | Cross-device acceptance, 2026-07-30 |
| D4 | Journal sync | PASS | Cross-device acceptance, 2026-07-30 |
| D5 | Health sync | PASS | Cross-device acceptance, 2026-07-30 |
| D6 | Each module state is accurate | PASS | Cross-device acceptance, 2026-07-30 |
| D7 | Upload count is accurate | PASS | Cross-device acceptance, 2026-07-30 |
| D8 | Pull count is accurate | PASS | Cross-device acceptance, 2026-07-30 |
| D9 | Delete count is accurate | PASS | Cross-device acceptance, 2026-07-30 |
| D10 | Conflict count is accurate | PASS | Cross-device acceptance, 2026-07-30 |
| D11 | Failed-item wording is accurate | PASS | Cross-device acceptance, 2026-07-30 |
| D12 | Journal exposes no sixth technical module | PASS | Cross-device acceptance, 2026-07-30 |

## E. Sync All Order

| ID | Check | Status | Evidence |
|---|---|---|---|
| E1 | Profile runs first | PASS | Cross-device acceptance, 2026-07-30 |
| E2 | Plan runs second | PASS | Cross-device acceptance, 2026-07-30 |
| E3 | Today runs third | PASS | Cross-device acceptance, 2026-07-30 |
| E4 | Journal runs fourth | PASS | Cross-device acceptance, 2026-07-30 |
| E5 | Health runs fifth | PASS | Cross-device acceptance, 2026-07-30 |
| E6 | Journal configuration precedes entry | PASS | Cross-device acceptance, 2026-07-30 |
| E7 | Current module is visible | PASS | Cross-device acceptance, 2026-07-30 |
| E8 | Progress moves from 0/5 to 5/5 | PASS | Cross-device acceptance, 2026-07-30 |
| E9 | Modules do not run concurrently | PASS | Cross-device acceptance, 2026-07-30 |
| E10 | Repeated taps do not duplicate sync | PASS | Cross-device acceptance, 2026-07-30 |
| E11 | Final aggregate is accurate | PASS | Cross-device acceptance, 2026-07-30 |

## F. Partial Success

| ID | Check | Status | Evidence |
|---|---|---|---|
| F1 | Safely create a single-module failure | PASS | Cross-device acceptance, 2026-07-30 |
| F2 | Later modules continue | PASS | Cross-device acceptance, 2026-07-30 |
| F3 | Earlier successful results remain | PASS | Cross-device acceptance, 2026-07-30 |
| F4 | Conflict does not block later modules | PASS | Cross-device acceptance, 2026-07-30 |
| F5 | Partial state is clear | PASS | Cross-device acceptance, 2026-07-30 |
| F6 | Local data is not lost | PASS | Cross-device acceptance, 2026-07-30 |
| F7 | Failed module can be retried independently | PASS | Cross-device acceptance, 2026-07-30 |
| F8 | Conflict is not resolved automatically | PASS | Cross-device acceptance, 2026-07-30 |

Fault-injection rows may remain `NOT EXECUTED` when no safe product operation
exists. For this acceptance, the user completed all rows through safe product
conditions.

## G. Global Failure

| ID | Check | Status | Evidence |
|---|---|---|---|
| G1 | Offline behavior | PASS | User acceptance, 2026-07-30 |
| G2 | Endpoint unavailable behavior | PASS | User acceptance, 2026-07-30 |
| G3 | Signed-out behavior | PASS | User acceptance, 2026-07-30 |
| G4 | Device-not-ready behavior | PASS | User acceptance, 2026-07-30 |
| G5 | Account scope mismatch behavior | PASS | User acceptance, 2026-07-30 |
| G6 | Later modules show Not Executed | PASS | User acceptance, 2026-07-30 |
| G7 | One prerequisite error is not repeated five times | PASS | User acceptance, 2026-07-30 |
| G8 | Local data remains | PASS | User acceptance, 2026-07-30 |
| G9 | Manual retry succeeds after recovery | PASS | User acceptance, 2026-07-30 |

## H. Pending Issues

| ID | Check | Status | Evidence |
|---|---|---|---|
| H1 | All filter | PASS | Cross-device acceptance, 2026-07-30 |
| H2 | Profile filter | PASS | Cross-device acceptance, 2026-07-30 |
| H3 | Plan filter | PASS | Cross-device acceptance, 2026-07-30 |
| H4 | Today filter | PASS | Cross-device acceptance, 2026-07-30 |
| H5 | Journal filter | PASS | Cross-device acceptance, 2026-07-30 |
| H6 | Health filter | PASS | Cross-device acceptance, 2026-07-30 |
| H7 | Journal configuration conflict is grouped into Journal | PASS | Cross-device acceptance, 2026-07-30 |
| H8 | Journal entry conflict is grouped into Journal | PASS | Cross-device acceptance, 2026-07-30 |
| H9 | Count refreshes after resolution | PASS | Cross-device acceptance, 2026-07-30 |
| H10 | List leaks no body text or UUID | PASS | Cross-device acceptance, 2026-07-30 |

## I. Account Boundary

| ID | Check | Status | Evidence |
|---|---|---|---|
| I1 | Account A state is correct | PASS | Cross-device acceptance, 2026-07-30 |
| I2 | Account A conflict is visible only to A | PASS | Cross-device acceptance, 2026-07-30 |
| I3 | Logout succeeds | PASS | Cross-device acceptance, 2026-07-30 |
| I4 | Account B does not see A state | PASS | Cross-device acceptance, 2026-07-30 |
| I5 | Account B has independent state | PASS | Cross-device acceptance, 2026-07-30 |
| I6 | Re-login A restores canonical state | PASS | Cross-device acceptance, 2026-07-30 |
| I7 | Authenticated-offline can inspect local state | PASS | Cross-device acceptance, 2026-07-30 |
| I8 | Authenticated-offline loses no data | PASS | Cross-device acceptance, 2026-07-30 |
| I9 | Binding-required cannot sync | PASS | Cross-device acceptance, 2026-07-30 |
| I10 | Session-rejected shows no prior account state | PASS | Cross-device acceptance, 2026-07-30 |

## J. UI and Accessibility

| ID | Check | Status | Evidence |
|---|---|---|---|
| J1 | Windows release | PASS | User acceptance, 2026-07-30 |
| J2 | Android arm64 release | PASS | User acceptance, 2026-07-30 |
| J3 | 320px width | PASS | User acceptance, 2026-07-30 |
| J4 | 360px width | PASS | User acceptance, 2026-07-30 |
| J5 | 412px width | PASS | User acceptance, 2026-07-30 |
| J6 | Maximum font size | PASS | User acceptance, 2026-07-30 |
| J7 | Windows narrow window | PASS | User acceptance, 2026-07-30 |
| J8 | Windows wide window | PASS | User acceptance, 2026-07-30 |
| J9 | Tab | PASS | User acceptance, 2026-07-30 |
| J10 | Shift+Tab | PASS | User acceptance, 2026-07-30 |
| J11 | Enter | PASS | User acceptance, 2026-07-30 |
| J12 | Space | PASS | User acceptance, 2026-07-30 |
| J13 | Android Back | PASS | User acceptance, 2026-07-30 |
| J14 | Pages scroll | PASS | User acceptance, 2026-07-30 |
| J15 | No overflow | PASS | User acceptance, 2026-07-30 |
| J16 | No crash | PASS | User acceptance, 2026-07-30 |
| J17 | Status is not color-only | PASS | User acceptance, 2026-07-30 |
| J18 | Primary actions remain reachable | PASS | User acceptance, 2026-07-30 |

## Summary

| Result | Count |
|---|---:|
| PASS | 113 |
| FAIL | 0 |
| NOT EXECUTED | 0 |

## Historical Acceptance Investigation (RESOLVED)

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

At that investigation stage, the Android arm64 release candidate was installed
over the existing app and the existing Today and Journal conflicts were
retested without clearing app data. D11, F7, and H9 remained `FAIL` until both
records converged and the conflict count decreased.

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

The retained-data acceptance completed successfully after installing commit
`ba480f06d2b8266e75bf4a1e7bf8521fc0c39e4e` over the existing Android app:

- Today and Journal conflicts converged;
- Health and unrelated Journal data remained intact;
- the pending conflict count refreshed correctly;
- Journal prompt-management navigation rendered and returned normally;
- A6, D11, F7, and H9 passed their final retest.

This investigation is `RESOLVED`. The diagnostic history remains above as
evidence of the retained-data recovery process; it is not an open blocker.

## Gates

- Settings Information Architecture Product Gate:
  `CLOSED / ACCEPTED`
- Unified Sync Center Product Gate:
  `CLOSED / ACCEPTED`
- Profile Unified Sync UX Gate:
  `CLOSED / ACCEPTED`
- Account Boundary Isolation Gate:
  `CLOSED / ACCEPTED`
