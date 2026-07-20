# Daily Insight Foundation

## Scope

Sprint 9A adds the typed, testable foundation for one manually requested `daily_insight`. It does not expose a Today, Journal, or AI Coach generation button and does not add chat, streaming, automatic generation, background work, Growth changes, sync, or source-record mutation. The existing Weekly UI and contract remain supported. Flutter `schemaVersion` remains 3.

## Contract Identity

| Field | Daily Insight | Weekly Report |
|---|---|---|
| `report_type` | `daily_insight` | `weekly_report` |
| `prompt_version` | `daily-insight-v1` | `weekly-report-v1` |
| input schema | 1 | 1 |
| output schema | 1 | 1 |
| period | one explicit local natural date, start = end | seven local natural dates |
| scopes | Today, Health, Journal | Growth, Today, Health, Journal |

Daily rejects `growth_summary` and `active_goals`. A selected scope with no record is present as an empty array. An unselected scope has no key in `data`. `null` remains missing and an explicit `0` remains zero.

## Flutter Assembly

`AiCoachInputAssembler.buildDailyInsight(targetDate, selection)` accepts an explicit `YYYY-MM-DD` target date. It reuses the existing consent gate, repositories, canonical JSON encoder, SHA-256 hasher, source normalization, and `AiCoachInputBundle`.

Only selected repositories are queried. Daily permits at most one Today, Health, and Journal record for the target date. The minimized rows exclude Today daily note and priority text, Health note and source metadata, user/device identity, endpoint, token, Provider/model, and sync fields. Journal text is included only after explicit Journal selection and is trimmed; an empty answer becomes `null`.

Sources contain only actual selected records as `table`, `id`, and `updated_at`. They are sorted and deduplicated by table/id, retaining the latest `updated_at`. Sources participate in canonical hash identity but are removed before Provider invocation and are never stored in the Server ledger or logs.

The shared fixture is `test/fixtures/ai_daily_insight_input_v1.json`; its SHA-256 is stored in `test/fixtures/ai_daily_insight_input_v1_expected_hash.txt` and verified by Dart and Python.

## Server Contract

Authenticated endpoints are:

- `GET /ai/capabilities`
- `POST /ai/reports/daily/generate`
- `POST /ai/reports/weekly/generate`
- `GET /ai/requests/{request_id}`

Capabilities expose typed `report_contracts`, including report/prompt pairing, schema versions, period kind, and supported scopes. Legacy aggregate capability fields remain for compatibility.

The Daily endpoint validates strict request shape, one-day period, report/prompt pairing, scope/data correspondence, record dates, row counts, and canonical SHA-256 before the Provider can run. The Provider receives only `report_type`, `prompt_version`, `period`, `scopes`, and selected `data`.

## Output

Daily output schema 1 contains:

- nonblank `title` and `summary`;
- up to four `observations` with nonblank `statement` and string `evidence`;
- up to three `possible_factors` with nonblank `factor` and `caveat`;
- up to three `tomorrow_adjustments` with nonblank `action` and `reason`;
- string-array `data_limitations`.

Top-level and nested extra fields are forbidden. The server-owned prompt treats Journal content as untrusted data, distinguishes missing from zero, avoids diagnosis, judgment and causal claims, and presents adjustments as optional low-burden experiments. Only validated structured output is rendered to deterministic Markdown.

## Reliability And Privacy

Daily reuses the durable `ai_generation_requests` ledger without a migration. A retained request ID is claimed at most once per JWT user, supports completed replay and status recovery, and preserves the existing `processing`, `failed`, `outcome_unknown`, and `result_expired` behavior. The ledger stores request identity and temporary validated output, never the input payload, canonical JSON, Sources, source IDs, Journal input, credentials, or raw Provider objects.

The deterministic Fake Provider supports Daily `success`, `timeout`, `refusal`, `invalid`, and `unavailable` scenarios. Normal tests and CI do not call real OpenAI. PostgreSQL includes a four-process Daily marker proving one claim owner and one ledger row without a Python global lock.

## Current Boundary

Sprint 9A is a foundation only. Ordinary users cannot trigger Daily Insight in the app, and no automatic schedule exists. Real OpenAI smoke and Android physical-device use are separate opt-in/manual verification. Production still requires the security, retention, privacy, cost, and legal controls documented for the existing gateway.
