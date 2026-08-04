# AI Report Cross-device Sync Manual Acceptance

Status: PASS for all applicable manual checks. B1-B3 and C1-C6 are NOT
EXECUTED because the current production UI deliberately has no report archive,
edit, or same-aggregate version-append operation.

Prerequisites: deploy the Sprint 14C API image after CI passes; sign in to the
same cloud account and register both Windows and Android devices. Use manual
sync only. Do not use a production report or paste report content into a test
recording.

| ID | Check | Expected result | Status |
|---|---|---|---|
| A1 | Open Sync Center on Windows | AI report is a separate sensitive module | PASS |
| A2 | Generate a terminal report on Windows, then sync AI reports | One report uploads; no prompt/provider/usage UI appears | PASS |
| A3 | Sync AI reports on Android | Same title, period, terminal status, and version count appear | PASS |
| A4 | Open report history on Android | Version content is readable in report history only | PASS |
| A5 | Sync again on both devices | No duplicate report or duplicate version | PASS |
| B1 | Create a new terminal version on Windows | Existing historical version remains unchanged | NOT EXECUTED - no production UI to append a version to an existing report |
| B2 | Sync Android then Windows | New version is appended and current version is consistent | NOT EXECUTED - depends on B1; covered by automated tests |
| B3 | Archive a report and sync | Archive state transfers without rewriting history | NOT EXECUTED - report archive is not a production UI operation |
| C1 | Edit the same report aggregate independently on both devices | A scoped AI report conflict is shown | NOT EXECUTED - no production UI to edit an existing report aggregate |
| C2 | Open conflict details | Only title, period, state, and version count are visible; body is hidden | NOT EXECUTED - depends on C1; covered by automated tests |
| C3 | Retrieve remote version | Remote summary appears and local report remains until a choice | NOT EXECUTED - depends on C1; covered by automated tests |
| C4 | Choose adopt remote | Conflict clears, remote projection is present, immutable versions retained | NOT EXECUTED - depends on C1; covered by automated tests |
| C5 | Recreate a conflict and choose keep local | Conflict clears after manual upload; local projection wins | NOT EXECUTED - depends on C1; covered by automated tests |
| C6 | Retry a failed conflict action | No crash, no data loss, and retry stays available | NOT EXECUTED - depends on C1; covered by automated tests |
| D1 | Delete a synced report on Windows | Root tombstone syncs; report disappears on Android | PASS |
| D2 | Sync repeatedly after delete | Deleted report does not reappear | PASS |
| D3 | Attempt no action while offline | Local report remains intact and cursor does not falsely advance | PASS |
| E1 | Sign in as account B | Account A reports, conflicts, and history are not visible | PASS |
| E2 | Return to account A | Account A report state is restored | PASS |
| F1 | Windows at normal and maximum text scale | No overflow; sync controls remain usable | PASS |
| F2 | Android 320/360/412 px widths | No horizontal overflow; conflict actions remain reachable | PASS |

Release gate is closed: all applicable rows passed. The remaining rows are
explicitly NOT EXECUTED because they have no corresponding production UI flow;
their protocol behavior remains covered by automated tests.
