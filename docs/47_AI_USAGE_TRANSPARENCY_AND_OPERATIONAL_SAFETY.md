# AI Usage Transparency And Operational Safety

## Scope

Sprint 14A.2 exposes the authenticated user's current AI allowance without
adding any AI capability. Daily Insight and Weekly Report remain explicit,
manual, synchronous actions. There is still no chat, agent, tool calling,
automatic generation, background task, AI Report sync, API version change, or
Sync Protocol change.

## User Usage Contract

`GET /ai/usage/me` requires the existing Rebirth JWT. The cloud user ID is
derived only from that JWT; the route accepts no `user_id` request field. The
strict response contains only:

```json
{
  "enabled": true,
  "status": "available",
  "daily_limit": 10,
  "used": 2,
  "remaining": 8,
  "resets_at": 1785628800000,
  "reset_timezone": "UTC"
}
```

`status` is one of `available`, `disabled`, or `limit_reached`. The response
never includes the deployment-global allowance, concurrency ceiling, another
user's usage, API keys, secrets, Authorization values, prompts, canonical
payloads, Journal or Health content, Provider responses, or report text.

The next reset is the next UTC natural-day boundary expressed as epoch
milliseconds. Flutter converts it only for local display and labels it as local
time. The quota itself does not reset at local midnight.

## Counting Semantics

The endpoint reads the existing `ai_usage_records` and `ai_usage_controls`
structures introduced in Sprint 14A.1. No new table or migration is added.

- A reservation is counted once before an external Provider call.
- Completed requests, Provider failures, and Provider timeouts count because
  the external request may already have incurred cost.
- A request rejected by the local disabled/quota/concurrency guard before
  reservation does not count.
- Replaying the same retained `request_id` reads the durable request state and
  does not create a second usage record.
- User counts are isolated by the JWT-derived cloud user ID.
- Global and concurrency controls can make generation temporarily unavailable,
  but their limits and counts are not disclosed to clients.

PostgreSQL remains the production consistency authority. The existing locking
control row and unique usage/request identities prevent workers from racing
past configured limits.

## Flutter States

Flutter maps the response to four presentation states:

| State | Behavior |
|---|---|
| Available | Shows used, remaining, daily limit, and reset time; generation remains enabled |
| Disabled | Shows the Server kill-switch state and disables generation |
| Limit reached | Shows the exhausted/unavailable allowance and disables generation |
| Unknown | Shows a restrained fallback; the Server remains authoritative if the user attempts generation |

Usage loads with the generation section, is checked again before final
confirmation, and refreshes after every submitted generation outcome. A usage
query failure never discards the local Preview or report history. Windows,
Android portrait, 320px width, and `TextScaler 2.0` use the same unframed,
wrapping summary.

## Security And Logging

The usage route performs aggregate metadata reads only. Existing AI logs remain
allowlisted and must not contain API keys, secrets, JWT/Authorization values,
prompts, canonical payloads, Journal/Today/Health text, Provider response bodies,
or report content. The response schema rejects additional Server fields, and
Flutter rejects unknown or internally inconsistent usage responses.

## Compatibility

- API Version remains `1`.
- Sync Protocol remains `2`.
- Flutter Drift `schemaVersion` remains `9`.
- No Server Alembic revision is added.
- AI Reports remain local-only and are not synchronized.

## Remaining Limits

Usage is a reservation count, not a Provider invoice or token-cost estimate.
Provider billing may differ. A global or concurrency block is intentionally
represented without disclosing deployment-wide values. Unknown client state is
fail-soft for usability, while every generation endpoint remains fail-closed
and performs the authoritative Server check.

## Sprint 18B Succession

The V1 response above remains available as a temporary Report-count
compatibility contract. Sprint 18B adds JWT-only `/ai/usage/me/v2`, independent
Chat and Report total-Token budgets, atomic `reserved_tokens`, settled
`charged_tokens`, and UTC reset metadata. Chat no longer increments V1 request
counts. The current client uses V2 and displays aggregate Token usage; it still
cannot see global budgets or request-level/content details. See
`docs/60_AI_COACH_CONVERSATION_FIRST_AND_TOKEN_BUDGET.md`.
