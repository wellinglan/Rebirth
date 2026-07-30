# Sprint 13A.2 Public Username/Password Login Manual Matrix

> Status: OPEN / MANUAL ACCEPTANCE REQUIRED
> Automated tests and builds do not count as manual PASS.
> Do not record usernames, passwords, tokens, Session IDs, device serials, or
> private endpoints as evidence.

Use separate Production and Alpha release builds on Windows and Android. Begin
with existing local and cloud data intact. Do not clear databases, cursors,
conflicts, or serverVersion to make a case easier to execute.

## A. Production Build

| ID | Check | Result | Evidence |
|---|---|---|---|
| A1 | Production Windows release builds and starts | NOT EXECUTED | |
| A2 | Production Android arm64 release installs and starts | NOT EXECUTED | |
| A3 | Public Login is visible | NOT EXECUTED | |
| A4 | Public Register is visible | NOT EXECUTED | |
| A5 | Developer Login is not visible | NOT EXECUTED | |
| A6 | Developer Options contains no Dev Login | NOT EXECUTED | |
| A7 | Deep link cannot enter Developer Login | NOT EXECUTED | |
| A8 | Alpha badge is absent | NOT EXECUTED | |
| A9 | Normal pages expose no endpoint | NOT EXECUTED | |
| A10 | Normal pages expose no internal account/session ID | NOT EXECUTED | |

## B. Alpha Build

| ID | Check | Result | Evidence |
|---|---|---|---|
| B1 | Public Login is visible | NOT EXECUTED | |
| B2 | Public Register is visible | NOT EXECUTED | |
| B3 | Alpha badge is visible | NOT EXECUTED | |
| B4 | Developer entry is low priority and clearly marked | NOT EXECUTED | |
| B5 | Developer Login can authenticate | NOT EXECUTED | |
| B6 | Public Login does not show a Dev Key field | NOT EXECUTED | |
| B7 | Dev Key is never echoed after submission | NOT EXECUTED | |
| B8 | Developer Login preserves the correct local account data | NOT EXECUTED | |

## C. Registration

| ID | Check | Result | Evidence |
|---|---|---|---|
| C1 | Register a new valid username | NOT EXECUTED | |
| C2 | Register with a valid password | NOT EXECUTED | |
| C3 | Optional display name is accepted | NOT EXECUTED | |
| C4 | Success enters the App without another login | NOT EXECUTED | |
| C5 | A separate local data space is created | NOT EXECUTED | |
| C6 | Registration does not start synchronization | NOT EXECUTED | |
| C7 | Restart restores the secure session | NOT EXECUTED | |
| C8 | Duplicate username shows unavailable feedback | NOT EXECUTED | |
| C9 | Short password is rejected | NOT EXECUTED | |
| C10 | Mismatched confirmation is rejected | NOT EXECUTED | |
| C11 | Network error is understandable and safe | NOT EXECUTED | |
| C12 | Repeated taps issue only one registration | NOT EXECUTED | |
| C13 | Failure creates no incorrect local binding | NOT EXECUTED | |

## D. Login

| ID | Check | Result | Evidence |
|---|---|---|---|
| D1 | Existing username can log in | NOT EXECUTED | |
| D2 | Correct password succeeds | NOT EXECUTED | |
| D3 | Correct account-scoped local space opens | NOT EXECUTED | |
| D4 | Incorrect password is rejected | NOT EXECUTED | |
| D5 | Unknown username is rejected | NOT EXECUTED | |
| D6 | D4 and D5 show exactly the same message | NOT EXECUTED | |
| D7 | Network and credential errors are distinguishable | NOT EXECUTED | |
| D8 | Rate-limit feedback is understandable | NOT EXECUTED | |
| D9 | Password visibility works and is readable | NOT EXECUTED | |
| D10 | Enter submits once | NOT EXECUTED | |
| D11 | Repeated taps create no duplicate session | NOT EXECUTED | |
| D12 | Failure preserves all local business data | NOT EXECUTED | |

## E. Session Restore

| ID | Check | Result | Evidence |
|---|---|---|---|
| E1 | Windows restarts after login | NOT EXECUTED | |
| E2 | Windows session restores | NOT EXECUTED | |
| E3 | Android restarts after login | NOT EXECUTED | |
| E4 | Android session restores | NOT EXECUTED | |
| E5 | Access Token is absent from normal files | NOT EXECUTED | |
| E6 | Offline startup enters offline use when trusted | NOT EXECUTED | |
| E7 | Local data remains readable offline | NOT EXECUTED | |
| E8 | Sync remains unavailable offline | NOT EXECUTED | |
| E9 | Network restoration recovers a valid session | NOT EXECUTED | |
| E10 | Definitive invalidation returns to Login | NOT EXECUTED | |
| E11 | Previous account content never flashes during bootstrap | NOT EXECUTED | |

## F. Logout

| ID | Check | Result | Evidence |
|---|---|---|---|
| F1 | Online logout completes | NOT EXECUTED | |
| F2 | Logout returns to Public Login | NOT EXECUTED | |
| F3 | Back cannot return to protected content | NOT EXECUTED | |
| F4 | Restart remains signed out | NOT EXECUTED | |
| F5 | Local business data is retained | NOT EXECUTED | |
| F6 | Cloud data is retained | NOT EXECUTED | |
| F7 | Offline logout is locally authoritative | NOT EXECUTED | |
| F8 | Other local account spaces are unaffected | NOT EXECUTED | |

