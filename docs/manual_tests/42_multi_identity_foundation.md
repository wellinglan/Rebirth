# Sprint 13B.1 Multi Identity Foundation Manual Matrix

> Baseline: `794019847911ab4c5dbf5215e5b7ccb00364f70a`
> Automation is not manual evidence. All rows remain `NOT EXECUTED` until
> performed on the stated target.

## Preconditions

- Deploy the Sprint 13B.1 API migration and image.
- Confirm `/health` reports API Version `1` and Sync Protocol `2`.
- Build Windows and Android from the same Sprint commit.
- Prepare password accounts A and B with different usernames.
- Use the same server endpoint on both clients.
- Do not enter real passwords, tokens, or provider subjects in this document.

## A. Server Identity Contract

| ID | Procedure | Expected | Status |
|---|---|---|---|
| A1 | Register password account A | Registration succeeds and enters the same existing account flow | NOT EXECUTED |
| A2 | Log out, then log in again as A | Login succeeds; no new cloud account is created | NOT EXECUTED |
| A3 | Open account security while online | Username/password is shown as bound | NOT EXECUTED |
| A4 | Inspect the identity response with authorized developer tooling | Response contains provider, created time, and optional last-used time only | NOT EXECUTED |
| A5 | Inspect the same response for private fields | No identity ID, user ID, provider subject, password hash, token, or secret appears | NOT EXECUTED |
| A6 | Call identity discovery without authentication | Request is rejected with 401 | NOT EXECUTED |

## B. Windows

| ID | Procedure | Expected | Status |
|---|---|---|---|
| B1 | Log in as A and open Settings | Settings loads without regression | NOT EXECUTED |
| B2 | Select Account Security | Page opens and displays “登录方式” | NOT EXECUTED |
| B3 | Check username/password row | Row says “已绑定” with a bound indicator | NOT EXECUTED |
| B4 | Check WeChat row | Row says “后续版本开放” and cannot be activated | NOT EXECUTED |
| B5 | Resize from narrow to wide desktop | No overflow, clipped action, or unreadable label | NOT EXECUTED |
| B6 | Use Tab, Enter, Space, and Back | Navigation remains usable and disabled WeChat stays disabled | NOT EXECUTED |
| B7 | Restart the app while the session is valid | Account security still shows A's login method | NOT EXECUTED |

## C. Android

| ID | Procedure | Expected | Status |
|---|---|---|---|
| C1 | Log in as A and open Settings > Account Security | Page opens and matches the Windows identity state | NOT EXECUTED |
| C2 | Check username/password row | Row says “已绑定” | NOT EXECUTED |
| C3 | Check WeChat row | It is visible but disabled | NOT EXECUTED |
| C4 | Test portrait at normal font size | No horizontal or vertical layout overflow | NOT EXECUTED |
| C5 | Test maximum system font size | Text remains readable and page scrolls | NOT EXECUTED |
| C6 | Use Android Back | Returns safely to Settings | NOT EXECUTED |
| C7 | Restart the app while the session is valid | Identity display remains correct | NOT EXECUTED |

## D. Account Isolation

| ID | Procedure | Expected | Status |
|---|---|---|---|
| D1 | On Windows, note account A's identity display and local records | A shows only A's state and data space | NOT EXECUTED |
| D2 | Log out and log in as account B | B resolves its own Account Boundary | NOT EXECUTED |
| D3 | Open B's account-security page | B's identity state loads freshly; A's state is absent | NOT EXECUTED |
| D4 | Inspect B's business modules | A's local records are not visible | NOT EXECUTED |
| D5 | Switch back to A | A's original local profile and identity display return | NOT EXECUTED |
| D6 | Repeat A/B switch on Android | No identity or local data crosses accounts | NOT EXECUTED |

## E. Offline and Auth Gate

| ID | Procedure | Expected | Status |
|---|---|---|---|
| E1 | With a valid restored session, disconnect the server/network | App enters authenticated-offline behavior | NOT EXECUTED |
| E2 | Open Account Security offline | Current login method is shown from session state | NOT EXECUTED |
| E3 | Inspect the offline page | A note explains that only the current login method is shown | NOT EXECUTED |
| E4 | Restore connectivity and reload | Full server identity list returns | NOT EXECUTED |
| E5 | Log out, then deep-link or navigate to Account Security | Auth Gate redirects to public login | NOT EXECUTED |
| E6 | Press Back after logout redirect | Business or account-security content is not exposed | NOT EXECUTED |

## F. Regression and Privacy

| ID | Procedure | Expected | Status |
|---|---|---|---|
| F1 | Save local data in Profile, Plan, Today, Journal, and Health | Existing local save behavior is unchanged | NOT EXECUTED |
| F2 | Run each existing manual sync action once | Manual-only sync behavior is unchanged | NOT EXECUTED |
| F3 | Inspect sync status and conflicts | No cursor, OCC, conflict, or tombstone semantics changed | NOT EXECUTED |
| F4 | Confirm no sync starts after opening Account Security | Identity discovery does not trigger synchronization | NOT EXECUTED |
| F5 | Inspect client and server logs | No password, token, refresh token, provider subject, or secret is logged | NOT EXECUTED |
| F6 | Confirm product entry points | No usable WeChat, Apple, Google, auto-merge, or password-recovery flow exists | NOT EXECUTED |

## Result

- PASS: 0
- FAIL: 0
- NOT EXECUTED: 38
- Release Gate: OPEN pending Windows, Android, A/B account, offline, and privacy
  evidence.
