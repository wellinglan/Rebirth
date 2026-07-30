# Sprint 13A.2 Public Username/Password Login Manual Matrix

> Status: CLOSED / ACCEPTED
> Automated tests and builds do not count as manual PASS.
> Do not record usernames, passwords, tokens, Session IDs, device serials, or
> private endpoints as evidence.
>
> User acceptance on 2026-07-30 recorded 107 PASS, 0 FAIL, and 7 NOT
> EXECUTED. H1-H7 remain NOT EXECUTED because no safe unbound-legacy-data
> fixture was available; this is not converted to PASS.

Use separate Production and Alpha release builds on Windows and Android. Begin
with existing local and cloud data intact. Do not clear databases, cursors,
conflicts, or serverVersion to make a case easier to execute.

## A. Production Build

| ID | Check | Result | Evidence |
|---|---|---|---|
| A1 | Production Windows release builds and starts | PASS | User acceptance 2026-07-30 |
| A2 | Production Android arm64 release installs and starts | PASS | User acceptance 2026-07-30 |
| A3 | Public Login is visible | PASS | User acceptance 2026-07-30 |
| A4 | Public Register is visible | PASS | User acceptance 2026-07-30 |
| A5 | Developer Login is not visible | PASS | User acceptance 2026-07-30 |
| A6 | Developer Options contains no Dev Login | PASS | User acceptance 2026-07-30 |
| A7 | Deep link cannot enter Developer Login | PASS | User acceptance 2026-07-30 |
| A8 | Alpha badge is absent | PASS | User acceptance 2026-07-30 |
| A9 | Normal pages expose no endpoint | PASS | User acceptance 2026-07-30 |
| A10 | Normal pages expose no internal account/session ID | PASS | User acceptance 2026-07-30 |

## B. Alpha Build

| ID | Check | Result | Evidence |
|---|---|---|---|
| B1 | Public Login is visible | PASS | User acceptance 2026-07-30 |
| B2 | Public Register is visible | PASS | User acceptance 2026-07-30 |
| B3 | Alpha badge is visible | PASS | User acceptance 2026-07-30 |
| B4 | Developer entry is low priority and clearly marked | PASS | User acceptance 2026-07-30 |
| B5 | Developer Login can authenticate | PASS | User acceptance 2026-07-30 |
| B6 | Public Login does not show a Dev Key field | PASS | User acceptance 2026-07-30 |
| B7 | Dev Key is never echoed after submission | PASS | User acceptance 2026-07-30 |
| B8 | Developer Login preserves the correct local account data | PASS | User acceptance 2026-07-30 |

## C. Registration

| ID | Check | Result | Evidence |
|---|---|---|---|
| C1 | Register a new valid username | PASS | User acceptance 2026-07-30 |
| C2 | Register with a valid password | PASS | User acceptance 2026-07-30 |
| C3 | Optional display name is accepted | PASS | User acceptance 2026-07-30 |
| C4 | Success enters the App without another login | PASS | User acceptance 2026-07-30 |
| C5 | A separate local data space is created | PASS | User acceptance 2026-07-30 |
| C6 | Registration does not start synchronization | PASS | User acceptance 2026-07-30 |
| C7 | Restart restores the secure session | PASS | User acceptance 2026-07-30 |
| C8 | Duplicate username shows unavailable feedback | PASS | User acceptance 2026-07-30 |
| C9 | Short password is rejected | PASS | User acceptance 2026-07-30 |
| C10 | Mismatched confirmation is rejected | PASS | User acceptance 2026-07-30 |
| C11 | Network error is understandable and safe | PASS | User acceptance 2026-07-30 |
| C12 | Repeated taps issue only one registration | PASS | User acceptance 2026-07-30 |
| C13 | Failure creates no incorrect local binding | PASS | User acceptance 2026-07-30 |

## D. Login

