# Real AI Provider And Cost Safety

## Scope

Sprint 14A.1 activates a real Provider adapter without changing the AI Report
domain. The only supported product flow remains explicit manual Daily Insight
or Weekly Report generation:

```text
Flutter confirmation
  -> authenticated Rebirth API
  -> durable request claim
  -> atomic usage reservation
  -> AI Provider adapter
  -> validated structured result
  -> local AI Report
```

There is no chat, agent, tool calling, background generation, automatic retry,
AI data mutation, AI sync entity, API version change, or Sync Protocol change.
Flutter Drift remains `schemaVersion = 9`.

## Provider Boundary

`AiProvider` remains the only external model boundary. `FakeAiProvider`,
`DeepSeekProvider`, `OpenAiResponsesProvider`, and `DisabledAiProvider` all
return the same `ProviderGeneration` value. A Provider may construct one HTTP
request, parse the response, validate the typed output, and report token counts.
It cannot access SQLAlchemy, Flutter SQLite, repositories, user permissions, or
result persistence.

DeepSeek uses `POST https://api.deepseek.com/chat/completions`, non-streaming
JSON Output, the deployment-selected model, a finite timeout, a maximum output
token limit, and no automatic retry. The existing Pydantic output model remains
the final authority; malformed, truncated, or schema-invalid JSON is rejected.

## Server Configuration

| Variable | Default | Purpose |
|---|---:|---|
| `REBIRTH_AI_PROVIDER` | `disabled` | `disabled`, `fake`, `deepseek`, or legacy `openai` |
| `REBIRTH_AI_MODEL` | none | Deployment-selected model, such as `deepseek-chat` |
| `DEEPSEEK_API_KEY` | none | DeepSeek credential, Server only |
| `REBIRTH_AI_TIMEOUT_SECONDS` | `90` | One paid request timeout |
| `REBIRTH_AI_MAX_OUTPUT_TOKENS` | `1600` | Output ceiling |
| `REBIRTH_AI_DAILY_USER_LIMIT` | `10` | UTC-day reservations per cloud user |
| `REBIRTH_AI_DAILY_GLOBAL_LIMIT` | `100` | UTC-day reservations across the deployment |
| `REBIRTH_AI_MAX_CONCURRENT_REQUESTS` | `5` | Active Provider reservations |

`deepseek` fails startup unless both `DEEPSEEK_API_KEY` and
`REBIRTH_AI_MODEL` are configured. `fake` remains development/test only.
`disabled` is the kill switch: generate endpoints return `ai_disabled` before
claiming usage or calling any Provider.

Secrets belong only in the Server environment or deployment secret store. Do
not place them in Flutter `--dart-define`, images, Compose files committed to
Git, databases, API responses, screenshots, diagnostics, or logs. The Settings
object excludes Provider keys from its representation.

## Cost Safety And Usage Ledger

`ai_usage_controls` contains one locking row. Every process locks that row before
counting the current UTC day and active leases, so PostgreSQL workers cannot
race past the configured limits. A successful reservation creates one
`ai_usage_records` row before the external request. Limit rejection returns
`usage_limit_reached` and makes no Provider call.

Usage records contain only account/request IDs, provider/model, request type,
nullable token counts, status, timestamps, and a bounded processing lease.
They never store prompts, Context DTO bodies, Journal/Health content, Provider
response bodies, rendered reports, API keys, or tokens. Provider failures still
count as reservations because an external request may already have incurred a
cost. Stale processing reservations become `expired` and no longer consume
concurrency.

The existing `ai_generation_requests` ledger still owns idempotency, temporary
result recovery, and `outcome_unknown`. Paid requests are never retried
automatically. A duplicate request ID replays or recovers the existing state
instead of reserving a second call.

## Controlled Errors

External failures are reduced to stable codes:

| Condition | Code |
|---|---|
| kill switch | `ai_disabled` |
| local quota or concurrency limit | `usage_limit_reached` |
| Provider 401/403 | `provider_auth_failed` |
| Provider 429 | `provider_rate_limited` |
| timeout | `provider_timeout` |
| network or Provider 5xx | `provider_unavailable` |
| invalid structured response | `response_invalid` |

No raw HTTP body, exception stack, credential, prompt, or model output is
returned to Flutter. Historical `gateway_disabled` and
`provider_authentication_failed` rows remain readable.

## Privacy Boundary

The Provider receives only the already minimized `ProviderPromptPayload`:
`report_type`, `prompt_version`, `period`, selected `scopes`, and selected
aggregated `data`. Source IDs, cloud identity, device/sync metadata, full
Journal text by default, Today priority/note text, and Health notes remain
excluded. The server prompt treats values as untrusted data and continues to
forbid diagnosis, causation, personality judgment, or deterministic advice.

## Deployment

Do not deploy automatically as part of this Sprint. After CI and manual review:

1. Back up the PostgreSQL deployment and confirm the current API image digest.
2. Add `DEEPSEEK_API_KEY` only to protected Server environment storage.
3. Set `REBIRTH_AI_PROVIDER=deepseek`, `REBIRTH_AI_MODEL`, and reviewed limits.
4. Pull the approved immutable API image.
5. Recreate only the API container. Do not restart PostgreSQL or delete volumes.
6. Confirm Alembic reaches `20260801_0007`, `/health` remains API `1` and Sync
   Protocol `2`, then execute the manual matrix.
7. Set `REBIRTH_AI_PROVIDER=disabled` and recreate only API for an immediate
   kill switch rollback. Keep the database migration in place.

The official DeepSeek API documentation describes the base URL and JSON Output
requirements: <https://api-docs.deepseek.com/guides/json_mode/>.

## Remaining Limits

Provider return and the final result commit are not one atomic transaction; a
crash can still produce `outcome_unknown`. Daily limits reset on the UTC natural
day, not the user's local date. Token counts are Provider-reported audit data,
not a billing invoice. Real-provider privacy, legal, retention, model-quality,
and pricing review remain required before production release.
