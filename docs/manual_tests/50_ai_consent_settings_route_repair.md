# Sprint 14A.4.1 AI Consent Settings Route Repair

Status: `NOT EXECUTED`

Baseline: `77e3c0b6e90c1dbdca20ec958118bfda62ef52e3`

This matrix verifies only the repaired Flutter consent route and state flow. It
does not prove real Provider operation and does not replace
`49_ai_operations_acceptance.md`. Do not record tokens, endpoints, User Keys,
prompts, Journal/Health content, or other private data as evidence.

## A. Navigation

| ID | Procedure | Expected | Result |
|---|---|---|---|
| A1 | Sign in with an account that has never granted AI consent and open Settings. | Settings loads normally. | NOT EXECUTED |
| A2 | Tap `AI 数据与隐私`. | `AI 数据与隐私` consent settings opens, not AI Coach. | NOT EXECUTED |
| A3 | Press Back. | Returns to Settings without changing consent. | NOT EXECUTED |
| A4 | Open AI Coach while consent is disabled and tap `前往 AI 授权设置`. | The same consent settings page opens directly; there is no Settings/AI Coach loop. | NOT EXECUTED |
| A5 | Press Back without granting. | Returns to AI Coach and generation remains unavailable. | NOT EXECUTED |

## B. Grant, Revoke, And Regrant

| ID | Procedure | Expected | Result |
|---|---|---|---|
| B1 | On consent settings, tap `允许 AI 使用个人数据`. | A confirmation dialog explains the data boundary; no AI request starts. | NOT EXECUTED |
| B2 | Cancel the confirmation. | Consent remains disabled and AI Coach remains blocked. | NOT EXECUTED |
| B3 | Confirm consent. | Status changes to enabled and a consent timestamp is shown. | NOT EXECUTED |
| B4 | Return to AI Coach. | Scope selection and preview controls are available; generation does not start automatically. | NOT EXECUTED |
| B5 | Return to consent settings and tap `撤销 AI 授权`, then confirm. | Status changes to disabled immediately. | NOT EXECUTED |
| B6 | Return to AI Coach. | Consent gate is restored and generation is unavailable. | NOT EXECUTED |
| B7 | Grant consent again. | Consent can be re-enabled and AI Coach becomes available after returning. | NOT EXECUTED |

## C. Persistence And Account Boundary

| ID | Procedure | Expected | Result |
|---|---|---|---|
| C1 | With consent enabled, fully close and restart the App, then sign in or restore the session. | The same account remains authorized. | NOT EXECUTED |
| C2 | Sign out Account A, sign in Account B that has never granted consent, and open AI Coach. | Account B is not authorized and does not inherit Account A consent. | NOT EXECUTED |
| C3 | Grant consent for Account B, then switch back to Account A. | Each account displays its own persisted consent state. | NOT EXECUTED |
| C4 | Revoke consent for one account and revisit the other account. | Revocation does not change the other account. | NOT EXECUTED |

## D. Compatibility And Accessibility

| ID | Procedure | Expected | Result |
|---|---|---|---|
| D1 | Complete A1-A5 and B1-B7 on Windows release. | Navigation, dialogs, actions, and Back behavior pass without errors. | NOT EXECUTED |
| D2 | Complete A1-A5 and B1-B7 on Android arm64 release. | Navigation, dialogs, actions, and Back behavior pass without errors. | NOT EXECUTED |
| D3 | Inspect the consent page at approximately 320, 360, and 412 logical pixels. | No horizontal overflow; status, copy, and action remain readable and tappable. | NOT EXECUTED |
| D4 | Set the largest supported system font or TextScaler 2.0 and repeat grant/revoke. | Content scrolls vertically with no clipped or hidden action. | NOT EXECUTED |
| D5 | On Windows, use Tab to focus and Enter/Space to activate the consent actions. | Focus order and keyboard activation remain usable. | NOT EXECUTED |

## E. Privacy And Regression

| ID | Procedure | Expected | Result |
|---|---|---|---|
| E1 | Review all consent page text, dialogs, and errors. | No token, API key, endpoint, User Key, prompt, Journal text, or Health text is displayed. | NOT EXECUTED |
| E2 | Grant and revoke consent while observing Today, Journal, Health, Plan, sync, and existing local AI reports. | No business record, sync state, or existing local report is deleted or changed. | NOT EXECUTED |
| E3 | Confirm versions after the client build. | Flutter schemaVersion 9, API Version 1, and Sync Protocol 2 remain unchanged. | NOT EXECUTED |

## Release Gate

- Sprint 14A.4.1 Consent UX Integrity Patch: `OPEN`
- Sprint 14A.4 AI Usage Audit Gate: `OPEN`
- Sprint 14A.4 AI Operation Safety Gate: `OPEN`

Close the patch gate only after all 24 rows pass. Then resume the remaining
manual execution in `49_ai_operations_acceptance.md`; this matrix alone does not
close either Sprint 14A.4 operations gate.