| ID | Check | Result | Evidence |
|---|---|---|---|
| D1 | Existing username can log in | PASS | User acceptance 2026-07-30 |
| D2 | Correct password succeeds | PASS | User acceptance 2026-07-30 |
| D3 | Correct account-scoped local space opens | PASS | User acceptance 2026-07-30 |
| D4 | Incorrect password is rejected | PASS | User acceptance 2026-07-30 |
| D5 | Unknown username is rejected | PASS | User acceptance 2026-07-30 |
| D6 | D4 and D5 show exactly the same message | PASS | User acceptance 2026-07-30 |
| D7 | Network and credential errors are distinguishable | PASS | User acceptance 2026-07-30 |
| D8 | Rate-limit feedback is understandable | PASS | User acceptance 2026-07-30 |
| D9 | Password visibility works and is readable | PASS | User acceptance 2026-07-30 |
| D10 | Enter submits once | PASS | User acceptance 2026-07-30 |
| D11 | Repeated taps create no duplicate session | PASS | User acceptance 2026-07-30 |
| D12 | Failure preserves all local business data | PASS | User acceptance 2026-07-30 |

## E. Session Restore

| ID | Check | Result | Evidence |
|---|---|---|---|
| E1 | Windows restarts after login | PASS | User acceptance 2026-07-30 |
| E2 | Windows session restores | PASS | User acceptance 2026-07-30 |
| E3 | Android restarts after login | PASS | User acceptance 2026-07-30 |
| E4 | Android session restores | PASS | User acceptance 2026-07-30 |
| E5 | Access Token is absent from normal files | PASS | User acceptance 2026-07-30 |
| E6 | Offline startup enters offline use when trusted | PASS | User acceptance 2026-07-30 |
| E7 | Local data remains readable offline | PASS | User acceptance 2026-07-30 |
| E8 | Sync remains unavailable offline | PASS | User acceptance 2026-07-30 |
| E9 | Network restoration recovers a valid session | PASS | User acceptance 2026-07-30 |
| E10 | Definitive invalidation returns to Login | PASS | User acceptance 2026-07-30 |
| E11 | Previous account content never flashes during bootstrap | PASS | User acceptance 2026-07-30 |

## F. Logout

| ID | Check | Result | Evidence |
|---|---|---|---|
| F1 | Online logout completes | PASS | User acceptance 2026-07-30 |
| F2 | Logout returns to Public Login | PASS | User acceptance 2026-07-30 |
| F3 | Back cannot return to protected content | PASS | User acceptance 2026-07-30 |
| F4 | Restart remains signed out | PASS | User acceptance 2026-07-30 |
| F5 | Local business data is retained | PASS | User acceptance 2026-07-30 |
| F6 | Cloud data is retained | PASS | User acceptance 2026-07-30 |
| F7 | Offline logout is locally authoritative | PASS | User acceptance 2026-07-30 |
| F8 | Other local account spaces are unaffected | PASS | User acceptance 2026-07-30 |

## G. A/B Account Isolation

