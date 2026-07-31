# Sprint 13B.2 WeChat Identity Foundation Manual Matrix

> Baseline: `69f12c5b044615e347684f902309c25d0c2b6a15`
> Automation is not manual evidence. All rows remain `NOT EXECUTED` until
> performed on the stated target.

## Preconditions

- Deploy the Sprint 13B.2 API image after GitHub Quality passes.
- Confirm `/health` reports API Version `1` and Sync Protocol `2`.
- Build Windows and Android from the same Sprint commit.
- Prepare password accounts A and B with different usernames.
- Use the same normalized server endpoint on both clients.
- Do not place real passwords, tokens, provider subjects, Open IDs, or Union
  IDs in this document, screenshots, or logs.
- Real WeChat OAuth is intentionally unavailable in this Sprint.

## A. Identity Display

| ID | Procedure | Expected | Status |
|---|---|---|---|
| A1 | Log in with password and open Settings > Account Security | Username/password is shown as bound | NOT EXECUTED |
| A2 | In an eligible Alpha build, log in with a developer identity and open Account Security | Developer identity is shown as bound | NOT EXECUTED |
| A3 | Inspect the WeChat row for an account without WeChat | WeChat is shown as unbound with a binding entry | NOT EXECUTED |
| A4 | Inspect a test account seeded with a safe bound WeChat identity | WeChat is shown as bound and has no duplicate binding action | NOT EXECUTED |
| A5 | Restart while the session remains valid | The identity list reloads for the same account | NOT EXECUTED |

## B. Binding Boundary

| ID | Procedure | Expected | Status |
|---|---|---|---|
| B1 | Log out, then try to navigate directly to Account Security | Auth Gate redirects to public login; binding is unavailable | NOT EXECUTED |
| B2 | Log in online and select the WeChat binding entry | A confirmation explains reauthentication and server verification | NOT EXECUTED |
| B3 | Cancel the confirmation | No request is completed and identity state is unchanged | NOT EXECUTED |
| B4 | Confirm the binding entry | The current release reports that WeChat binding is not configured | NOT EXECUTED |
| B5 | Tap the action repeatedly while the request is active | Only one request is active and the action cannot be duplicated | NOT EXECUTED |
| B6 | Disconnect the server, restore an offline session, and open Account Security | WeChat binding is disabled with an offline explanation | NOT EXECUTED |
| B7 | Restore connectivity and reload | Full identity state returns without starting sync or binding automatically | NOT EXECUTED |

## C. Account Isolation

| ID | Procedure | Expected | Status |
|---|---|---|---|
| C1 | Record account A's identity list and local Profile/Plan/Today/Journal/Health data | A shows only A's identity and data space | NOT EXECUTED |
| C2 | Log out and log in as account B | B resolves its own Account Boundary and identity list | NOT EXECUTED |
| C3 | Attempt to bind a provider identity already owned by A using a controlled server test fixture | Binding is rejected without identifying A | NOT EXECUTED |
| C4 | Reopen B's business modules after the rejection | A's local or cloud data is not visible and no data space was merged | NOT EXECUTED |
| C5 | Switch back to A | A's original identity list and local data space return | NOT EXECUTED |
| C6 | Inspect sync status before and after the identity operations | Cursor, conflicts, tombstones, and manual-sync state are unchanged | NOT EXECUTED |

## D. Privacy

| ID | Procedure | Expected | Status |
|---|---|---|---|
| D1 | Inspect Account Security at normal and maximum font sizes | No provider subject or private provider identifier is displayed | NOT EXECUTED |
| D2 | Inspect all visible binding messages | No third-party token, authorization code, secret, or cloud user ID is displayed | NOT EXECUTED |
| D3 | Inspect the authenticated identity-list response | Only provider and safe timestamps are returned | NOT EXECUTED |
| D4 | Inspect the binding-start response | It contains only status, safe provider name, reauthentication requirement, and message | NOT EXECUTED |
| D5 | Inspect client and server logs after successful and failed attempts | No password, bearer token, provider subject, third-party token, code, or secret appears | NOT EXECUTED |
| D6 | Inspect the server identity table using authorized administration tooling | No third-party access token, refresh token, or secret column/value exists | NOT EXECUTED |

## E. UI and Regression

| ID | Procedure | Expected | Status |
|---|---|---|---|
| E1 | Test Account Security on Windows narrow and wide layouts | No overflow, clipping, or hidden binding action | NOT EXECUTED |
| E2 | Test Android portrait at normal and maximum system font size | Text remains readable, controls remain reachable, and the page scrolls | NOT EXECUTED |
| E3 | Use Tab, Enter, Space, Back, and Android Back where applicable | Navigation and controls remain usable | NOT EXECUTED |
| E4 | Register and log in with username/password | Existing password authentication is unchanged | NOT EXECUTED |
| E5 | Use developer login in an eligible Alpha build | Existing developer authentication is unchanged | NOT EXECUTED |
| E6 | Save and manually sync existing business modules | No automatic sync starts and existing sync semantics are unchanged | NOT EXECUTED |

## Result

- PASS: 0
- FAIL: 0
- NOT EXECUTED: 30
- WeChat Identity Foundation Gate: OPEN pending Windows, Android, A/B account,
  offline, privacy, and controlled duplicate-identity evidence.
