# AI Report Lifecycle And Conflict Readiness Manual Acceptance

Status: NOT EXECUTED. Record only real execution results; automated tests do
not become manual PASS.

Prerequisites:

1. Install the Sprint 14D Windows release and arm64-v8a Android release.
2. Sign in with the same Cloud account on Windows and Android, with both
   devices registered and manual AI Report sync available.
3. Create a disposable completed report containing a non-sensitive marker in
   its title only. Do not record report body, prompt, provider details, token,
   or credential in screenshots or this document.

| ID | Check | Expected result | Status |
|---|---|---|---|
| A1 | Windows: open the completed disposable report | Detail shows status, body, and version history | NOT EXECUTED |
| A2 | Choose Archive and inspect the confirmation | It states archive keeps body/history and does not generate AI | NOT EXECUTED |
| A3 | Confirm Archive | Status becomes archived; success feedback appears | NOT EXECUTED |
| A4 | Reopen the archived report | Body and historical version remain readable | NOT EXECUTED |
| A5 | Inspect actions on archived report | Archive action is absent; no edit/generate action is introduced | NOT EXECUTED |
| A6 | Open the report library | Completed and archived reports remain distinguishable and readable | NOT EXECUTED |
| A7 | Manually sync AI Reports on Windows | Archive state uploads through the existing module with no automatic sync | NOT EXECUTED |
| B1 | Android: manually sync AI Reports | Same report appears archived, without a duplicate | NOT EXECUTED |
| B2 | Android: open archived report | Body and version history are present and unchanged | NOT EXECUTED |
| B3 | Sync both devices again | No duplicate report/version and no unexpected generation | NOT EXECUTED |
| C1 | Windows archive a completed report, then Android deletes the older completed copy before pulling | A scoped AI Report conflict is created after manual sync/pull | NOT EXECUTED |
| C2 | Open Sync Conflict Center and select the report conflict | Row identifies the report without showing body or internal IDs | NOT EXECUTED |
| C3 | If the remote summary is pending, choose Re-fetch remote version, then inspect both summaries | The remote summary appears and the explicit Adopt Remote / Keep Local actions become available; only title, period, status, and version count are visible, with report text hidden | NOT EXECUTED |
| C4 | Choose Adopt Remote and confirm | Conflict clears; remote delete/archive projection wins; immutable history is not rewritten | NOT EXECUTED |
| C5 | Recreate an archive versus old-local-state conflict | A new scoped AI Report conflict is shown | NOT EXECUTED |
| C6 | Choose Keep Local and confirm | Conflict clears only after normal manual resolution; local archive projection wins | NOT EXECUTED |
| C7 | Retry sync after each resolution | Cursor remains usable and no duplicate aggregate/version appears | NOT EXECUTED |
| D1 | Sign out, sign in as Account B, inspect library and conflict center | Account A reports, versions, archive state, and conflicts are not visible | NOT EXECUTED |
| D2 | Return to Account A | Account A report state and any unresolved conflict scope are restored | NOT EXECUTED |
| E1 | Inspect report library, detail, and conflict screens | No prompt, input snapshot, provider/model metadata, token, secret, or full user ID is displayed | NOT EXECUTED |
| E2 | Force an ordinary network failure during manual sync | Local archive/body/history remain intact and no false completion is shown | NOT EXECUTED |
| F1 | Windows at normal and maximum text scale | Archive and conflict actions remain readable and reachable without overflow | NOT EXECUTED |
| F2 | Android at 320, 360, and 412 px widths | No horizontal overflow; archive confirmation and conflict actions remain reachable | NOT EXECUTED |
| F3 | Android Back navigation from detail, archive dialog, and conflict detail | Returns to the expected prior screen without losing preserved report data | NOT EXECUTED |
| F4 | Restart both apps after a completed archive sync | Archived state, body, and history persist; no automatic generation or sync occurs | NOT EXECUTED |

Release gate is open until applicable rows are manually executed and recorded.
Rows requiring a deliberately destructive cross-device setup may remain NOT
EXECUTED only when the required isolated test account/environment is unavailable.
