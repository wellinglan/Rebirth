# Sprint 14B AI Report Persistence Foundation

Status: `NOT EXECUTED`

Baseline: `272de1e0958eef41bbcbdf0130a8d30ccdd506cf`

This matrix validates local Report persistence and read-only history. It does
not validate automatic generation, AI Report sync, cloud storage, chat, agents,
or editable conclusions.

## Preconditions

- Install the Sprint 14B Windows release and arm64-v8a Android release.
- Use one authenticated account A on both platforms.
- Have at least one existing completed Daily Insight or Weekly Report.
- Keep a second independent account B available for isolation checks.
- Do not clear app data between persistence checks.

## Matrix

| ID | Check | Result | Notes |
|---|---|---|---|
| A1 | Settings shows a separate `AI 报告` entry | NOT EXECUTED | |
| A2 | Opening the entry shows the local report list | NOT EXECUTED | |
| A3 | The page does not automatically call AI | NOT EXECUTED | |
| A4 | Refresh only reloads local data | NOT EXECUTED | |
| A5 | Back returns to Settings | NOT EXECUTED | |
| B1 | Empty account shows the empty state | NOT EXECUTED | |
| B2 | Loading state is readable | NOT EXECUTED | |
| B3 | Read failure shows retry without losing other app data | NOT EXECUTED | |
| B4 | Completed report status is displayed | NOT EXECUTED | |
| B5 | Failed status is displayed without raw exception text | NOT EXECUTED | |
| B6 | Draft/generating state does not fabricate content | NOT EXECUTED | |
| B7 | Archived state remains readable | NOT EXECUTED | |
| C1 | Opening a completed report shows its content | NOT EXECUTED | |
| C2 | Detail shows the report period and status | NOT EXECUTED | |
| C3 | Version 1 is shown for a migrated completed report | NOT EXECUTED | |
| C4 | Multiple versions are ordered newest first | NOT EXECUTED | |
| C5 | Older version content remains unchanged | NOT EXECUTED | |
| C6 | No edit or overwrite control is present | NOT EXECUTED | |
| C7 | No generation button is present in the Report library | NOT EXECUTED | |
| D1 | Close and restart Windows; reports remain | NOT EXECUTED | |
| D2 | Close and restart Android; reports remain | NOT EXECUTED | |
| D3 | Version history remains after restart | NOT EXECUTED | |
| D4 | Existing AI Coach report history still works | NOT EXECUTED | |
| D5 | Existing pending recovery remains unchanged | NOT EXECUTED | |
| E1 | Account A can see only account A reports | NOT EXECUTED | |
| E2 | Switch to account B; account A reports disappear | NOT EXECUTED | |
| E3 | Account B cannot open account A detail via history | NOT EXECUTED | |
| E4 | Switch back to account A; its reports return | NOT EXECUTED | |
| E5 | Logout blocks access while retaining local rows | NOT EXECUTED | |
| E6 | Session rejection does not expose report content | NOT EXECUTED | |
| F1 | UI shows no API key, token, Prompt, or Provider secret | NOT EXECUTED | |
| F2 | UI shows no full internal user/report/version ID | NOT EXECUTED | |
| F3 | Growth output is unchanged by Report history | NOT EXECUTED | |
| F4 | Personal Data Overview excludes Report content | NOT EXECUTED | |
| F5 | Manual Sync Center contains no AI Report module | NOT EXECUTED | |
| F6 | Normal app/server logs contain no report content | NOT EXECUTED | |
| G1 | Windows layout is readable and scrollable | NOT EXECUTED | |
| G2 | Android portrait layout is readable and scrollable | NOT EXECUTED | |
| G3 | 320 px width has no RenderFlex overflow | NOT EXECUTED | |
| G4 | TextScaler 2.0 has no overflow or hidden navigation | NOT EXECUTED | |
| G5 | Keyboard Tab/Enter opens list items on Windows | NOT EXECUTED | |
| G6 | Screen reader semantics identify report/version status | NOT EXECUTED | |

## Result Summary

- PASS: `0`
- FAIL: `0`
- NOT EXECUTED: `42`

AI Report Persistence Gate: `OPEN`

The gate remains open until all applicable rows are executed, CI passes, and no
privacy or account-boundary defect remains.
