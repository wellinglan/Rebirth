# Sprint 17C-E Plan, Journal, Growth and Metric Narratives Manual Acceptance

> Status: **ACCEPTED WITH AUTOMATED SUBSTITUTIONS**
> Gate: **CLOSED**
> Final result: **67 PASS / 0 FAIL / 2 NOT EXECUTED**
> Baseline: `0a3bbcd2005ca30b02693a1d3ee573c36c908fa3`
> Candidate HEAD: `877d359d5fe3eb4848edcffb991e0d221c4bd012`
> API image: `ghcr.io/wellinglan/rebirth-api:877d359d5fe3eb4848edcffb991e0d221c4bd012`
> API digest: `sha256:1c3e3ea3c0f0429aa79b391763efd9dbcb7205cfb2385766b789bc7e93671098`
> Alpha deployment: API-only recreation verified healthy on `2026-08-21`

This matrix was executed after the candidate full-SHA API image was deployed
and matching Windows release and Android arm64 release artifacts were installed.
Unless a row says otherwise, each `PASS` below is the user's reported product
result on `2026-08-21`. Automated evidence is not represented as manual PASS.

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
| A1 | On Android, open Plan and confirm the filter is collapsed by default and goals have usable space. | PASS | |
| A2 | Open the title-area filter; verify controls and `显示归档` are readable and usable. | PASS | |
| A3 | Tap outside the filter and confirm it closes without changing selected filters. | PASS | |
| A4 | Verify root and child goals are distinguishable through indentation, connectors, level, state, and date. | PASS | |
| A5 | Use the compact goal menu to edit, change status, archive, and delete test goals. | PASS | |
| A6 | Confirm monthly, quarterly, custom, and parent-child date behavior matches the existing product rules. | PASS | |
| A7 | Repeat the hierarchy/filter flow on Windows and confirm the content remains compact and keyboard reachable. | PASS | |

## B. Journal History

| ID | Manual action and expected result | Status | Evidence / note |
|---|---|---|---|
| B1 | Open Journal and confirm no history list or history loading/error block appears below the current reflection. | PASS | |
| B2 | Use the history icon and confirm `/journal/history` opens as a separate page. | PASS | |
| B3 | Navigate dates in history and open an existing entry through the existing Journal edit flow. | PASS | |
| B4 | View details and delete a disposable historical entry; confirm the list refreshes correctly. | PASS | |
| B5 | Enter unsaved text in today's reflection, visit history, return, and confirm the unsaved text remains. | PASS | |
| B6 | Confirm Back from history returns to Journal without an unexpected route or duplicate page. | PASS | |
| B7 | Repeat the history flow on Windows and Android and verify account/date scope remains correct. | PASS | |

## C. Growth

| ID | Manual action and expected result | Status | Evidence / note |
|---|---|---|---|
| C1 | Open Growth and confirm the large inline data-coverage/source block is absent. | PASS | |
| C2 | Open the compact `数据说明` entry and confirm the existing coverage/source content appears on its own page. | PASS | |
| C3 | Change the Growth period, visit data sources, return, and confirm the selected period is retained. | PASS | |
| C4 | Confirm the main hierarchy is 周期概览、专注、恢复、身心状态、反思. | PASS | |
| C5 | Verify Mood chart axis, summary, tooltip, and detail all use 1-10. | PASS | |
| C6 | Verify Energy chart axis, summary, tooltip, and detail all use 1-10. | PASS | |
| C7 | Check known migrated records and confirm values were not doubled again. | PASS | |
| C8 | Confirm Growth shows no composite growth score, achievement judgement, or medical judgement. | PASS | |
| C9 | Repeat chart and data-source navigation on Windows and Android without clipping or route errors. | PASS | |

## D. Compact Input

| ID | Manual action and expected result | Status | Evidence / note |
|---|---|---|---|
| D1 | Directly enter Research hours/minutes and save; confirm the correct total minutes reload. | PASS | |
| D2 | Use Research add dialog with a positive duration; confirm it adds to null/zero/current value accurately. | PASS | |
| D3 | Clear Research, undo once, and confirm a second undo is disabled. | PASS | |
| D4 | Repeat direct/add/clear/undo for Learning, Sleep, and Exercise. | PASS | |
| D5 | Enter `0h 0min`, save, and confirm explicit zero is retained after reload. | PASS | |
| D6 | Clear both duration inputs, save, and confirm the value reloads as null rather than zero. | PASS | |
| D7 | Enter invalid/negative hours, invalid minutes, or a non-positive add amount and confirm save/add is blocked. | PASS | |
| D8 | Directly enter Water, use add, clear, and undo; confirm the exact ml value changes as expected. | PASS | |
| D9 | Confirm WaterCupIndicator updates immediately for direct input, add, clear, and undo without a medical target. | PASS | |
| D10 | Enter Weight directly, clear and undo it; confirm no Weight add operation is offered. | PASS | |
| D11 | Make unsaved edits, force a normal recoverable save failure, and confirm values and undo state are retained. | NOT EXECUTED | No safe product-level failure injection. Automated evidence: Today/Health failed-save widget and controller tests passed locally and in Quality run `32404151284`. |
| D12 | Confirm editing, add, clear, and undo do not automatically save or start synchronization. | PASS | |

## E. Metric Descriptions

