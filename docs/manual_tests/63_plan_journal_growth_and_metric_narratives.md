# Sprint 17C-E Plan, Journal, Growth and Metric Narratives Manual Acceptance

> Status: **NOT EXECUTED**
> Gate: **OPEN**
> Initial result: **0 PASS / 0 FAIL / 69 NOT EXECUTED**
> Baseline: `0a3bbcd2005ca30b02693a1d3ee573c36c908fa3`
> Candidate HEAD: pending final local verification
> API image/tag/digest: pending GitHub publication
> Alpha deployment identity: pending

This matrix must be executed only after the candidate full-SHA API image is
deployed and matching Windows release and Android arm64 release artifacts are
installed. Automated evidence must never be entered as manual PASS. A row that
cannot be safely exercised remains `NOT EXECUTED` with its exact reason.

## Preconditions

- Record the candidate full SHA, Windows artifact, Android arm64 APK, API image
  full-SHA tag, short tag, and digest.
- Confirm the API container is running/healthy and `/health` reports API Version
  `1` and Sync Protocol `2`.
- Confirm only the API container was recreated; PostgreSQL, its volume, other
  environment variables, business data, and Alembic head were not changed.
- Use Windows and Android clients from the same candidate commit.
- Prepare two authenticated accounts and two registered devices. Use only
  disposable test records without real sensitive narrative text.
- Preserve a pre-upgrade account/database for the migration and retained-field
  checks when one is safely available.

## A. Plan

| ID | Manual action and expected result | Status | Evidence / note |
|---|---|---|---|
| A1 | On Android, open Plan and confirm the filter is collapsed by default and goals have usable space. | NOT EXECUTED | |
| A2 | Open the title-area filter; verify controls and `显示归档` are readable and usable. | NOT EXECUTED | |
| A3 | Tap outside the filter and confirm it closes without changing selected filters. | NOT EXECUTED | |
| A4 | Verify root and child goals are distinguishable through indentation, connectors, level, state, and date. | NOT EXECUTED | |
| A5 | Use the compact goal menu to edit, change status, archive, and delete test goals. | NOT EXECUTED | |
| A6 | Confirm monthly, quarterly, custom, and parent-child date behavior matches the existing product rules. | NOT EXECUTED | |
| A7 | Repeat the hierarchy/filter flow on Windows and confirm the content remains compact and keyboard reachable. | NOT EXECUTED | |

## B. Journal History

| ID | Manual action and expected result | Status | Evidence / note |
|---|---|---|---|
| B1 | Open Journal and confirm no history list or history loading/error block appears below the current reflection. | NOT EXECUTED | |
| B2 | Use the history icon and confirm `/journal/history` opens as a separate page. | NOT EXECUTED | |
| B3 | Navigate dates in history and open an existing entry through the existing Journal edit flow. | NOT EXECUTED | |
| B4 | View details and delete a disposable historical entry; confirm the list refreshes correctly. | NOT EXECUTED | |
| B5 | Enter unsaved text in today's reflection, visit history, return, and confirm the unsaved text remains. | NOT EXECUTED | |
| B6 | Confirm Back from history returns to Journal without an unexpected route or duplicate page. | NOT EXECUTED | |
| B7 | Repeat the history flow on Windows and Android and verify account/date scope remains correct. | NOT EXECUTED | |

## C. Growth

| ID | Manual action and expected result | Status | Evidence / note |
|---|---|---|---|
| C1 | Open Growth and confirm the large inline data-coverage/source block is absent. | NOT EXECUTED | |
| C2 | Open the compact `数据说明` entry and confirm the existing coverage/source content appears on its own page. | NOT EXECUTED | |
| C3 | Change the Growth period, visit data sources, return, and confirm the selected period is retained. | NOT EXECUTED | |
| C4 | Confirm the main hierarchy is 周期概览、专注、恢复、身心状态、反思. | NOT EXECUTED | |
| C5 | Verify Mood chart axis, summary, tooltip, and detail all use 1-10. | NOT EXECUTED | |
| C6 | Verify Energy chart axis, summary, tooltip, and detail all use 1-10. | NOT EXECUTED | |
| C7 | Check known migrated records and confirm values were not doubled again. | NOT EXECUTED | |
| C8 | Confirm Growth shows no composite growth score, achievement judgement, or medical judgement. | NOT EXECUTED | |
| C9 | Repeat chart and data-source navigation on Windows and Android without clipping or route errors. | NOT EXECUTED | |

## D. Compact Input

| ID | Manual action and expected result | Status | Evidence / note |
|---|---|---|---|
| D1 | Directly enter Research hours/minutes and save; confirm the correct total minutes reload. | NOT EXECUTED | |
| D2 | Use Research add dialog with a positive duration; confirm it adds to null/zero/current value accurately. | NOT EXECUTED | |
| D3 | Clear Research, undo once, and confirm a second undo is disabled. | NOT EXECUTED | |
| D4 | Repeat direct/add/clear/undo for Learning, Sleep, and Exercise. | NOT EXECUTED | |
| D5 | Enter `0h 0min`, save, and confirm explicit zero is retained after reload. | NOT EXECUTED | |
| D6 | Clear both duration inputs, save, and confirm the value reloads as null rather than zero. | NOT EXECUTED | |
| D7 | Enter invalid/negative hours, invalid minutes, or a non-positive add amount and confirm save/add is blocked. | NOT EXECUTED | |
| D8 | Directly enter Water, use add, clear, and undo; confirm the exact ml value changes as expected. | NOT EXECUTED | |
| D9 | Confirm WaterCupIndicator updates immediately for direct input, add, clear, and undo without a medical target. | NOT EXECUTED | |
| D10 | Enter Weight directly, clear and undo it; confirm no Weight add operation is offered. | NOT EXECUTED | |
| D11 | Make unsaved edits, force a normal recoverable save failure, and confirm values and undo state are retained. | NOT EXECUTED | No safe failure injection may be available. |
| D12 | Confirm editing, add, clear, and undo do not automatically save or start synchronization. | NOT EXECUTED | |

