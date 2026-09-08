# Sprint 18C Repository Consolidation & Legacy Surface Cleanup

> Matrix status: **CLOSED**
> Result: **8 PASS / 0 FAIL / 0 NOT EXECUTED**
> Scope: source-maintenance regression only; it introduces no product feature,
> Server deployment, schema, API, or Sync Protocol change.
>
> Manual acceptance recorded: **2026-09-08**
> Evaluated client source: **`1aed7dbf64cfa05d2cebd784af99fa36002e546b`**
> Evidence: user-executed Windows and Android regression matrix; all rows passed.

## Preconditions

- Use the exact Windows and Android client artifacts built from the final Sprint
  18C commit.
- Keep the existing authenticated account and local data. This matrix must not
  delete, reset, migrate, or synchronize data as part of verification.
- The API deployment is not part of this Sprint; use the already configured
  reachable endpoint.

## Maintenance Regression Matrix

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| A1 | Open AI Coach on Windows. | The canonical conversation page opens directly. | PASS | User-executed on the evaluated Sprint 18C client. |
| A2 | Open the legacy `/ai-coach/chat` entry where available. | It redirects to the same conversation without a loop. | PASS | User-executed compatibility-route regression check. |
| A3 | Edit Today research and learning duration values. | Direct input, add, clear, undo, and null/zero behavior remain usable. | PASS | User-executed; no old permanent Chip surface returned. |
| A4 | Edit Health sleep, exercise, and water values. | Direct input, add, clear, undo, and water display remain usable. | PASS | User-executed without a save or sync requirement. |
| A5 | Open Home in day and night appearance where supported. | The bundled background loads in both modes. | PASS | User-executed asset-path regression check. |
| A6 | In an Alpha/development build with developer login enabled, open Experience Preview. | Preview opens and its Home image loads. | PASS | User-executed developer-only route regression check. |
| A7 | In a production build with developer login disabled, inspect Settings. | Experience Preview is not reachable. | PASS | User-executed; no developer route leak observed. |
| A8 | Repeat the above on Android with normal and large text. | No crash, route loop, hidden primary action, or horizontal overflow. | PASS | User-executed Android normal and large-text regression check. |

## Gate Rule

Only the user may change a row to PASS or FAIL after real execution. Automated
tests are supporting evidence and never become manual PASS. This maintenance
matrix does not reopen the accepted Sprint 18B Conversation-first AI Coach Gate.

## Gate Decision

**CLOSED.** All required Sprint 18C maintenance regression rows passed on the
evaluated client source. Local automated evidence, release builds, and GitHub
Quality also passed for the same source commit. This decision introduces no API
deployment requirement because Sprint 18C did not modify Server code or images.
