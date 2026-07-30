# Authentication Protocol And Secure Session Manual Matrix

## Test Rules

- Acceptance date: 2026-07-30.
- Evidence records only the user's real Windows and Android release execution.
- Passwords, Dev User Keys, tokens, Authorization headers, internal IDs, private
  module text, and private endpoints are excluded from evidence.
- Automated coverage does not convert a manual item into PASS.

## A. Existing Dev Account

| ID | Check | Status | Evidence |
|---|---|---|---|
| A1 | Existing Dev Account can log in | PASS | User acceptance, 2026-07-30 |
| A2 | CloudUser identity remains unchanged | PASS | User acceptance, 2026-07-30 |
| A3 | Existing local data remains available | PASS | User acceptance, 2026-07-30 |
| A4 | Existing five-module cloud data remains available | PASS | User acceptance, 2026-07-30 |
| A5 | Session recovers after restart | PASS | User acceptance, 2026-07-30 |
| A6 | Dev Key is never echoed | PASS | User acceptance, 2026-07-30 |
| A7 | Normal Settings does not show Dev Key | PASS | User acceptance, 2026-07-30 |
| A8 | Non-development configuration hides Dev Login | NOT EXECUTED | No non-development client build; carried to Sprint 13A.2 |

## B. Secure Storage

| ID | Check | Status | Evidence |
|---|---|---|---|
| B1 | Android Dev Login succeeds | PASS | Android release acceptance, 2026-07-30 |
| B2 | Android restart preserves the session | PASS | Android release acceptance, 2026-07-30 |
| B3 | Windows Dev Login succeeds | PASS | Windows release acceptance, 2026-07-30 |
| B4 | Windows restart preserves the session | PASS | Windows release acceptance, 2026-07-30 |
| B5 | Logout followed by restart stays signed out | PASS | User acceptance, 2026-07-30 |
| B6 | Credentials are not visible in ordinary app files | PASS | User acceptance, 2026-07-30 |
| B7 | Tokens are absent from Settings | PASS | User acceptance, 2026-07-30 |
| B8 | Tokens are absent from logs | PASS | User acceptance, 2026-07-30 |

## C. Refresh

| ID | Check | Status | Evidence |
|---|---|---|---|
| C1 | A valid access token supports normal requests | PASS | User acceptance, 2026-07-30 |
| C2 | Access expiry triggers one refresh | PASS | User acceptance, 2026-07-30 |
| C3 | The original business request resumes once | PASS | User acceptance, 2026-07-30 |
| C4 | Concurrent app work does not duplicate refresh | PASS | User acceptance, 2026-07-30 |
| C5 | Network loss does not delete local business data | PASS | User acceptance, 2026-07-30 |
| C6 | Definitive refresh failure enters invalid-session state | NOT EXECUTED | No safe product-level token fault injection |
| C7 | The old rotated refresh token cannot be reused | NOT EXECUTED | No safe product-level token reuse fixture |
| C8 | Revoked session cannot access Server APIs | NOT EXECUTED | No safe product-level revoked-session fixture |

## D. Logout

| ID | Check | Status | Evidence |
|---|---|---|---|
| D1 | Online logout succeeds | PASS | User acceptance, 2026-07-30 |
| D2 | Client becomes signed out immediately | PASS | User acceptance, 2026-07-30 |
| D3 | Restart remains signed out | PASS | User acceptance, 2026-07-30 |
| D4 | The former session cannot access Server APIs | PASS | User acceptance, 2026-07-30 |
| D5 | Local business data is retained | PASS | User acceptance, 2026-07-30 |
| D6 | Another test session is unaffected | PASS | User acceptance, 2026-07-30 |
| D7 | Offline logout still signs out locally | PASS | User acceptance, 2026-07-30 |

## E. Dev Account Attach Password

| ID | Check | Status | Evidence |
|---|---|---|---|
| E1 | Current Dev User can open Developer Options | PASS | User acceptance, 2026-07-30 |
| E2 | Username/password binding form is available | PASS | User acceptance, 2026-07-30 |
| E3 | Wrong Dev Key is rejected | PASS | User acceptance, 2026-07-30 |
| E4 | Correct Dev Key attaches the identity | PASS | User acceptance, 2026-07-30 |
| E5 | Existing CloudUser remains unchanged | PASS | User acceptance, 2026-07-30 |
| E6 | Existing five-module data remains unchanged | PASS | User acceptance, 2026-07-30 |
| E7 | Password API login returns the same CloudUser | PASS | User acceptance, 2026-07-30 |
| E8 | Binding does not create a second account | PASS | User acceptance, 2026-07-30 |
| E9 | Repeated binding is rejected | PASS | User acceptance, 2026-07-30 |
| E10 | Username collision has a safe generic message | PASS | User acceptance, 2026-07-30 |

## F. Legacy Session Upgrade

