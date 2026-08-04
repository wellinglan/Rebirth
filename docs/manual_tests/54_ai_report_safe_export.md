# AI Report Safe Export Manual Acceptance

Status: NOT EXECUTED (0 PASS / 0 FAIL / 38 NOT EXECUTED).

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
| A1 | Windows: open a completed report detail | `导出当前报告` is visible without changing lifecycle controls | NOT EXECUTED |
| A2 | Activate `导出当前报告` | A warning states that body and version history may contain sensitive personal information | NOT EXECUTED |
| A3 | Cancel the warning | No platform dialog or file appears; detail content remains unchanged | NOT EXECUTED |
| A4 | Confirm and choose a trusted destination | A UTF-8 Markdown file is saved and success feedback appears | NOT EXECUTED |
| A5 | Inspect the suggested single-report file name | It uses only the report period and contains no title, account ID, or internal ID | NOT EXECUTED |
| A6 | Open the Markdown file | Title, type, period, lifecycle, timestamps, and current content are readable | NOT EXECUTED |
| A7 | Inspect a multi-version Markdown export | Every immutable version appears once in ascending version order | NOT EXECUTED |
| B1 | Windows: open AI Report Library with multiple statuses | `导出全部报告` is visible and enabled | NOT EXECUTED |
| B2 | Activate `导出全部报告` | The warning clearly refers to all current-account reports | NOT EXECUTED |
| B3 | Select a status filter, then export all | Export still contains all un-deleted current-account reports, not only visible rows | NOT EXECUTED |
| B4 | Save the complete export | A UTF-8 `rebirth-ai-reports-YYYY-MM-DD.json` file is saved | NOT EXECUTED |
| B5 | Parse the JSON with a trusted local parser | The document parses without repair or encoding errors | NOT EXECUTED |
| B6 | Inspect the JSON envelope | `format_version` is `1.0`, `exported_at` is UTC ISO-8601, and `reports` is an array | NOT EXECUTED |
| B7 | Inspect completed, archived, failed, and multi-version entries | Status, nullable content, timestamps, and version history remain distinguishable | NOT EXECUTED |
| C1 | Record report status, version count, sync label, and conflict count before export | A stable before-state is available for comparison | NOT EXECUTED |
| C2 | Complete single and all exports | Report status, body, version count, and updated time do not change | NOT EXECUTED |
| C3 | Compare sync and conflict state after export | Sync status, server version behavior, cursor, and conflict count do not change | NOT EXECUTED |
| C4 | Use the disposable unwritable destination described above | A controlled failure appears without leaking the private path or exception | NOT EXECUTED |
| C5 | Restore write access and retry | Export succeeds without restarting or losing report content | NOT EXECUTED |
| C6 | Restart both apps after cancellation/failure/success | Reports and versions reload unchanged; no automatic generation or sync starts | NOT EXECUTED |
| D1 | Account A: export all using harmless A markers | The file contains A reports | NOT EXECUTED |
| D2 | Sign out and try to revisit an AI Report export route | Protected UI is inaccessible and no export can start | NOT EXECUTED |
| D3 | Sign in as Account B and export all | No Account A title, body, version, or marker is present | NOT EXECUTED |
| D4 | Export one Account B report | Only the selected B report and its versions are present | NOT EXECUTED |
| D5 | Reject/expire the session, then attempt export | The auth gate blocks the report UI and no file is created | NOT EXECUTED |
| D6 | Return to Account A | A reports return without duplication and can still be exported | NOT EXECUTED |
| E1 | Search both export formats | No user ID, device ID, report/version UUID, or source record ID exists | NOT EXECUTED |
| E2 | Search both export formats | No Prompt, prompt version, input hash, scope, source list, or input snapshot exists | NOT EXECUTED |
| E3 | Search both export formats | No Provider, model, generation source, model metadata, or structured output exists | NOT EXECUTED |
| E4 | Search both export formats | No Token, Secret, Authorization, endpoint, request ledger, or usage ledger exists | NOT EXECUTED |
| E5 | Search the JSON export | No sync status, serverVersion, cursor, conflict payload, or tombstone exists | NOT EXECUTED |
| E6 | Inspect suggested names and user-visible failure messages | They expose no report title, identity, private path, credential, or stack trace | NOT EXECUTED |
| F1 | Windows: use Tab, Shift+Tab, Enter, Space, and Escape | Export buttons and warning dialog are fully keyboard operable | NOT EXECUTED |
| F2 | Android: open the warning and use system Back | The dialog closes as cancellation and no file is created | NOT EXECUTED |
| F3 | Android at 320 px width | Buttons, warning text, progress state, and feedback remain readable with no overflow | NOT EXECUTED |
| F4 | Android at 360 and 412 px widths | Detail and library export flows remain scrollable and usable | NOT EXECUTED |
| F5 | Windows and Android with TextScaler 2.0 | No RenderFlex overflow, clipped warning, or hidden required action occurs | NOT EXECUTED |
| F6 | Observe network and app behavior during export | No AI generation, Provider call, upload, cloud export, or manual/automatic sync starts | NOT EXECUTED |

Release gate: OPEN. Close the AI Report Safe Export and Data Portability Gate
only after the applicable Windows and Android checks are manually executed
with 0 FAIL and every NOT EXECUTED item has an explicit accepted reason.
