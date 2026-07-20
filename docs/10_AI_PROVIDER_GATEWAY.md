# AI Provider Gateway And Report Contracts

## Scope

The user-visible flow remains the explicit, synchronous, non-streaming `weekly_report` with `weekly-report-v1`. Sprint 9A adds the typed `daily_insight` + `daily-insight-v1` foundation and developer test endpoint without adding a UI action. There is still no chat, tools, automatic/background generation, server report history, AIReport sync, or source-record mutation. Flutter database `schemaVersion` remains 3.

The flow is:

```text
Local Preview -> Final confirmation -> local pending AIReport
-> Rebirth FastAPI -> verified/minimized Provider payload
-> strict structured output -> server Markdown renderer
-> local completed or failed AIReport -> History/Detail
```

Preview remains local and never creates `pending`. Consent, login, capabilities, supported versions, reusable completed reports, and the current Preview identity are checked before `createPending`. Closing or cancelling the final dialog creates nothing.

## Configuration

The Server reads:

| Variable | Default | Meaning |
|---|---|---|
| `REBIRTH_AI_PROVIDER` | `disabled` | `disabled`, `fake`, or `openai` |
| `OPENAI_API_KEY` | none | OpenAI credential, Server only |
| `REBIRTH_AI_MODEL` | none | Deployment-selected model ID |
| `REBIRTH_AI_TIMEOUT_SECONDS` | `90` | Provider request timeout |
| `REBIRTH_AI_MAX_OUTPUT_TOKENS` | `1600` | Conservative output limit |
| `REBIRTH_AI_FAKE_SCENARIO` | `success` | Development Fake scenario |

`openai` requires a key and model. `fake` is rejected outside development/test. The key uses a `repr=False` Settings field and is never returned by health/capabilities/errors. Flutter, SharedPreferences, Drift, logs, fixtures, and source control must never contain it.

## Server Contract

All endpoints require the existing Rebirth JWT:

- `GET /ai/capabilities`
- `POST /ai/reports/daily/generate`
- `POST /ai/reports/weekly/generate`
- `GET /ai/requests/{request_id}`

The generate request contains a UUID `request_id`, lowercase SHA-256 `input_hash`, and a report-specific Canonical Input payload. Daily requires one explicit natural date and only Today, Health, or Journal scopes; Weekly requires seven inclusive dates and may also use Growth. The Server rejects extra fields, invalid periods, cross-paired report/prompt identities, unsupported scopes, and data that does not exactly match selected scopes.

The Server sorts map keys recursively, scopes, sources, and dated rows, serializes compact UTF-8 JSON with preserved `null`/`0`/JSON scalar types, and recomputes SHA-256. A mismatch blocks Provider invocation. Dart and Python verify `test/fixtures/ai_weekly_input_v1.json` against the same expected hash.

## Provider Boundary

The Provider sees only:

```text
report_type, prompt_version, period, scopes, data
```

Canonical `sources`, source IDs, request/hash/local IDs, cloud identity, device/token/endpoint and sync metadata are removed. Unselected scopes are absent. Growth is marked as a derived summary. Existing assembler minimization continues to exclude Today notes/priority text and Health notes. User identity is not inserted into model text.

The server-owned prompt treats all user data as untrusted data, ignores embedded instructions, distinguishes missing values from zero, forbids diagnosis/personality judgments/causal claims, and requires neutral optional suggestions. User data is supplied as a separate input message.

## OpenAI Adapter

The adapter uses the official Python SDK Responses API with the configured model, strict JSON Schema, `store=false`, `stream=false`, an empty tools list, no background/conversation/previous response, explicit timeout and maximum output tokens, and zero SDK retries. The safety identifier is a namespaced SHA-256 of the authenticated internal user ID and is neither stored locally nor shown in UI.

`store=false` requests that Provider response application state not be stored; it does not promise absolute zero retention. Production use still needs provider-policy, privacy, cost, logging, and legal review.

## Output and Errors

Weekly output schema v1 requires `title`, `summary`, up to five observations, up to three suggestions, and `data_limitations`. Daily output schema v1 requires `title`, `summary`, up to four observations, up to three caveated possible factors, up to three optional tomorrow adjustments, and `data_limitations`. Nested and top-level models reject additional fields. The Server selects output schema and deterministic Markdown renderer through the typed report/prompt registry. Arbitrary Provider text is never accepted as report content.

Controlled errors are: `gateway_disabled`, `authentication_required`, `invalid_request`, `invalid_input`, `input_hash_mismatch`, `idempotency_conflict`, `unsupported_report_type`, `unsupported_prompt_version`, `unsupported_scope`, `provider_authentication_failed`, `provider_rate_limited`, `provider_timeout`, `provider_unavailable`, `provider_refused`, `response_invalid`, `request_failed`, `outcome_unknown`, `result_expired`, `not_found`, and `unknown`.

After confirmation, a failure marks the local pending report failed with only one controlled text code. Timeout is never retried automatically because another call can incur cost. A crash can leave `pending`; Sprint 8C displays it as-is and does not recover/resend it.

## Sprint 8D Durable Request Ledger

The Server now persists a minimal `ai_generation_requests` ledger and exposes `GET /ai/requests/{request_id}`. A unique JWT-user/request ID claim prevents the same request ID from invoking the Provider more than once while the tombstone exists. Completed output is temporarily replayable; active processing returns 202; failed, stale/outcome-unknown, and expired requests never invoke Provider again.

The ledger never stores the input payload, Canonical JSON, sources, source IDs, Journal text, Provider request body, raw Provider response, token, or API key. It temporarily stores validated structured output and rendered Markdown, which can contain sensitive summaries. Defaults are 24-hour result retention, 30-day dedupe retention, and a 5-minute processing lease, all reported by capabilities. Cleanup is lazy.

Flutter stores endpoint/account/request identity in a SharedPreferences Binding before POST. Network timeout keeps local pending and permits explicit status GET; Provider timeout is a terminal controlled failure. Consent revocation still permits recovery of an already-sent request. No status path retries POST.

## Current Limits

AI runtime events use the `rebirth.ai` JSON logger and the allowlist documented in `12_AI_OPERATIONS_AND_OBSERVABILITY.md`. Provider events include latency; replay has a distinct event. No input or output body is logged. Startup rejects timeout/lease/retention relationships that could invalidate request ownership.

The ledger provides at-most-once ownership for one database and retained request ID, not exactly-once. Provider invocation and result commit are not atomic; the crash gap can become `outcome_unknown`, and duplicate-cost risk cannot be completely eliminated across external Provider behavior or dedupe expiry. Reports remain local-only and source data is read-only. Real OpenAI smoke testing is opt-in with `REBIRTH_RUN_OPENAI_SMOKE=1`; normal tests use Fake/Mocks only.
