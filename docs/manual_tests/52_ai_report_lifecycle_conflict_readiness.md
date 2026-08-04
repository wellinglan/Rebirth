# AI Report Lifecycle And Conflict Readiness Manual Acceptance

Status: PASS (25 PASS / 0 FAIL / 0 NOT EXECUTED).

Execution record: 2026-08-04 on Windows release and Android arm64-v8a release.
During C3 acceptance, the remote AI Report snapshot initially remained pending.
Commit `bbe96b4b1ea785630c072e863627ec9e3480b01d` repaired conflict snapshot
hydration. C3-C7 and the remaining regression checks were rerun against the
fixed client and passed.

Prerequisites:

1. Install the Sprint 14D Windows release and arm64-v8a Android release.
2. Sign in with the same Cloud account on Windows and Android, with both
   devices registered and manual AI Report sync available.
3. Create a disposable completed report containing a non-sensitive marker in
   its title only. Do not record report body, prompt, provider details, token,
   or credential in screenshots or this document.

| ID | Check | Expected result | Status |
|---|---|---|---|
| A1 | Windows: open the completed disposable report | Detail shows status, body, and version history | PASS |
| A2 | Choose Archive and inspect the confirmation | It states archive keeps body/history and does not generate AI | PASS |
| A3 | Confirm Archive | Status becomes archived; success feedback appears | PASS |
| A4 | Reopen the archived report | Body and historical version remain readable | PASS |
| A5 | Inspect actions on archived report | Archive action is absent; no edit/generate action is introduced | PASS |
| A6 | Open the report library | Completed and archived reports remain distinguishable and readable | PASS |
| A7 | Manually sync AI Reports on Windows | Archive state uploads through the existing module with no automatic sync | PASS |
| B1 | Android: manually sync AI Reports | Same report appears archived, without a duplicate | PASS |
| B2 | Android: open archived report | Body and version history are present and unchanged | PASS |
| B3 | Sync both devices again | No duplicate report/version and no unexpected generation | PASS |
| C1 | Windows archive a completed report, then Android deletes the older completed copy before pulling | A scoped AI Report conflict is created after manual sync/pull | PASS |
| C2 | Open Sync Conflict Center and select the report conflict | Row identifies the report without showing body or internal IDs | PASS |
| C3 | If the remote summary is pending, choose Re-fetch remote version, then inspect both summaries | The remote summary appears and the explicit Adopt Remote / Keep Local actions become available; only title, period, status, and version count are visible, with report text hidden | PASS |
| C4 | Choose Adopt Remote and confirm | Conflict clears; remote delete/archive projection wins; immutable history is not rewritten | PASS |
| C5 | Recreate an archive versus old-local-state conflict | A new scoped AI Report conflict is shown | PASS |
| C6 | Choose Keep Local and confirm | Conflict clears only after normal manual resolution; local archive projection wins | PASS |
| C7 | Retry sync after each resolution | Cursor remains usable and no duplicate aggregate/version appears | PASS |
| D1 | Sign out, sign in as Account B, inspect library and conflict center | Account A reports, versions, archive state, and conflicts are not visible | PASS |
| D2 | Return to Account A | Account A report state and any unresolved conflict scope are restored | PASS |
| E1 | Inspect report library, detail, and conflict screens | No prompt, input snapshot, provider/model metadata, token, secret, or full user ID is displayed | PASS |
| E2 | Force an ordinary network failure during manual sync | Local archive/body/history remain intact and no false completion is shown | PASS |
| F1 | Windows at normal and maximum text scale | Archive and conflict actions remain readable and reachable without overflow | PASS |
| F2 | Android at 320, 360, and 412 px widths | No horizontal overflow; archive confirmation and conflict actions remain reachable | PASS |
| F3 | Android Back navigation from detail, archive dialog, and conflict detail | Returns to the expected prior screen without losing preserved report data | PASS |
| F4 | Restart both apps after a completed archive sync | Archived state, body, and history persist; no automatic generation or sync occurs | PASS |

Release gate: CLOSED. Archive lifecycle, cross-device propagation, both conflict
resolution directions, account isolation, privacy, failure recovery,
accessibility, and restart persistence were manually accepted.
