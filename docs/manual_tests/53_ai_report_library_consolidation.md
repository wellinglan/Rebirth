# AI Report Library Consolidation Manual Acceptance

Status: PASS (31 PASS / 0 FAIL / 0 NOT EXECUTED).

Execution record: 2026-08-04 on Windows release and Android arm64-v8a
release. All entry, lifecycle, sync/conflict, account isolation, privacy,
responsive, accessibility, Back navigation, and restart checks passed without
an observed exception.

Automated Flutter tests do not count as manual PASS. Record Windows and Android
results only after exercising release builds with disposable report data.

Prerequisites:

1. Install the Sprint 14E Windows release and arm64-v8a Android release.
2. Sign in to Account A on both devices and make manual AI Report sync
   available.
3. Prepare disposable completed, archived, and failed reports. Use a harmless
   marker only in titles; do not place report body, prompts, credentials, or
   private source data in this document or screenshots.
4. Prepare Account B with an independent local/cloud account scope.

| ID | Check | Expected result | Status |
|---|---|---|---|
| A1 | Windows: Settings -> AI Report Library | The canonical AI Report Library opens | PASS |
| A2 | Return to Settings, open AI Coach -> Local Reports | The tab shows one action that opens the same canonical library | PASS |
| A3 | Compare both entry destinations | Both show the same reports, filters, sync states, and actions | PASS |
| A4 | Open an old `/ai-coach/reports/:id` deep link | It safely redirects to the canonical `/ai-reports/:id` detail | PASS |
| A5 | Use Back from detail and from the library | Navigation returns to the expected prior product screen | PASS |
| A6 | Inspect AI Coach Local Reports | No second embedded report list or duplicate lifecycle controls remain | PASS |
| B1 | Select All | Completed, archived, and failed reports are distinguishable | PASS |
| B2 | Select Completed | Only completed reports remain visible | PASS |
| B3 | Select Archived | Only archived reports remain visible | PASS |
| B4 | Select Failed | Only failed reports remain visible | PASS |
| B5 | Select a status with no report | A clear empty-filter state appears and All can be restored | PASS |
| B6 | Inspect each list row | Title, period, created/updated time, status, version count, and sync state are readable | PASS |
| C1 | Open a completed report | Existing detail content and immutable version history are readable | PASS |
| C2 | Open an archived report | Body and historical versions remain readable; no unarchive/edit/regenerate action appears | PASS |
| C3 | Archive a completed report | Existing confirmation and archive flow work; versions remain unchanged | PASS |
| C4 | Restart the app and reopen the archived report | Archived status and version history persist | PASS |
| D1 | Inspect synced, pending, and conflict rows | Safe labels show Synced, Waiting to sync, or Conflict | PASS |
| D2 | Open Sync Center from the library | Existing manual Sync Center opens; no sync starts automatically | PASS |
| D3 | Open Conflict Center from the library | Conflict Center opens scoped to AI Reports | PASS |
| D4 | Resolve a disposable AI Report conflict | Existing Adopt Remote / Keep Local flow works and library refreshes normally | PASS |
| E1 | Sign out of Account A, then sign in as Account B | Account A reports and versions are absent | PASS |
| E2 | Inspect Account B conflict entry | Account A conflicts are absent | PASS |
| E3 | Return to Account A | Account A reports and its unresolved conflict scope return without duplication | PASS |
| E4 | Reject/expire the session while on a report route | Protected report UI is no longer accessible and no A content flashes | PASS |
| F1 | Inspect the ordinary list | No report body, Prompt, AI input, Provider/model, API state, token, secret, internal UUID, user ID, cursor, or payload is shown | PASS |
| F2 | Windows: use Tab, Shift+Tab, Enter, Space, and Escape | Filters, report rows, toolbar actions, dialogs, and Back behavior remain operable | PASS |
| F3 | Windows at 720, 840, and 1200 px widths | Layout remains compact and has no horizontal overflow | PASS |
| F4 | Android at 320, 360, and 412 px widths | Titles, filters, statuses, toolbar actions, and list rows remain readable and scrollable | PASS |
| F5 | Windows and Android with TextScaler 2.0 | No RenderFlex overflow or hidden required action occurs | PASS |
| F6 | Android: use system Back from library/detail/conflict center | Each route returns predictably without changing report data | PASS |
| F7 | Restart both release apps | Library state is reloaded from the active account; no automatic generation or sync occurs | PASS |

Release gate: CLOSED. The canonical-entry, lifecycle, sync/conflict,
account-isolation, privacy, responsive, accessibility, navigation, and restart
checks were manually accepted with 0 FAIL.
