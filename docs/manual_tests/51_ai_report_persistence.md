# Sprint 14B AI Report Persistence Foundation

Status: `ACCEPTED WITH NON-APPLICABLE EXCLUSIONS`

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
| A1 | Settings shows a separate `AI 报告` entry | PASS | Windows/Android verified. |
| A2 | Opening the entry shows the local report list | PASS | Windows/Android verified. |
| A3 | The page does not automatically call AI | PASS | No automatic generation observed. |
| A4 | Refresh only reloads local data | PASS | No AI generation or sync request observed. |
| A5 | Back returns to Settings | PASS | Windows/Android verified. |
| B1 | Empty account shows the empty state | PASS | Account B verified. |
| B2 | Loading state is readable | NOT EXECUTED | No safe product-level loading injection. |
| B3 | Read failure shows retry without losing other app data | NOT EXECUTED | No safe product-level read-failure injection. |
| B4 | Completed report status is displayed | PASS | Verified. |
| B5 | Failed status is displayed without raw exception text | NOT EXECUTED | No safe product-level failed-state fixture. |
| B6 | Draft/generating state does not fabricate content | NOT EXECUTED | No safe product-level draft/generating fixture. |
| B7 | Archived state remains readable | NOT EXECUTED | No safe product-level archived-state fixture. |
| C1 | Opening a completed report shows its content | PASS | Verified. |
| C2 | Detail shows the report period and status | PASS | Verified. |
| C3 | Version 1 is shown for a migrated completed report | PASS | Verified. |
| C4 | Multiple versions are ordered newest first | NOT EXECUTED | No product flow creates multiple versions in this Sprint. |
| C5 | Older version content remains unchanged | NOT EXECUTED | No product flow creates multiple versions in this Sprint. |
| C6 | No edit or overwrite control is present | PASS | Verified. |
| C7 | No generation button is present in the Report library | PASS | Verified. |
| D1 | Close and restart Windows; reports remain | PASS | Verified. |
| D2 | Close and restart Android; reports remain | PASS | Verified. |
| D3 | Version history remains after restart | PASS | Verified for available history. |
| D4 | Existing AI Coach report history still works | PASS | Verified. |
| D5 | Existing pending recovery remains unchanged | PASS | Verified. |
| E1 | Account A can see only account A reports | PASS | Verified. |
| E2 | Switch to account B; account A reports disappear | PASS | Verified. |
| E3 | Account B cannot open account A detail via history | PASS | Verified. |
| E4 | Switch back to account A; its reports return | PASS | Verified. |
| E5 | Logout blocks access while retaining local rows | PASS | Verified. |
| E6 | Session rejection does not expose report content | PASS | Verified. |
| F1 | UI shows no API key, token, Prompt, or Provider secret | PASS | Verified. |
| F2 | UI shows no full internal user/report/version ID | PASS | Verified. |
| F3 | Growth output is unchanged by Report history | PASS | Verified. |
| F4 | Personal Data Overview excludes Report content | PASS | Verified. |
| F5 | Manual Sync Center contains no AI Report module | PASS | Verified. |
| F6 | Normal app/server logs contain no report content | NOT EXECUTED | No controlled product-level log capture was available. |
| G1 | Windows layout is readable and scrollable | PASS | Verified. |
| G2 | Android portrait layout is readable and scrollable | PASS | Verified. |
| G3 | 320 px width has no RenderFlex overflow | PASS | Verified. |
| G4 | TextScaler 2.0 has no overflow or hidden navigation | PASS | Verified. |
| G5 | Keyboard Tab/Enter opens list items on Windows | PASS | Verified. |
| G6 | Screen reader semantics identify report/version status | PASS | Verified. |

## Result Summary

- PASS: `34`
- FAIL: `0`
- NOT EXECUTED: `8`

AI Report Persistence Gate: `CONDITIONALLY ACCEPTED`

All applicable rows passed, CI passed, and no privacy or account-boundary defect
was found. The eight remaining rows require controlled test fixtures or product
flows that are intentionally outside Sprint 14B; they remain NOT EXECUTED rather
than being marked PASS.