## E. Metric Descriptions

| ID | Manual action and expected result | Status | Evidence / note |
|---|---|---|---|
| E1 | Add, save, and reload Mood and Energy descriptions. | NOT EXECUTED | |
| E2 | Add, save, and reload Research and Learning descriptions. | NOT EXECUTED | |
| E3 | Add, save, and reload Sleep and Weight descriptions. | NOT EXECUTED | |
| E4 | Add, save, and reload Water and Exercise descriptions. | NOT EXECUTED | |
| E5 | Add, save, and reload a Physical State description. | NOT EXECUTED | |
| E6 | Save a description while its metric value is null and confirm the record and description remain. | NOT EXECUTED | |
| E7 | Save whitespace-only text and confirm it reloads as null. | NOT EXECUTED | |
| E8 | Enter more than 80 characters and confirm validation blocks save without losing the text. | NOT EXECUTED | |
| E9 | Confirm an empty description stays collapsed, an existing one opens expanded, and clear restores null. | NOT EXECUTED | |

## F. Persistence and Migration

| ID | Manual action and expected result | Status | Evidence / note |
|---|---|---|---|
| F1 | Upgrade a safe schema-13 client database and confirm existing Today/Health values and records remain intact. | NOT EXECUTED | Retained fixture may be unavailable; automation must be cited instead of PASS. |
| F2 | Restart Windows after saving numeric values and all applicable narratives; confirm they remain. | NOT EXECUTED | |
| F3 | Restart Android after saving numeric values and all applicable narratives; confirm they remain. | NOT EXECUTED | |
| F4 | Export current-account personal data and verify the nine narrative fields, nulls, and explicit zeros are represented correctly. | NOT EXECUTED | Use disposable text only. |
| F5 | Confirm fields not currently shown or edited by a form remain unchanged after saving visible fields. | NOT EXECUTED | |

## G. Cross-device Sync and Conflict

| ID | Manual action and expected result | Status | Evidence / note |
|---|---|---|---|
| G1 | Save all new Today narratives on Windows, manually sync, pull on Android, and verify exact values including null keys. | NOT EXECUTED | Requires candidate API deployment. |
| G2 | Save all new Health narratives on Android, manually sync, pull on Windows, and verify exact values including null keys. | NOT EXECUTED | Requires candidate API deployment. |
| G3 | Verify explicit numeric zero and null remain distinct after the round trip. | NOT EXECUTED | |
| G4 | Create a Today conflict containing narrative changes and verify local and remote snapshots are available. | NOT EXECUTED | |
| G5 | Resolve the Today conflict once with Adopt Remote and once with Keep Local; verify convergence and conflict removal. | NOT EXECUTED | |
| G6 | Create and resolve the equivalent Health narrative conflict in both directions. | NOT EXECUTED | |
| G7 | Verify cursor, OCC, tombstone, retry, and manual-only synchronization behavior remain normal after conflict recovery. | NOT EXECUTED | |
| G8 | Confirm a pre-Sprint-17B legacy payload fixture and a Sprint-17B payload remain accepted. | NOT EXECUTED | Product-level legacy fixture may be unsafe/unavailable; automation may substitute only as NOT EXECUTED evidence. |

## H. Account and Privacy

| ID | Manual action and expected result | Status | Evidence / note |
|---|---|---|---|
| H1 | Save narratives in Account A, switch to Account B, and confirm they are not visible. | NOT EXECUTED | |
| H2 | Export Account B and confirm Account A narratives are absent. | NOT EXECUTED | |
| H3 | Sync Account B and confirm it cannot pull or resolve Account A narratives/conflicts. | NOT EXECUTED | |
| H4 | Inspect visible errors, SnackBars, and conflict list summaries and confirm narrative text is not leaked. | NOT EXECUTED | |
| H5 | Confirm Home, Growth summaries, and accessibility announcements do not expose narrative contents automatically. | NOT EXECUTED | |

## I. Responsive and Accessibility

| ID | Manual action and expected result | Status | Evidence / note |
|---|---|---|---|
| I1 | On a 320px Android-width layout, exercise Plan, Journal History, Growth, Today, and Health without horizontal overflow. | NOT EXECUTED | |
| I2 | At TextScaler 2.0, confirm labels, units, buttons, menus, and validation messages wrap without hiding actions. | NOT EXECUTED | |
| I3 | On Windows, use Tab, Enter, and Space for compact editors, description expansion/clear, filters, and history navigation. | NOT EXECUTED | |
| I4 | Confirm direction keys and native rating controls remain usable for Mood, Energy, and Physical State. | NOT EXECUTED | |
| I5 | With TalkBack, confirm controls announce labels, current numeric values, units, and actions without narrative body text. | NOT EXECUTED | |
| I6 | Confirm all icon-only actions have readable Tooltip/Semantics and at least 48px interaction targets. | NOT EXECUTED | |
| I7 | Scroll each affected page at maximum font size and confirm save, back, menus, and history/data-source navigation remain reachable. | NOT EXECUTED | |

## Initial Gate Decision

The matrix has not been executed. Result: **0 PASS / 0 FAIL / 69 NOT
EXECUTED**. The **Sprint 17C-E Core Experience Gate remains OPEN**. Do not
close it after local tests, CI, image publication, or deployment alone. Record
the complete user-reported matrix in one final documentation-only commit.
