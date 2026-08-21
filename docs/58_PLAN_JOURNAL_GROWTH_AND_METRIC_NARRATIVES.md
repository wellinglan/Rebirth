# Sprint 17C-E Core Experience Consolidation & Metric Narratives

> Classification: **Accepted implementation contract / Gate closed with automated substitutions**
> Baseline: `0a3bbcd2005ca30b02693a1d3ee573c36c908fa3`
> Candidate HEAD: `877d359d5fe3eb4848edcffb991e0d221c4bd012`
> API image digest: `sha256:1c3e3ea3c0f0429aa79b391763efd9dbcb7205cfb2385766b789bc7e93671098`
> Flutter schemaVersion: `14`
> API Version: `1`
> Sync Protocol: `2`
> Server Alembic head: `20260812_0008` (unchanged)

Sprint 17C-E consolidates the production experience in Plan, Journal, Growth,
Today, and Health. It does not add AI capability, automatic synchronization,
or a second persistence path. The candidate API was published and deployed,
matching Windows and Android releases were exercised, and the final product
Gate closed with two explicitly accepted automated substitutions.

## Product Changes

### Plan

- The filter is opened on demand from the title area and closes when the user
  clicks outside it.
- `显示归档` lives inside the filter surface.
- Goal hierarchy uses indentation, restrained connectors, level/status/date
  metadata, and a compact action menu instead of nested cards.
- Goal Domain, parent-child rules, lifecycle, date calculation, Repository,
  database, and synchronization semantics are unchanged.

### Journal

- `/journal` contains only the selected day's reflection and edit flow.
- `/journal/history` owns the historical list, date navigation, detail, delete,
  and opening an existing date through the existing Journal controller flow.
- Opening the main Journal page does not preload the history list.
- Returning from history preserves an unsaved current reflection.
- Journal persistence and synchronization contracts are unchanged.

### Growth

- The main page is organized as 周期概览、专注、恢复、身心状态、反思.
- A compact `数据说明` entry opens `/growth/data-sources`, which reuses the
  existing projection and coverage view.
- The selected period is retained when returning from data sources.
- Mood and Energy charts, summaries, tooltips, detail text, and Semantics use
  the normalized 1-10 domain scale. Charts use `minY = 1` and
  `fixedMaxY = 10`.
- Already migrated values are never multiplied a second time. Aggregation
  algorithms and source records are unchanged, and Growth does not create a
  composite score or medical judgement.

## Metric Narrative Contract

All structured metric narratives are nullable strings, trimmed before save,
and limited to 80 characters. Blank or whitespace-only input becomes `null`.
A narrative may exist when its numeric metric is `null`, and that narrative
keeps the corresponding Today or Health record meaningful.

| Module | Metric | Field |
|---|---|---|
| Today | Mood | `moodDescription` |
| Today | Energy | `energyDescription` |
| Today | Research | `researchDescription` |
| Today | Learning | `learningDescription` |
| Health | Sleep | `sleepDescription` |
| Health | Weight | `weightDescription` |
| Health | Water | `waterDescription` |
| Health | Exercise | `exerciseDescription` |
| Health | Physical State | `physicalStateDescription` |

The first two Today fields and Physical State field were introduced in Sprint
17B. Sprint 17C-E adds the remaining six fields. These narratives are sensitive
body content. They must not appear in logs, exception text, SnackBars,
statistics, Semantics values, AI Prompt, or AI Context. Home and Growth do not
surface the text automatically.

## Local Persistence

Flutter Drift advances from schema 13 to 14 through additive nullable columns:

```text
today_records
  research_description TEXT NULL
  learning_description TEXT NULL

health_records
  sleep_description TEXT NULL
  weight_description TEXT NULL
  water_description TEXT NULL
  exercise_description TEXT NULL
```

Each non-null value has a database length constraint of at most 80 characters.
The migration does not rewrite existing business values, `updated_at`, sync
status, server version, last-synced time, tombstone, cursor, or conflict state.
Migrations from every supported historical Flutter schema are tested through
schema 14.

Repository writes explicitly update `updatedAt`, preserve fields not edited by
the current UI, and retain the distinction between `null` and explicit numeric
zero. Description-only records are not classified as empty. Full Personal Data
Export includes all nine narratives in the owning module and remains local,
plaintext, account-scoped, and export-only.

## Compact Metric Editing

Production Today and Health use three shared widgets:

```dart
CompactDurationEditor(
  label: label,
  icon: icon,
  value: totalMinutes,
  onChanged: onChanged,
  resetToken: resetToken,
)

CompactQuantityEditor(
  label: label,
  icon: icon,
  value: value,
  unit: unit,
  onChanged: onChanged,
  allowDecimal: allowDecimal,
  allowZero: allowZero,
  allowAdd: allowAdd,
  maximumValue: maximumValue,
  resetToken: resetToken,
)

MetricDescriptionField(
  label: label,
  value: value,
  hintText: hintText,
  onChanged: onChanged,
  resetToken: resetToken,
)
```