## G. A/B Account Isolation

| ID | Check | Result | Evidence |
|---|---|---|---|
| G1 | Register or log in Account A | NOT EXECUTED | |
| G2 | Create local data for A | NOT EXECUTED | |
| G3 | Log out A | NOT EXECUTED | |
| G4 | Log in Account B | NOT EXECUTED | |
| G5 | B cannot see A Profile | NOT EXECUTED | |
| G6 | B cannot see A Today | NOT EXECUTED | |
| G7 | B cannot see A Journal | NOT EXECUTED | |
| G8 | B cannot see A Health | NOT EXECUTED | |
| G9 | B cannot see A conflicts | NOT EXECUTED | |
| G10 | B cannot see A Sync Center state | NOT EXECUTED | |
| G11 | Log out B | NOT EXECUTED | |
| G12 | Log A in again | NOT EXECUTED | |
| G13 | A local data is restored | NOT EXECUTED | |
| G14 | B data does not enter A | NOT EXECUTED | |

## H. Binding Required

| ID | Check | Result | Evidence |
|---|---|---|---|
| H1 | Device has unbound legacy local data | NOT EXECUTED | |
| H2 | Log in a new public account | NOT EXECUTED | |
| H3 | Legacy data is not inherited automatically | NOT EXECUTED | |
| H4 | Ownership review opens | NOT EXECUTED | |
| H5 | Cancel modifies no data | NOT EXECUTED | |
| H6 | Ownership changes only after explicit confirmation | NOT EXECUTED | |
| H7 | Account isolation remains intact | NOT EXECUTED | |

Keep cases that cannot be safely constructed as `NOT EXECUTED`.

## I. Privacy

| ID | Check | Result | Evidence |
|---|---|---|---|
| I1 | UI displays no Token | NOT EXECUTED | |
| I2 | UI displays no Session ID | NOT EXECUTED | |
| I3 | UI displays no CloudUser ID | NOT EXECUTED | |
| I4 | UI displays no provider subject | NOT EXECUTED | |
| I5 | Logs contain no Password | NOT EXECUTED | |
| I6 | Logs contain no Access Token | NOT EXECUTED | |
| I7 | Logs contain no Refresh Token | NOT EXECUTED | |
| I8 | SharedPreferences contains no Password | NOT EXECUTED | |
| I9 | SharedPreferences contains no Access Token | NOT EXECUTED | |
| I10 | Drift contains no Password or Token | NOT EXECUTED | |
| I11 | Error text contains no HTTP code | NOT EXECUTED | |
| I12 | Login error does not enumerate accounts | NOT EXECUTED | |
| I13 | Authentication logs contain no Journal or Health body | NOT EXECUTED | |

## J. UI And Accessibility

| ID | Check | Result | Evidence |
|---|---|---|---|
| J1 | 320px layout is usable | NOT EXECUTED | |
| J2 | 360px layout is usable | NOT EXECUTED | |
| J3 | 412px layout is usable | NOT EXECUTED | |
| J4 | Maximum font size is usable | NOT EXECUTED | |
| J5 | Narrow Windows layout is usable | NOT EXECUTED | |
| J6 | Wide Windows layout is usable | NOT EXECUTED | |
| J7 | Tab navigation is logical | NOT EXECUTED | |
| J8 | Shift+Tab navigation is logical | NOT EXECUTED | |
| J9 | Enter submits once | NOT EXECUTED | |
| J10 | Escape closes dialogs | NOT EXECUTED | |
| J11 | Android Back is safe | NOT EXECUTED | |
| J12 | Software keyboard does not hide required controls | NOT EXECUTED | |
| J13 | Pages remain scrollable | NOT EXECUTED | |
| J14 | Password visibility semantics are understandable | NOT EXECUTED | |
| J15 | Status is not communicated by color alone | NOT EXECUTED | |
| J16 | No RenderFlex overflow occurs | NOT EXECUTED | |
| J17 | No crash occurs | NOT EXECUTED | |
| J18 | Busy state is understandable and prevents duplicates | NOT EXECUTED | |

## Summary

| Result | Count |
|---|---:|
| PASS | 0 |
| FAIL | 0 |
| NOT EXECUTED | 114 |

## Gates

- Public Login Experience Gate: OPEN / MANUAL ACCEPTANCE REQUIRED
- Authentication Protocol Gate: OPEN / MANUAL ACCEPTANCE REQUIRED
- Password Credential Security Gate: OPEN / MANUAL ACCEPTANCE REQUIRED
- Secure Client Storage Gate: OPEN / MANUAL ACCEPTANCE REQUIRED
- Refresh Token Rotation Gate: CLOSED / ACCEPTED
- Development Account Upgrade Gate: CLOSED / ACCEPTED
- Account Boundary Isolation Gate: CLOSED / ACCEPTED
- Public Account Recovery Gate: OPEN / DEFERRED
- WeChat Login And Binding Gate: OPEN / DEFERRED TO SPRINT 13B
