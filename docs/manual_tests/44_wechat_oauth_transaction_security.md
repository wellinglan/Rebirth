# Sprint 13B.3 WeChat OAuth Transaction Security Manual Matrix

> Baseline: `ef33ff687478d22489bd2973670272b301be593f`
> Manual acceptance completed by the authorized tester.
> Final result: `24 PASS / 0 FAIL / 0 NOT EXECUTED`.

## Preconditions

- Resume only when an authorized tester can access Windows, Android, and the
  Alpha server.
- Deploy the Sprint 13B.3 API image after GitHub Quality passes.
- Confirm `/health` reports API Version `1` and Sync Protocol `2`.
- Do not configure real WeChat credentials for this matrix.
- Do not place passwords, JWTs, state, nonce, authorization codes, provider
  subjects, or server secrets in this document or screenshots.

## A. Fail-closed Readiness

| ID | Procedure | Expected | Status |
|---|---|---|---|
| A1 | Start the API without WeChat configuration | API starts and WeChat remains unavailable | PASS |
| A2 | Open Account Security on Windows while online | WeChat readiness is visible without claiming real login support | PASS |
| A3 | Select the WeChat binding entry | The App reports that provider binding is not configured | PASS |
| A4 | Repeat A2-A3 on Android | The same fail-closed behavior appears | PASS |
| A5 | Inspect `/health` | No provider credential or readiness secret is returned | PASS |

## B. Authentication and Account Boundary

| ID | Procedure | Expected | Status |
|---|---|---|---|
| B1 | Log out and navigate directly to Account Security | Auth Gate blocks access | PASS |
| B2 | Log in as account A and inspect local modules | A's existing local data space is unchanged | PASS |
| B3 | Log out and log in as account B | B resolves its own Account Boundary | PASS |
| B4 | Switch A -> B -> A | Identity display and local data never cross accounts | PASS |
| B5 | Inspect sync status after readiness checks | No automatic sync, cursor movement, or conflict change occurs | PASS |

## C. Authentication Regression

| ID | Procedure | Expected | Status |
|---|---|---|---|
| C1 | Register and log in with username/password | Existing password authentication succeeds | PASS |
| C2 | Refresh or restore a valid session | Existing session rotation/restoration succeeds | PASS |
| C3 | Log out and restart | Session remains revoked and public login is shown | PASS |
| C4 | Use developer login in an eligible Alpha build | Existing developer authentication succeeds | PASS |
| C5 | Open Account Security after each login method | Safe identity discovery remains correct | PASS |

## D. Privacy and Operations

| ID | Procedure | Expected | Status |
|---|---|---|---|
| D1 | Inspect API and reverse-proxy logs after readiness checks | No token, state, nonce, code, provider subject, App ID, or secret appears | PASS |
| D2 | Inspect the Alpha environment file using authorized access | WeChat variables are absent or contain only intentionally configured server values | PASS |
| D3 | Inspect the OAuth transaction schema | No authorization-code, provider-token, or secret column exists | PASS |
| D4 | Restart only the API container | PostgreSQL and business data remain unchanged | PASS |
| D5 | Exercise existing manual sync actions | Existing five-module manual sync behavior is unchanged | PASS |

## E. UI and Accessibility

| ID | Procedure | Expected | Status |
|---|---|---|---|
| E1 | Test Windows narrow and wide Account Security layouts | No overflow, clipping, or hidden action | PASS |
| E2 | Test Android portrait at normal and maximum font size | Text remains readable and controls remain reachable | PASS |
| E3 | Use Tab, Enter, Space, Back, and Android Back | Navigation remains usable | PASS |
| E4 | Disconnect the network with a restored session | Offline state disables provider binding safely | PASS |

## Result

- PASS: 24
- FAIL: 0
- NOT EXECUTED: 0
- WeChat OAuth Transaction Security Gate: `CLOSED`.
- Sprint 13B.2 manual matrix is also complete with `30 PASS / 0 FAIL`.
