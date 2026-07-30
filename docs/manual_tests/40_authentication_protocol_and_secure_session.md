# Authentication Protocol And Secure Session Manual Matrix

## Test Rules

- Build and Server version: to be recorded by the tester.
- Do not include passwords, Dev User Keys, access tokens, refresh tokens,
  Authorization headers, Journal text, or Health notes in evidence.
- Automated tests do not count as manual PASS.
- Initial status of every item below is `NOT EXECUTED`.

## A. Existing Dev Account

| ID | Check | Status |
|---|---|---|
| A1 | Existing Dev Account can log in | NOT EXECUTED |
| A2 | CloudUser identity remains unchanged | NOT EXECUTED |
| A3 | Existing local data remains available | NOT EXECUTED |
| A4 | Existing five-module cloud data remains available | NOT EXECUTED |
| A5 | Session recovers after restart | NOT EXECUTED |
| A6 | Dev Key is never echoed | NOT EXECUTED |
| A7 | Normal Settings does not show Dev Key | NOT EXECUTED |
| A8 | Non-development configuration hides Dev Login | NOT EXECUTED |

## B. Secure Storage

| ID | Check | Status |
|---|---|---|
| B1 | Android Dev Login succeeds | NOT EXECUTED |
| B2 | Android restart preserves the session | NOT EXECUTED |
| B3 | Windows Dev Login succeeds | NOT EXECUTED |
| B4 | Windows restart preserves the session | NOT EXECUTED |
| B5 | Logout followed by restart stays signed out | NOT EXECUTED |
| B6 | Credentials are not visible in ordinary app files | NOT EXECUTED |
| B7 | Tokens are absent from Settings | NOT EXECUTED |
| B8 | Tokens are absent from logs | NOT EXECUTED |

## C. Refresh

| ID | Check | Status |
|---|---|---|
| C1 | A valid access token supports normal requests | NOT EXECUTED |
| C2 | Access expiry triggers one refresh | NOT EXECUTED |
| C3 | The original business request resumes once | NOT EXECUTED |
| C4 | Concurrent app work does not duplicate refresh | NOT EXECUTED |
| C5 | Network loss does not delete local business data | NOT EXECUTED |
| C6 | Definitive refresh failure enters invalid-session state | NOT EXECUTED |
| C7 | The old rotated refresh token cannot be reused | NOT EXECUTED |
| C8 | Revoked session cannot access Server APIs | NOT EXECUTED |

## D. Logout

| ID | Check | Status |
|---|---|---|
| D1 | Online logout succeeds | NOT EXECUTED |
| D2 | Client becomes signed out immediately | NOT EXECUTED |
| D3 | Restart remains signed out | NOT EXECUTED |
| D4 | The former session cannot access Server APIs | NOT EXECUTED |
| D5 | Local business data is retained | NOT EXECUTED |
| D6 | Another test session is unaffected | NOT EXECUTED |
| D7 | Offline logout still signs out locally | NOT EXECUTED |

## E. Dev Account Attach Password

| ID | Check | Status |
|---|---|---|
| E1 | Current Dev User can open Developer Options | NOT EXECUTED |
| E2 | Username/password binding form is available | NOT EXECUTED |
| E3 | Wrong Dev Key is rejected | NOT EXECUTED |
| E4 | Correct Dev Key attaches the identity | NOT EXECUTED |
| E5 | Existing CloudUser remains unchanged | NOT EXECUTED |
| E6 | Existing five-module data remains unchanged | NOT EXECUTED |
| E7 | Password API login returns the same CloudUser | NOT EXECUTED |
| E8 | Binding does not create a second account | NOT EXECUTED |
| E9 | Repeated binding is rejected | NOT EXECUTED |
| E10 | Username collision has a safe generic message | NOT EXECUTED |

## F. Legacy Session Upgrade

| ID | Check | Status |
|---|---|---|
| F1 | New client installs over the previous version | NOT EXECUTED |
| F2 | App data is not cleared during upgrade | NOT EXECUTED |
| F3 | Eligible legacy session migrates | NOT EXECUTED |
| F4 | Local data remains available | NOT EXECUTED |
| F5 | Cloud data remains available | NOT EXECUTED |
| F6 | New session can refresh | NOT EXECUTED |
| F7 | Legacy credential store is cleared after verified copy | NOT EXECUTED |
| F8 | Migration failure does not delete business data | NOT EXECUTED |

## G. Account Boundary

| ID | Check | Status |
|---|---|---|
| G1 | Sign in to Account A | NOT EXECUTED |
| G2 | Log out Account A | NOT EXECUTED |
| G3 | Sign in to independent Account B | NOT EXECUTED |
| G4 | B does not display A data | NOT EXECUTED |
| G5 | B does not display A conflicts | NOT EXECUTED |
| G6 | B cannot modify A data | NOT EXECUTED |
| G7 | Re-login Account A | NOT EXECUTED |
| G8 | A data becomes available again | NOT EXECUTED |
| G9 | Authenticated-offline access stays account scoped | NOT EXECUTED |
| G10 | Endpoint switch signs out without deleting data | NOT EXECUTED |

## H. Privacy

| ID | Check | Status |
|---|---|---|
| H1 | No password in logs | NOT EXECUTED |
| H2 | No Dev Key in logs | NOT EXECUTED |
| H3 | No access token in logs | NOT EXECUTED |
| H4 | No refresh token in logs | NOT EXECUTED |
| H5 | No Authorization header in logs | NOT EXECUTED |
| H6 | No password hash in response or logs | NOT EXECUTED |
| H7 | No Journal body in auth evidence | NOT EXECUTED |
| H8 | No Health body in auth evidence | NOT EXECUTED |
| H9 | Login errors do not enumerate accounts | NOT EXECUTED |
| H10 | Settings does not show internal IDs | NOT EXECUTED |

## I. Platform Smoke

| ID | Check | Status |
|---|---|---|
| I1 | Windows release starts | NOT EXECUTED |
| I2 | Windows secure storage works across restart | NOT EXECUTED |
| I3 | Android arm64 release starts | NOT EXECUTED |
| I4 | Android secure storage works across restart | NOT EXECUTED |
| I5 | Developer Options works at 320 px | NOT EXECUTED |
| I6 | Developer Options works at maximum text scale | NOT EXECUTED |
| I7 | Windows keyboard navigation works | NOT EXECUTED |
| I8 | Android Back works | NOT EXECUTED |
| I9 | No crash | NOT EXECUTED |
| I10 | No horizontal or RenderFlex overflow | NOT EXECUTED |

## Gate Status

- Authentication Protocol Gate: OPEN / MANUAL ACCEPTANCE REQUIRED
- Password Credential Security Gate: OPEN / MANUAL ACCEPTANCE REQUIRED
- Refresh Token Rotation Gate: OPEN / MANUAL ACCEPTANCE REQUIRED
- Secure Client Storage Gate: OPEN / MANUAL ACCEPTANCE REQUIRED
- Development Account Upgrade Gate: OPEN / MANUAL ACCEPTANCE REQUIRED
- Account Boundary Isolation Gate: CLOSED / ACCEPTED
- Public Login Experience Gate: OPEN / DEFERRED TO SPRINT 13A.2
- Public Account Recovery Gate: OPEN / DEFERRED