| ID | Check | Status | Evidence |
|---|---|---|---|
| F1 | New client installs over the previous version | NOT EXECUTED | No verifiable legacy-session sample |
| F2 | App data is not cleared during upgrade | NOT EXECUTED | No verifiable legacy-session sample |
| F3 | Eligible legacy session migrates | NOT EXECUTED | No verifiable legacy-session sample |
| F4 | Local data remains available | NOT EXECUTED | No verifiable legacy-session sample |
| F5 | Cloud data remains available | NOT EXECUTED | No verifiable legacy-session sample |
| F6 | New session can refresh | NOT EXECUTED | No verifiable legacy-session sample |
| F7 | Legacy credential store is cleared after verified copy | NOT EXECUTED | No verifiable legacy-session sample |
| F8 | Migration failure does not delete business data | NOT EXECUTED | No verifiable legacy-session sample |

## G. Account Boundary

| ID | Check | Status | Evidence |
|---|---|---|---|
| G1 | Sign in to Account A | PASS | User acceptance, 2026-07-30 |
| G2 | Log out Account A | PASS | User acceptance, 2026-07-30 |
| G3 | Sign in to independent Account B | PASS | User acceptance, 2026-07-30 |
| G4 | B does not display A data | PASS | User acceptance, 2026-07-30 |
| G5 | B does not display A conflicts | PASS | User acceptance, 2026-07-30 |
| G6 | B cannot modify A data | PASS | User acceptance, 2026-07-30 |
| G7 | Re-login Account A | PASS | User acceptance, 2026-07-30 |
| G8 | A data becomes available again | PASS | User acceptance, 2026-07-30 |
| G9 | Authenticated-offline access stays account scoped | PASS | User acceptance, 2026-07-30 |
| G10 | Endpoint switch signs out without deleting data | PASS | User acceptance, 2026-07-30 |

## H. Privacy

| ID | Check | Status | Evidence |
|---|---|---|---|
| H1 | No password in logs | PASS | User acceptance, 2026-07-30 |
| H2 | No Dev Key in logs | PASS | User acceptance, 2026-07-30 |
| H3 | No access token in logs | PASS | User acceptance, 2026-07-30 |
| H4 | No refresh token in logs | PASS | User acceptance, 2026-07-30 |
| H5 | No Authorization header in logs | PASS | User acceptance, 2026-07-30 |
| H6 | No password hash in response or logs | PASS | User acceptance, 2026-07-30 |
| H7 | No Journal body in auth evidence | PASS | User acceptance, 2026-07-30 |
| H8 | No Health body in auth evidence | PASS | User acceptance, 2026-07-30 |
| H9 | Login errors do not enumerate accounts | PASS | User acceptance, 2026-07-30 |
| H10 | Settings does not show internal IDs | PASS | User acceptance, 2026-07-30 |

## I. Platform Smoke

| ID | Check | Status | Evidence |
|---|---|---|---|
| I1 | Windows release starts | PASS | Windows release acceptance, 2026-07-30 |
| I2 | Windows secure storage works across restart | PASS | Windows release acceptance, 2026-07-30 |
| I3 | Android arm64 release starts | PASS | Android release acceptance, 2026-07-30 |
| I4 | Android secure storage works across restart | PASS | Android release acceptance, 2026-07-30 |
| I5 | Developer Options works at 320 px | PASS | User acceptance, 2026-07-30 |
| I6 | Developer Options works at maximum text scale | PASS | User acceptance, 2026-07-30 |
| I7 | Windows keyboard navigation works | PASS | Windows release acceptance, 2026-07-30 |
| I8 | Android Back works | PASS | Android release acceptance, 2026-07-30 |
| I9 | No crash | PASS | User acceptance, 2026-07-30 |
| I10 | No horizontal or RenderFlex overflow | PASS | User acceptance, 2026-07-30 |

## Result Summary

| Result | Count |
|---|---:|
| PASS | 67 |
| FAIL | 0 |
| NOT EXECUTED | 12 |

The 12 `NOT EXECUTED` rows are capability or fixture limitations, not failures
and not automated PASS results. A8 moves to Sprint 13A.2. C6-C8 retain automated
protocol and PostgreSQL coverage without being represented as manual execution.
F1-F8 remain unexecuted because no trustworthy legacy-session sample exists.
These limitations do not block Sprint 13A.2.

## Gate Status

- Authentication Protocol Gate: OPEN / CARRIED TO SPRINT 13A.2
- Password Credential Security Gate: OPEN / CARRIED TO SPRINT 13A.2
- Refresh Token Rotation Gate: CLOSED / ACCEPTED
- Secure Client Storage Gate: OPEN / CARRIED TO SPRINT 13A.2
- Development Account Upgrade Gate: CLOSED / ACCEPTED
- Account Boundary Isolation Gate: CLOSED / ACCEPTED
- Public Login Experience Gate: OPEN / DEFERRED TO SPRINT 13A.2
- Public Account Recovery Gate: OPEN / DEFERRED
- WeChat Login And Binding Gate: OPEN / DEFERRED TO SPRINT 13B
