# AI Coach Conversation-first And Token Budget

> Sprint: **18B**
> Baseline: `a3325939c45a9b138b8f717448e394fb4ecd7930`
> Flutter schemaVersion: `15` (unchanged)
> API Version: `1` (unchanged)
> Sync Protocol: `2` (unchanged)
> Server Alembic revision: `20260822_0009`

## Product Flow

`/ai-coach` now opens the existing local conversation experience directly.
The compatibility path `/ai-coach/chat` redirects to the canonical route and
preserves query parameters. Android keeps a focused single-column view;
Windows keeps the existing wide thread-list and conversation layout.

The composer has three persistent responsive actions:

- `本次参考资料` controls only the next ordinary Chat turn.
- `生成今日洞察` starts the existing Daily Report pipeline for the current
  local calendar date.
- `生成每周回顾` starts the existing Weekly Report pipeline for the most
  recent seven local calendar dates.

Daily and Weekly each start with an independent empty selection. Their scope
picker explains privacy, Journal sensitivity, possible AI error, and that the
next canonical preview shows source count, Provider, and final confirmation.
Generation continues through `AiReportGenerationCoordinator`, report
persistence, version history, recovery, synchronization, and conflict
handling. A completed or archived report is projected back into Chat as a
link-like report reference. Its body is not copied into a Chat message and is
not automatically attached to later turns.

Chat threads remain account-scoped local data and do not synchronize. AI
Reports continue to use their existing cross-device synchronization path.

## Token Accounting

Chat no longer consumes the legacy per-user report request count. The Server
uses independent UTC-day token budgets:

| Scope | Configuration | Alpha default |
|---|---|---:|
| Chat | `REBIRTH_AI_CHAT_DAILY_TOKEN_LIMIT` | 50,000 |
| Daily/Weekly Reports | `REBIRTH_AI_REPORT_DAILY_TOKEN_LIMIT` | 50,000 |
| Deployment-wide total | `REBIRTH_AI_DAILY_GLOBAL_TOKEN_LIMIT` | 250,000 |
| Maximum reservation per request | `REBIRTH_AI_MAX_REQUEST_TOKENS` | 20,000 |

An estimate is reserved atomically before the Provider call. It includes the
governed instructions, bounded conversation/history or report payload, and the
configured maximum output. When Provider usage is available, settlement uses
`input_tokens + output_tokens` or the Provider total. If usage is absent, the
reserved conservative estimate is charged.

Known pre-Provider failures release the reservation. Local validation,
authorization, disabled Provider, and budget rejection create no usage charge.
Known Provider failures conservatively charge the reservation. Timeout or
outcome-unknown states retain the reservation until status confirmation or
lease expiry; expiry converts it once into a fallback charge. Idempotent replay
resolves through the existing Generation Ledger before reservation and cannot
charge twice.

`ai_usage_records` now has `reserved_tokens`, `charged_tokens`, and
`accounting_source`. No second accounting table exists. The existing
`ai_usage_controls` row remains the PostgreSQL serialization point for
multi-worker reservations.

## Usage APIs

`GET /ai/usage/me` remains the legacy report-count response for old clients.
Chat does not increment it. New clients use JWT-only `GET /ai/usage/me/v2`.
The V2 response contains separate Chat and Report token objects with `unit`,
`limit`, `used`, `reserved`, `remaining`, `availability`, and `resets_at`.
It ignores any query `user_id` and never exposes global budgets, another user,
request-level details, Prompt, content, credential, or secret.

The Flutter conversation page reads the Chat object and displays compact Token
usage plus an in-flight reservation indicator. Report generation reads the
Report object. Account changes rebuild both providers from the authenticated
account scope.

## Chinese Report Prompts

The active report prompts are `daily-insight-v3` and `weekly-report-v3`.
Their governed output fields remain strict JSON, while all user-visible title,
summary, observation, factor, suggestion, evidence explanation, and limitation
content must be Simplified Chinese.

Published v1 Prompt text and fingerprints were not edited. During the rollout,
the Server explicitly accepts v1 and v3 report requests; v2 remains rejected.
Capabilities advertise only active v3 contracts. Old reports retain their
original text and are never translated or regenerated automatically. Chat
continues to follow the user's current language under `coach-chat-v1`.

## Privacy And Safety

Opening Chat, changing any selection, viewing local history, opening a report,
or restoring a session does not call AI. No widget accesses Drift, a Server
implementation, or a Provider directly. Logs exclude Prompt text, Chat and
Report content, Journal/Health bodies, Authorization, API keys, secrets, and
full user identity.

Streaming, Chat Sync, agents, tools, search, attachments, voice, automatic
generation, background work, automatic retry, and business-record writes
remain out of scope.

## Deployment

The Candidate API image must be deployed before the new client. Run Alembic
upgrade to `20260822_0009`, then recreate only the API container. Do not restart
or clear PostgreSQL. Confirm `/health`, API Version `1`, Sync Protocol `2`, and
run `config-check`; it must show the four non-secret token controls.

Rollback of application code can continue to read the additive columns. A
database downgrade to `20260812_0008` is only for a reviewed rollback window;
it removes the three accounting columns and therefore must not be performed
while the 18B API is running.

## Sprint 18C Cleanup Register

After 18B deployment compatibility and client adoption are proven, Sprint 18C
must audit and remove only obsolete compatibility code:

- legacy Usage V1 and obsolete count-only configuration after a measured
  deprecation period;
- the old AI Coach overview widgets and no-longer-reachable composition;
- temporary `/ai-coach/chat` compatibility routing after deep-link evidence;
- v1 generation acceptance after old-client retirement.

Historical Prompt definitions, fingerprints, and report metadata must remain.
Sprint 18C must not delete old report content or rewrite ledger history.

## Release Gate

The **Conversation-first AI Coach, Token Budget And Chinese Report Gate** stays
**OPEN** until final Quality and image publication pass, the Candidate is
deployed with migration `20260822_0009`, Windows and Android releases are
tested, authorized real-Provider Chinese output is reviewed, and
`docs/manual_tests/65_ai_coach_conversation_first.md` is executed. Automated
evidence never becomes manual PASS.
