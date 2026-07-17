# AI Generation Reliability

## Scope

Sprint 8D adds durable request identity, short-term result replay, and explicit pending reconciliation for the existing manual `weekly_report` flow. It adds no chat, streaming, background generation, scheduler, new report type, AIReport sync, Growth changes, or automatic Provider retry. Flutter `schemaVersion` remains 3.

## Reliability Contract

The Server uses `ai_generation_requests` with a unique `(user_id, request_id)` constraint. A new validated request atomically claims `processing`, commits its lease, and only then calls the Provider. The same user and request ID behaves as follows:

- same identity and completed result retained: replay the same validated result;
- different hash, report type, or prompt version: `409 idempotency_conflict`;
- active processing lease: `202 processing`, without a Provider call;
- stale processing lease: persist `outcome_unknown`, without a Provider call;
- failed: replay the same controlled failure, without a Provider call;
- completed output purged: `result_expired`, without a Provider call.

This is an at-most-once ownership guard for one Server database, not distributed exactly-once. Provider invocation and the completed database update are not atomic. If the Server crashes after Provider return but before the completed update, the request eventually becomes `outcome_unknown`. The Server cannot prove whether a result or cost occurred and never reuses that request ID for another Provider call.

## Ledger Data

The ledger stores request/user identity, input hash, report type, prompt version, status, safe Provider/model metadata, output schema version, controlled error code, timestamps, lease/retention timestamps, and temporarily the Server-rendered Markdown plus validated structured output.

It does not store input payloads, canonical JSON, sources, source record IDs, Journal text, Today/Health notes, Provider request bodies, raw Provider response objects, tokens, endpoint credentials, database paths, or API keys. Status responses omit `user_id` and another JWT user receives 404.

The output itself can contain an AI summary of sensitive selected data. It is retained for recovery, not as Server report history. Flutter local `ai_reports` remains the user-visible report history and source of truth.

## Retention

- `REBIRTH_AI_RESULT_RETENTION_HOURS=24`: validated output replay window.
- `REBIRTH_AI_DEDUPE_RETENTION_DAYS=30`: minimal tombstone window after output purge.
- `REBIRTH_AI_PROCESSING_LEASE_MINUTES=5`: processing ownership window.

AI request entry performs lazy cleanup. Result expiry clears Markdown and structured output and sets `result_purged_at`; request identity and hash remain until dedupe expiry. Dedupe expiry permits physical row deletion. There is no background cleanup scheduler.

Startup enforces a processing lease at least 30 seconds longer than Provider timeout, dedupe retention at least as long as result retention, and dedupe retention strictly longer than the lease. The maintenance CLI reuses the same cleanup core as lazy cleanup; it does not add a scheduler.

## Flutter Binding And Recovery

`AiGenerationRequestBindingStore` persists only local report ID, request ID, normalized endpoint, cloud user ID, input hash, report type, prompt version, and creation time in SharedPreferences. It contains no bundle, canonical JSON, Journal, token, or report body. Binding save occurs after local pending creation and before POST; failure marks the local report with `request_binding_failed` and sends no POST.

Terminal local completion/failure deletes the binding. A network timeout or connection loss is not a Provider timeout: the local report and binding remain pending and UI says the result is awaiting confirmation. Status recovery performs only `GET /ai/requests/{request_id}`. It never polls, retries POST, creates a request ID, or automatically regenerates.

The current endpoint and cloud user must match the binding. A mismatch sends no request and asks the user to switch back. Completed and failed statuses reconcile locally; processing remains pending; `outcome_unknown` and `result_expired` become controlled local failures. Not-found remains pending until the user explicitly confirms marking only the local report as `server_state_not_found`; that action does not generate again or delete source data.

Consent blocks new preview/generation and pending creation. Revoking Consent does not block status GET for a request already sent, because recovery sends no new business input and does not invoke the Provider.

## Production Limits

Production still requires HTTPS, encryption at rest, managed secrets, database access controls, retention enforcement/monitoring, backup and deletion procedures, incident observability without sensitive payload logging, provider/privacy/cost review, and legal review. The current SharedPreferences session and binding stores are development-level metadata storage, not secure credential storage.
