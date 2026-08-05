# AI Report Safe Export Manual Acceptance

Status: PASS WITH ACCEPTED LIMITATION (37 PASS / 0 FAIL / 1 NOT EXECUTED).

Execution record: 2026-08-05 on Windows release and Android arm64-v8a
release. Single-report Markdown export, complete-library JSON export,
non-mutation behavior, recoverable file failure, account isolation, privacy,
responsive layout, accessibility, keyboard navigation, Android Back, and
local-only operation all passed. D5 remains honestly NOT EXECUTED because no
safe product-level SessionRejected injection was available; automated coverage
exists but is not counted as a manual PASS.

Automated tests do not count as manual PASS. Record results only after using
Windows release and Android arm64-v8a release builds with disposable report
content. Never paste report bodies, exported files, credentials, account IDs,
or private paths into this document.

## Prerequisites

1. Install the Sprint 14F Windows release and arm64-v8a Android release.
2. Sign in to Account A on both devices and prepare disposable completed,
   archived, failed, and multi-version reports with harmless marker text.
3. Prepare Account B with an independent local/cloud scope.
4. Use a disposable destination folder. For the controlled failure check, use
   only a test folder whose write permission can safely be removed and
   restored; otherwise record that item as `NOT EXECUTED` with the reason.
5. Record only PASS, FAIL, or honestly NOT EXECUTED. A save-dialog screenshot
   must not expose paths, report content, usernames, or credentials.

| ID | Check | Expected result | Status |
|---|---|---|---|
| A1 | Windows: open a completed report detail | `导出当前报告` is visible without changing lifecycle controls | PASS |
| A2 | Activate `导出当前报告` | A warning states that body and version history may contain sensitive personal information | PASS |
| A3 | Cancel the warning | No platform dialog or file appears; detail content remains unchanged | PASS |
| A4 | Confirm and choose a trusted destination | A UTF-8 Markdown file is saved and success feedback appears | PASS |
| A5 | Inspect the suggested single-report file name | It uses only the report period and contains no title, account ID, or internal ID | PASS |
| A6 | Open the Markdown file | Title, type, period, lifecycle, timestamps, and current content are readable | PASS |
| A7 | Inspect a multi-version Markdown export | Every immutable version appears once in ascending version order | PASS |
| B1 | Windows: open AI Report Library with multiple statuses | `导出全部报告` is visible and enabled | PASS |
| B2 | Activate `导出全部报告` | The warning clearly refers to all current-account reports | PASS |
| B3 | Select a status filter, then export all | Export still contains all un-deleted current-account reports, not only visible rows | PASS |
| B4 | Save the complete export | A UTF-8 `rebirth-ai-reports-YYYY-MM-DD.json` file is saved | PASS |
| B5 | Parse the JSON with a trusted local parser | The document parses without repair or encoding errors | PASS |
| B6 | Inspect the JSON envelope | `format_version` is `1.0`, `exported_at` is UTC ISO-8601, and `reports` is an array | PASS |
| B7 | Inspect completed, archived, failed, and multi-version entries | Status, nullable content, timestamps, and version history remain distinguishable | PASS |
| C1 | Record report status, version count, sync label, and conflict count before export | A stable before-state is available for comparison | PASS |
| C2 | Complete single and all exports | Report status, body, version count, and updated time do not change | PASS |
| C3 | Compare sync and conflict state after export | Sync status, server version behavior, cursor, and conflict count do not change | PASS |
| C4 | Use the disposable unwritable destination described above | A controlled failure appears without leaking the private path or exception | PASS |
| C5 | Restore write access and retry | Export succeeds without restarting or losing report content | PASS |
| C6 | Restart both apps after cancellation/failure/success | Reports and versions reload unchanged; no automatic generation or sync starts | PASS |
| D1 | Account A: export all using harmless A markers | The file contains A reports | PASS |
| D2 | Sign out and try to revisit an AI Report export route | Protected UI is inaccessible and no export can start | PASS |
| D3 | Sign in as Account B and export all | No Account A title, body, version, or marker is present | PASS |
| D4 | Export one Account B report | Only the selected B report and its versions are present | PASS |
| D5 | Reject/expire the session, then attempt export | The auth gate blocks the report UI and no file is created | NOT EXECUTED |
| D6 | Return to Account A | A reports return without duplication and can still be exported | PASS |
| E1 | Search both export formats | No user ID, device ID, report/version UUID, or source record ID exists | PASS |
| E2 | Search both export formats | No Prompt, prompt version, input hash, scope, source list, or input snapshot exists | PASS |
| E3 | Search both export formats | No Provider, model, generation source, model metadata, or structured output exists | PASS |
| E4 | Search both export formats | No Token, Secret, Authorization, endpoint, request ledger, or usage ledger exists | PASS |
| E5 | Search the JSON export | No sync status, serverVersion, cursor, conflict payload, or tombstone exists | PASS |
| E6 | Inspect suggested names and user-visible failure messages | They expose no report title, identity, private path, credential, or stack trace | PASS |
| F1 | Windows: use Tab, Shift+Tab, Enter, Space, and Escape | Export buttons and warning dialog are fully keyboard operable | PASS |
| F2 | Android: open the warning and use system Back | The dialog closes as cancellation and no file is created | PASS |
| F3 | Android at 320 px width | Buttons, warning text, progress state, and feedback remain readable with no overflow | PASS |
| F4 | Android at 360 and 412 px widths | Detail and library export flows remain scrollable and usable | PASS |
| F5 | Windows and Android with TextScaler 2.0 | No RenderFlex overflow, clipped warning, or hidden required action occurs | PASS |
| F6 | Observe network and app behavior during export | No AI generation, Provider call, upload, cloud export, or manual/automatic sync starts | PASS |

Release gate: CLOSED WITH ACCEPTED LIMITATION. The AI Report Safe Export and
Data Portability Gate is accepted with 37 manual PASS results and 0 FAIL. D5 is
the sole NOT EXECUTED item because no safe product-level SessionRejected fault
injection was available; the limitation is explicit and accepted.
