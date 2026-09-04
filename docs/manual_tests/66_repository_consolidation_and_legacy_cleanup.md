# Sprint 18C Repository Consolidation & Legacy Surface Cleanup

> Matrix status: **OPEN**
> Result: **0 PASS / 0 FAIL / 8 NOT EXECUTED**
> Scope: source-maintenance regression only; it introduces no product feature,
> Server deployment, schema, API, or Sync Protocol change.

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
| A1 | Open AI Coach on Windows. | The canonical conversation page opens directly. | NOT EXECUTED | Sprint 18B behavior must remain. |
| A2 | Open the legacy `/ai-coach/chat` entry where available. | It redirects to the same conversation without a loop. | NOT EXECUTED | Compatibility route remains supported. |
| A3 | Edit Today research and learning duration values. | Direct input, add, clear, undo, and null/zero behavior remain usable. | NOT EXECUTED | No old permanent Chip surface returns. |
| A4 | Edit Health sleep, exercise, and water values. | Direct input, add, clear, undo, and water display remain usable. | NOT EXECUTED | No data save or sync is required beyond ordinary existing behavior. |
| A5 | Open Home in day and night appearance where supported. | The bundled background loads in both modes. | NOT EXECUTED | Asset path changed only. |
| A6 | In an Alpha/development build with developer login enabled, open Experience Preview. | Preview opens and its Home image loads. | NOT EXECUTED | Developer-only route remains protected. |
| A7 | In a production build with developer login disabled, inspect Settings. | Experience Preview is not reachable. | NOT EXECUTED | No developer route leak. |
| A8 | Repeat the above on Android with normal and large text. | No crash, route loop, hidden primary action, or horizontal overflow. | NOT EXECUTED | Automated widget coverage supports responsive behavior. |

## Gate Rule

Only the user may change a row to PASS or FAIL after real execution. Automated
tests are supporting evidence and never become manual PASS. This maintenance
matrix does not reopen the accepted Sprint 18B Conversation-first AI Coach Gate.