Research, Learning, Sleep, and Exercise continue to store `int?` total minutes.
Water continues to store `int?` ml. Weight remains direct kg input and does not
offer the add operation. Full direct input is always available; the add button
opens a focused amount dialog. There are no permanent decrement controls,
step chips, or automatic saves.

Two empty duration inputs mean `null`; `0h 0min` means explicit zero. Empty
Water means `null`; `0` means explicit zero. Add requires a positive amount and
treats `null + amount` as `amount`. Clear sets the field to `null`. Direct edit,
add, and clear each create one field-local undo opportunity; undo restores only
the latest valid unsaved value and is consumed after one use. Successful save,
reload, date change, or account change clears undo history. Water input, add,
clear, and undo update `WaterCupIndicator` immediately without implying a
medical target.

Descriptions remain collapsed while empty, expand on request, and stay
expanded when populated. An overlength value blocks save. Save failure retains
the current numeric values, descriptions, and undo state.

## Sync Contract

Today and Health continue through their existing adapters, `SyncCoordinator`,
cursor, OCC, tombstone, and conflict framework. New clients send the complete
field set for their payload generation, including keys whose values are null.
Server Pydantic models keep `extra="forbid"`, trim narrative strings, enforce
80 characters, and reject partial extension generations with HTTP 422.

Three generations are accepted:

1. Legacy payloads before Sprint 17B, with implicit 1-5 scores and no scale or
   metric descriptions.
2. Sprint 17B payloads, with explicit score scale and Mood/Energy or Physical
   State descriptions.
3. Sprint 17C-E payloads, with the complete scale fields and all narrative keys
   belonging to Today or Health.

Submitted payload JSON is stored and returned exactly, including explicit null
keys. Conflict local and remote snapshots expose the new fields only inside the
authenticated conflict flow. Account A cannot read, export, synchronize, or
resolve Account B's narratives.

The Server uses the existing generic sync JSON. No PostgreSQL business column,
model, Alembic revision, API version, protocol version, sync module, or
automatic synchronization behavior changes. Because Server validation changed,
the candidate API image must be published and deployed before cross-device
acceptance.

## Responsive and Accessibility Contract

- Android remains single-column; Windows uses constrained content widths.
- Controls wrap at 320px and TextScaler 2.0 without horizontal overflow.
- Icon buttons retain at least 48px interaction targets, Tooltip, and readable
  Semantics.
- Tab, Enter, Space, directional navigation, TalkBack, and Windows keyboard
  operation remain supported where applicable.
- Sensitive narrative contents are not used as Semantics values.

## Verification and Release Gate

Automated verification includes Drift migration, repositories, export,
payload codecs, Server contract validation, SQLite/PostgreSQL/multi-worker,
conflict recovery, responsive widgets, keyboard/Semantics, and regressions.
Publication is not deployment, and automation is not manual acceptance.

The authoritative manual matrix is
[Plan, Journal, Growth and Metric Narratives](manual_tests/63_plan_journal_growth_and_metric_narratives.md).
It records `67 PASS / 0 FAIL / 2 NOT EXECUTED`. D11 retains automated
failed-save recovery evidence because no safe product-level failure injection
exists. G8 retains automated legacy/Sprint-17B payload compatibility evidence
because no safe product-level legacy fixture exists. Neither row is counted as
manual PASS.

The **Sprint 17C-E Core Experience Gate is CLOSED WITH ACCEPTED AUTOMATED
SUBSTITUTIONS** after:

1. local verification and release builds pass;
2. GitHub Quality and image publication pass for the candidate commit;
3. the candidate full-SHA API image is deployed without changing PostgreSQL;
4. matching Windows and Android release artifacts complete the applicable
   manual matrix;
5. results were recorded in one final documentation-only acceptance commit.

Candidate GitHub Quality run
[32404151284](https://github.com/wellinglan/Rebirth/actions/runs/32404151284)
and image-publication run
[32404151075](https://github.com/wellinglan/Rebirth/actions/runs/32404151075)
passed. The Beijing Alpha Server runs the full-SHA API image with the digest
above after API-only recreation. PostgreSQL remained healthy and was not
restarted; `/health` reported API Version `1` and Sync Protocol `2`.

## Explicit Non-goals

This Sprint does not add AI capability, AI Chat, automatic AI text, automatic
sync, a new Growth score, medical guidance, Journal repository changes, Plan
domain/date/sync changes, PostgreSQL schema changes, or import/restore.
