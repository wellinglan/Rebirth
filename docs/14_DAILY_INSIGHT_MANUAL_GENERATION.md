# Daily Insight Manual Generation

## User Flow

Daily Insight is an explicit, user-initiated flow:

```text
AI Coach / Today / Journal
-> /ai-coach/daily/:targetDate
-> explicit scopes
-> one-time Journal confirmation when selected
-> local buildDailyInsight Preview
-> source-count guard
-> Preview identity rebuild
-> typed capabilities and final confirmation
-> second identity rebuild
-> local pending -> Binding -> POST /ai/reports/daily/generate
-> completed / pending recovery / controlled failure
-> local History and Detail
```

Nothing runs when the page opens. Scope selection is not persisted, Journal confirmation is not persisted, and leaving then reopening the page starts with all scopes disabled.

## Date And State Identity

`AiInsightRequestContext` contains `reportType` and `targetDate` and has stable equality/hash semantics. Preview and generation use Riverpod families keyed by this object. The route date must be a valid `YYYY-MM-DD` local date; invalid input shows a safe error page. The route date never changes at midnight.

AI Coach uses the local date at click time. Today passes its displayed `recordDate`. Journal passes its displayed date and warns when form edits are unsaved; only Repository-saved Journal content can enter the Assembler.

## Selection And Preview

Daily permits `today_metrics`, `health_metrics`, and `journal_reflections`. Growth, Goals, and select-all are absent and rejected by the controller. Selected missing scopes remain visible as empty sections. `null` remains unrecorded and explicit `0` remains a real value.

When total `sourceCount` is zero, the page shows links to Today, Health, and Journal and does not mount the generation controller. Therefore it performs no capabilities request, creates no pending row, and calls no Provider.

## Final Confirmation And Integrity

The final dialog shows report type, target date, Provider, model, selected scopes, shortened hash, source count, result retention, dedupe retention, cost/no-retry warnings, and privacy boundaries. Journal content itself, canonical JSON, full hash, source IDs, credentials, and database paths are never shown.

The same date/selection is rebuilt before the dialog and before submit. Report type, period, prompt version, scopes, and input hash must match the reviewed Preview. A mismatch blocks pending, Binding, and POST and asks the user to inspect the refreshed Preview.

## Generation And Recovery

Dispatch is typed: Daily calls `generateDaily`; Weekly calls `generateWeekly`. After confirmation, the order remains `createPending -> save Binding -> POST`. A Binding failure marks a controlled local failure and sends no POST. Network uncertainty keeps pending/Binding and never retries POST automatically.

Daily recovery reuses the generic request identity and status GET. Completed, failed, processing, outcome-unknown, result-expired, not-found, endpoint mismatch, and account mismatch retain the existing reliability semantics. Consent revocation blocks new generation but not status recovery for a request already sent.

History mixes Daily and Weekly. Daily displays one date; Weekly displays a range. Detail remains read-only, offers Today/Journal source navigation for Daily, and never applies tomorrow adjustments automatically.

## Architecture Boundary

No Flutter or Server table, migration, binding schema, Daily input contract, fixture hash, Growth behavior, sync behavior, or source domain was changed. Flutter `schemaVersion` remains 3. AI reports remain local-only. Normal tests use Fake/Mock providers; real OpenAI is opt-in only.