| ID | Check | Result | Evidence |
|---|---|---|---|
| G1 | Register or log in Account A | PASS | User acceptance 2026-07-30 |
| G2 | Create local data for A | PASS | User acceptance 2026-07-30 |
| G3 | Log out A | PASS | User acceptance 2026-07-30 |
| G4 | Log in Account B | PASS | User acceptance 2026-07-30 |
| G5 | B cannot see A Profile | PASS | User acceptance 2026-07-30 |
| G6 | B cannot see A Today | PASS | User acceptance 2026-07-30 |
| G7 | B cannot see A Journal | PASS | User acceptance 2026-07-30 |
| G8 | B cannot see A Health | PASS | User acceptance 2026-07-30 |
| G9 | B cannot see A conflicts | PASS | User acceptance 2026-07-30 |
| G10 | B cannot see A Sync Center state | PASS | User acceptance 2026-07-30 |
| G11 | Log out B | PASS | User acceptance 2026-07-30 |
| G12 | Log A in again | PASS | User acceptance 2026-07-30 |
| G13 | A local data is restored | PASS | User acceptance 2026-07-30 |
| G14 | B data does not enter A | PASS | User acceptance 2026-07-30 |

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
| I1 | UI displays no Token | PASS | User acceptance 2026-07-30 |
| I2 | UI displays no Session ID | PASS | User acceptance 2026-07-30 |
| I3 | UI displays no CloudUser ID | PASS | User acceptance 2026-07-30 |
| I4 | UI displays no provider subject | PASS | User acceptance 2026-07-30 |
| I5 | Logs contain no Password | PASS | User acceptance 2026-07-30 |
| I6 | Logs contain no Access Token | PASS | User acceptance 2026-07-30 |
| I7 | Logs contain no Refresh Token | PASS | User acceptance 2026-07-30 |
| I8 | SharedPreferences contains no Password | PASS | User acceptance 2026-07-30 |
| I9 | SharedPreferences contains no Access Token | PASS | User acceptance 2026-07-30 |
| I10 | Drift contains no Password or Token | PASS | User acceptance 2026-07-30 |
| I11 | Error text contains no HTTP code | PASS | User acceptance 2026-07-30 |
| I12 | Login error does not enumerate accounts | PASS | User acceptance 2026-07-30 |
| I13 | Authentication logs contain no Journal or Health body | PASS | User acceptance 2026-07-30 |

## J. UI And Accessibility

| ID | Check | Result | Evidence |
|---|---|---|---|
| J1 | 320px layout is usable | PASS | User acceptance 2026-07-30 |
| J2 | 360px layout is usable | PASS | User acceptance 2026-07-30 |
| J3 | 412px layout is usable | PASS | User acceptance 2026-07-30 |
| J4 | Maximum font size is usable | PASS | User acceptance 2026-07-30 |
| J5 | Narrow Windows layout is usable | PASS | User acceptance 2026-07-30 |
| J6 | Wide Windows layout is usable | PASS | User acceptance 2026-07-30 |
| J7 | Tab navigation is logical | PASS | User acceptance 2026-07-30 |
| J8 | Shift+Tab navigation is logical | PASS | User acceptance 2026-07-30 |
| J9 | Enter submits once | PASS | User acceptance 2026-07-30 |
| J10 | Escape closes dialogs | PASS | User acceptance 2026-07-30 |
| J11 | Android Back is safe | PASS | User acceptance 2026-07-30 |
| J12 | Software keyboard does not hide required controls | PASS | User acceptance 2026-07-30 |
| J13 | Pages remain scrollable | PASS | User acceptance 2026-07-30 |
| J14 | Password visibility semantics are understandable | PASS | User acceptance 2026-07-30 |
| J15 | Status is not communicated by color alone | PASS | User acceptance 2026-07-30 |
| J16 | No RenderFlex overflow occurs | PASS | User acceptance 2026-07-30 |
| J17 | No crash occurs | PASS | User acceptance 2026-07-30 |
| J18 | Busy state is understandable and prevents duplicates | PASS | User acceptance 2026-07-30 |

## Summary

| Result | Count |
|---|---:|
| PASS | 107 |
| FAIL | 0 |
| NOT EXECUTED | 7 |

## Gates

- Public Login Experience Gate: CLOSED / ACCEPTED
- Authentication Protocol Gate: CLOSED / ACCEPTED
- Password Credential Security Gate: CLOSED / ACCEPTED
- Secure Client Storage Gate: CLOSED / ACCEPTED
- Refresh Token Rotation Gate: CLOSED / ACCEPTED
- Development Account Upgrade Gate: CLOSED / ACCEPTED
- Account Boundary Isolation Gate: CLOSED / ACCEPTED
- Public Account Recovery Gate: OPEN / DEFERRED
- WeChat Login And Binding Gate: OPEN / DEFERRED TO SPRINT 13B