| ID | Manual action and expected result | Status | Evidence / note |
|---|---|---|---|
| E1 | Add, save, and reload Mood and Energy descriptions. | PASS | |
| E2 | Add, save, and reload Research and Learning descriptions. | PASS | |
| E3 | Add, save, and reload Sleep and Weight descriptions. | PASS | |
| E4 | Add, save, and reload Water and Exercise descriptions. | PASS | |
| E5 | Add, save, and reload a Physical State description. | PASS | |
| E6 | Save a description while its metric value is null and confirm the record and description remain. | PASS | |
| E7 | Save whitespace-only text and confirm it reloads as null. | PASS | |
| E8 | Enter more than 80 characters and confirm validation blocks save without losing the text. | PASS | |
| E9 | Confirm an empty description stays collapsed, an existing one opens expanded, and clear restores null. | PASS | |

## F. Persistence and Migration

| ID | Manual action and expected result | Status | Evidence / note |
|---|---|---|---|
| F1 | Upgrade a safe schema-13 client database and confirm existing Today/Health values and records remain intact. | PASS | Safe retained client data was upgraded and checked. |
| F2 | Restart Windows after saving numeric values and all applicable narratives; confirm they remain. | PASS | |
| F3 | Restart Android after saving numeric values and all applicable narratives; confirm they remain. | PASS | |
| F4 | Export current-account personal data and verify the nine narrative fields, nulls, and explicit zeros are represented correctly. | PASS | Disposable test text only. |
| F5 | Confirm fields not currently shown or edited by a form remain unchanged after saving visible fields. | PASS | |

## G. Cross-device Sync and Conflict

| ID | Manual action and expected result | Status | Evidence / note |
|---|---|---|---|
| G1 | Save all new Today narratives on Windows, manually sync, pull on Android, and verify exact values including null keys. | PASS | Candidate API deployment verified before execution. |
| G2 | Save all new Health narratives on Android, manually sync, pull on Windows, and verify exact values including null keys. | PASS | Candidate API deployment verified before execution. |
| G3 | Verify explicit numeric zero and null remain distinct after the round trip. | PASS | |
| G4 | Create a Today conflict containing narrative changes and verify local and remote snapshots are available. | PASS | |
| G5 | Resolve the Today conflict once with Adopt Remote and once with Keep Local; verify convergence and conflict removal. | PASS | |
| G6 | Create and resolve the equivalent Health narrative conflict in both directions. | PASS | |
| G7 | Verify cursor, OCC, tombstone, retry, and manual-only synchronization behavior remain normal after conflict recovery. | PASS | |
| G8 | Confirm a pre-Sprint-17B legacy payload fixture and a Sprint-17B payload remain accepted. | NOT EXECUTED | No safe product-level legacy payload fixture. Automated evidence: Today/Health legacy and Sprint 17B codec tests plus Server three-generation contract tests passed locally and in Quality run `32404151284`. |

## H. Account and Privacy

| ID | Manual action and expected result | Status | Evidence / note |
|---|---|---|---|
| H1 | Save narratives in Account A, switch to Account B, and confirm they are not visible. | PASS | |
| H2 | Export Account B and confirm Account A narratives are absent. | PASS | |
| H3 | Sync Account B and confirm it cannot pull or resolve Account A narratives/conflicts. | PASS | |
| H4 | Inspect visible errors, SnackBars, and conflict list summaries and confirm narrative text is not leaked. | PASS | |
| H5 | Confirm Home, Growth summaries, and accessibility announcements do not expose narrative contents automatically. | PASS | |

## I. Responsive and Accessibility

| ID | Manual action and expected result | Status | Evidence / note |
|---|---|---|---|
| I1 | On a 320px Android-width layout, exercise Plan, Journal History, Growth, Today, and Health without horizontal overflow. | PASS | |
| I2 | At TextScaler 2.0, confirm labels, units, buttons, menus, and validation messages wrap without hiding actions. | PASS | |
| I3 | On Windows, use Tab, Enter, and Space for compact editors, description expansion/clear, filters, and history navigation. | PASS | |
| I4 | Confirm direction keys and native rating controls remain usable for Mood, Energy, and Physical State. | PASS | |
| I5 | With TalkBack, confirm controls announce labels, current numeric values, units, and actions without narrative body text. | PASS | |
| I6 | Confirm all icon-only actions have readable Tooltip/Semantics and at least 48px interaction targets. | PASS | |
| I7 | Scroll each affected page at maximum font size and confirm save, back, menus, and history/data-source navigation remain reachable. | PASS | |

## Final Gate Decision

The user reported every safely executable Windows, Android, migration,
cross-device, account, privacy, responsive, and accessibility row as PASS.
Result: **67 PASS / 0 FAIL / 2 NOT EXECUTED**. D11 has no safe product-level
save-failure injection and G8 has no safe product-level legacy payload fixture;
both retain named automated evidence and are not counted as manual PASS.

GitHub Quality [run 32404151284](https://github.com/wellinglan/Rebirth/actions/runs/32404151284)
and Publish Alpha Images [run 32404151075](https://github.com/wellinglan/Rebirth/actions/runs/32404151075)
passed for the candidate. The full-SHA API image was digest-verified and
deployed through API-only recreation; PostgreSQL remained healthy and was not
restarted. `/health` returned API Version `1` and Sync Protocol `2`.

The **Sprint 17C-E Core Experience Gate is CLOSED WITH ACCEPTED AUTOMATED
SUBSTITUTIONS**. This closes the Sprint product Gate, not the separate public
Production or app-store release blockers.
