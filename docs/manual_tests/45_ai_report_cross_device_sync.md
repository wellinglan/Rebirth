# AI Report Cross-device Sync Manual Acceptance

Status: NOT EXECUTED

Prerequisites: deploy the Sprint 14C API image after CI passes; sign in to the
same cloud account and register both Windows and Android devices. Use manual
sync only. Do not use a production report or paste report content into a test
recording.

| ID | Check | Expected result | Status |
|---|---|---|---|
| A1 | Open Sync Center on Windows | AI report is a separate sensitive module | NOT EXECUTED |
| A2 | Generate a terminal report on Windows, then sync AI reports | One report uploads; no prompt/provider/usage UI appears | NOT EXECUTED |
| A3 | Sync AI reports on Android | Same title, period, terminal status, and version count appear | NOT EXECUTED |
| A4 | Open report history on Android | Version content is readable in report history only | NOT EXECUTED |
| A5 | Sync again on both devices | No duplicate report or duplicate version | NOT EXECUTED |
| B1 | Create a new terminal version on Windows | Existing historical version remains unchanged | NOT EXECUTED |
| B2 | Sync Android then Windows | New version is appended and current version is consistent | NOT EXECUTED |
| B3 | Archive a report and sync | Archive state transfers without rewriting history | NOT EXECUTED |
| C1 | Edit the same report aggregate independently on both devices | A scoped AI report conflict is shown | NOT EXECUTED |
| C2 | Open conflict details | Only title, period, state, and version count are visible; body is hidden | NOT EXECUTED |
| C3 | Retrieve remote version | Remote summary appears and local report remains until a choice | NOT EXECUTED |
| C4 | Choose adopt remote | Conflict clears, remote projection is present, immutable versions retained | NOT EXECUTED |
| C5 | Recreate a conflict and choose keep local | Conflict clears after manual upload; local projection wins | NOT EXECUTED |
| C6 | Retry a failed conflict action | No crash, no data loss, and retry stays available | NOT EXECUTED |
| D1 | Delete a synced report on Windows | Root tombstone syncs; report disappears on Android | NOT EXECUTED |
| D2 | Sync repeatedly after delete | Deleted report does not reappear | NOT EXECUTED |
| D3 | Attempt no action while offline | Local report remains intact and cursor does not falsely advance | NOT EXECUTED |
| E1 | Sign in as account B | Account A reports, conflicts, and history are not visible | NOT EXECUTED |
| E2 | Return to account A | Account A report state is restored | NOT EXECUTED |
| F1 | Windows at normal and maximum text scale | No overflow; sync controls remain usable | NOT EXECUTED |
| F2 | Android 320/360/412 px widths | No horizontal overflow; conflict actions remain reachable | NOT EXECUTED |

Release gate closes only when all applicable rows are PASS and any unavailable
environment-specific row is explicitly recorded as NOT EXECUTED with a reason.
