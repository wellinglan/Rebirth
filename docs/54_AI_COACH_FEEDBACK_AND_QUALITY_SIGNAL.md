# AI Coach Feedback and Quality Signal

> Sprint: **16B**
> Classification: **Active implementation / manual Gate open**
> Starting HEAD: `260356faf79deac1c72b8dd6f97f938185a4e6e3`

## Purpose

Sprint 16B adds a privacy-controlled quality signal for immutable completed AI
Report versions. A user may mark one version as `helpful` or `not_helpful`,
select fixed reasons for a negative rating, modify the current selection, or
clear it. Feedback is observation data. It does not edit a report version,
train a model, change a Prompt, trigger generation, or promise that a later
report will improve.

The implementation adds no AI Chat, agent, tool calling, report type,
background work, automatic sync, Provider, quota, or ledger behavior.

## Phase 0 Decision

The audit found no legal existing store for mutable, account-scoped,
version-bound feedback. `ai_reports` is the report aggregate,
`ai_report_versions` is immutable generation history, and generation/usage
ledgers and sync conflicts have different ownership and retention semantics.
SharedPreferences, report content, Prompt metadata, untyped arbitrary JSON, and
controller memory are therefore invalid homes.

Flutter advances from schema 11 to 12 and adds the independent
`ai_report_feedback` aggregate. The Server adds a matching PostgreSQL/SQLite
table through Alembic revision `20260812_0008`. This additive migration is the
smallest design that preserves local-first writes, account isolation, strict
typing, deletion tombstones, OCC, and cross-device convergence.

## Aggregate Contract

Each active row is unique by `(user_id, report_id, report_version)` and stores:

- a stable feedback UUID and immutable report-version identity;
- report type plus copied governed `prompt_id` and `prompt_version`;
- `helpful` or `not_helpful`;
- canonical, sorted reason codes from the fixed allowlist;
- creation/update/deletion times;
- dedicated pending, remote-version, last-sync, and conflict metadata.

The fixed negative reason codes are:

| Code | Product label |
|---|---|
| `repetitive` | 内容重复 |
| `not_factually_grounded` | 与记录事实不符 |
| `not_actionable` | 建议不够可执行 |
| `too_generic` | 内容过于笼统 |
| `missed_important_context` | 遗漏重要背景 |
| `tone_not_helpful` | 表达方式没有帮助 |
| `hard_to_understand` | 内容难以理解 |

No free-text field exists in the Drift table, Server table, API request, UI,
or export DTO. `helpful` always has an empty reason list. `not_helpful`
requires at least one allowlisted reason. Unknown, duplicate, or non-canonical
reason data fails closed.

## Eligibility and UI

Feedback appears only in canonical report detail and completed historical
version detail. Completed Daily Insight and Weekly Report versions with body
content are eligible. An archived report remains eligible because archive does
not remove its body or immutable versions. Draft, pending, generating, failed,
outcome-unknown, bodyless, deleted, and wrong-account versions are ineligible.

The UI uses a segmented helpfulness control, fixed reason chips, Save, Modify,
and Clear actions. Saving is single-flight and keeps the local selection on
failure. Ordinary UI shows neither free text nor Prompt version, input hash,
Provider, model, request/feedback ID, server version, or raw sync state. The
privacy note states that only structured choices are recorded and report body
is excluded.

## Local-first, API, and Cross-device Flow

```text
Report detail / historical version
  -> AiReportFeedbackController
  -> account-scoped repository
  -> local ai_report_feedback row first
  -> pending push or pending delete
  -> explicit AI Report manual sync
  -> dedicated feedback API
  -> server ai_report_feedback row
```

The API is authenticated and derives account ownership only from the JWT:

- `GET /ai/report-feedback` lists the current account's records;
- `POST /ai/report-feedback/upsert` creates or updates one aggregate;
- `POST /ai/report-feedback/delete` creates an OCC tombstone.

Requests never accept `user_id`, report content, Prompt content, source data,
Provider response, or free text. The Server verifies ownership against the
already-synced report and verifies the completed immutable version before an
upsert. Exact retries are idempotent. Stale expected versions return the current
remote projection as an explicit conflict; reason lists are never field-merged.

Feedback deliberately does not become a seventh Sync Protocol entity. AI
Report manual sync first runs the existing `SyncCoordinator` report transport,
then the dedicated feedback service. Feedback waits when its report has not
reached the Server. A feedback-stage failure returns an explicit partial result
and preserves the already-completed report sync. There is no startup,
background, scheduled, or automatic retry.

## Modification, Clear, and Retention

Repeated identical saves do not create rows or versions. A changed local
selection becomes pending for the next explicit manual sync. Clearing a
never-synced selection removes the local-only row. Clearing a previously synced
selection writes a local `pending_delete` tombstone and sends a dedicated
delete mutation. Report deletion removes never-synced feedback and tombstones
synced feedback so another device can converge.

Server clear records `deleted_at` instead of erasing cross-device evidence.
The feedback audit excludes deleted rows from quality rates and reports only a
deleted count. Complete cloud-account deletion and long-term Production
retention remain part of the existing unresolved deletion-policy work; this
Sprint does not claim an end-to-end account-erasure implementation.

## Export Contract

Full Personal Data Export format `1.0` gains the optional, self-describing
`ai_report_feedback` module. It exports report ID, version number, report type,
helpfulness, fixed reasons, governed Prompt identity, and business timestamps,
including a clear timestamp when present. It excludes user/cloud/device IDs,
server version, sync state, last-sync time, pending state, conflict snapshot,
remote payload, report body duplication, and any free text.

The export remains plaintext, local, explicit, read-only, account-scoped, and
without import or restore. Existing format 1.0 consumers must use the module
manifest and ignore unknown optional modules.

## Aggregate Quality CLI

Operators may run the read-only command from `server`:

```bash
python -m app.maintenance.rebirth_ai feedback-audit --days 30
```

The default UTC window is 30 days. Output groups sample size, helpful counts
and rate, negative reason counts, report type, Prompt ID, and Prompt version.
It never returns user/report/feedback IDs, report or source bodies, Prompt
text, request data, credentials, tokens, or Provider responses. It does not
repair or mutate rows. These signals support human Prompt review only; no
automatic Prompt activation, ranking, model training, or generation change is
implemented.

## Versions and Release State

- Flutter schemaVersion: `12`;
- Server Alembic head: `20260812_0008`;
- API Version: `1`;
- Sync Protocol: `2`;
- active Prompts: unchanged Daily/Weekly v1 definitions;
- Provider, quota, generation ledger, and usage ledger: unchanged.

Publishing a GHCR image from a reviewed commit is not deployment. The
`AI Coach Feedback & Quality Signal Gate` remains **OPEN** until the manual
matrix, exact Alpha image/migration record, and required CI evidence are
completed with no FAIL.
