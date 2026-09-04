# Rebirth Maintenance Backlog

> Classification: **Active maintenance planning**
> This is not authorization to remove compatibility code. Each item requires a
> separate reviewed Sprint, explicit rollback analysis, and relevant migration,
> Sync, authentication, export, and account-boundary regression evidence.

## Compatibility Retirement Ledger

| Boundary | Why it remains | Risk of removing now | Required retirement evidence |
|---|---|---|---|
| Journal legacy fixed fields and payload support | Old journal entries and Sync payloads can still be read while prompt items are the source of truth. | Historical entries or older clients could lose answers or fail synchronization. | Data migration/readback tests, a published minimum client version, historical export verification, and a defined rollback window. |
| Wellbeing 1-5 to 1-10 mapping | Existing local and synchronized records may use the earlier scale. | Charts and records could change meaning or become unreadable. | Migration/accounting plan, old-row fixture coverage, export/import-format decision, and cross-device compatibility cutoff. |
| Legacy secure auth-session migration | A prior SharedPreferences session can be upgraded into secure storage. | An upgrading user could lose a valid local session unexpectedly. | Evidence that supported old clients have passed the secure-store migration or an announced re-login cutoff. |
| AI generation request-binding V1 migration | Pending report generation bindings may exist in the earlier single-map layout. | Recovery could duplicate, abandon, or misattribute a pending report request. | Pending-recovery telemetry or expiry proof, migration fixture retention review, and an explicit compatibility cutoff. |
| `REBIRTH_API_BASE_URL` Dart define fallback | Older development and Alpha build commands may still use the legacy define. | Existing build scripts could silently target the wrong endpoint or fail to build. | All supported build guides and CI use `REBIRTH_SERVER_ENDPOINT`; a documented deprecation window has elapsed. |
| Legacy JWT migration | Controlled Server migration remains available only when explicitly enabled. | An authorized legacy-token rollout could become impossible or strand sessions. | Production configuration audit, expiry proof for legacy tokens, disabled migration window, and server rollback plan. |
| WeChat OAuth stub | The provider boundary fails closed because real WeChat login is suspended. | Future callers could receive an unclear failure or a security boundary could be removed before replacement exists. | An approved real-provider Sprint or a product decision to permanently remove WeChat identity routes and tests. |

## Deployment Configuration Fact

`AUTH_ACCESS_TOKEN_MINUTES` is the formal Server access-token lifetime
variable. `REBIRTH_ACCESS_TOKEN_MINUTES` is a compatibility fallback in current
Server configuration. Sprint 18C does not alter either runtime behavior,
deployment environment, or Server source. A future configuration-governance
Sprint should define a deprecation window and reject or safely report conflicting
values before removing the fallback.

## Deferred Structural Work

- Characterize Sync Adapter behavior before extracting only shared preflight,
  acknowledgement, and conflict-hydration helpers. Do not hide Today, Journal,
  Plan, Health, or AI Report semantics behind a monolithic adapter.
- Characterize AI Chat and Report coordinator invariants before extracting only
  shared request guards or binding lifecycle helpers.
- Split large Server services only after contract tests identify transaction and
  lock boundaries.
- Establish package versioning, dependency-lock, Windows release CI, and Android
  plugin compatibility policy in a dedicated release-engineering Sprint.
