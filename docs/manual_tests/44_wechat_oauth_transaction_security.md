# Sprint 13B.3 WeChat OAuth Transaction Security Manual Matrix

> Baseline: `ef33ff687478d22489bd2973670272b301be593f`
> Status: `SUSPENDED / NOT EXECUTED` while the tester is away.
> Automation is not manual evidence and does not close this gate.

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
| A1 | Start the API without WeChat configuration | API starts and WeChat remains unavailable | SUSPENDED |
| A2 | Open Account Security on Windows while online | WeChat readiness is visible without claiming real login support | SUSPENDED |
| A3 | Select the WeChat binding entry | The App reports that provider binding is not configured | SUSPENDED |
| A4 | Repeat A2-A3 on Android | The same fail-closed behavior appears | SUSPENDED |
| A5 | Inspect `/health` | No provider credential or readiness secret is returned | SUSPENDED |

## B. Authentication and Account Boundary

| ID | Procedure | Expected | Status |
|---|---|---|---|
| B1 | Log out and navigate directly to Account Security | Auth Gate blocks access | SUSPENDED |
| B2 | Log in as account A and inspect local modules | A's existing local data space is unchanged | SUSPENDED |
| B3 | Log out and log in as account B | B resolves its own Account Boundary | SUSPENDED |
| B4 | Switch A -> B -> A | Identity display and local data never cross accounts | SUSPENDED |
| B5 | Inspect sync status after readiness checks | No automatic sync, cursor movement, or conflict change occurs | SUSPENDED |

## C. Authentication Regression

| ID | Procedure | Expected | Status |
|---|---|---|---|
| C1 | Register and log in with username/password | Existing password authentication succeeds | SUSPENDED |
| C2 | Refresh or restore a valid session | Existing session rotation/restoration succeeds | SUSPENDED |
| C3 | Log out and restart | Session remains revoked and public login is shown | SUSPENDED |
| C4 | Use developer login in an eligible Alpha build | Existing developer authentication succeeds | SUSPENDED |
| C5 | Open Account Security after each login method | Safe identity discovery remains correct | SUSPENDED |

## D. Privacy and Operations

| ID | Procedure | Expected | Status |
|---|---|---|---|
| D1 | Inspect API and reverse-proxy logs after readiness checks | No token, state, nonce, code, provider subject, App ID, or secret appears | SUSPENDED |
| D2 | Inspect the Alpha environment file using authorized access | WeChat variables are absent or contain only intentionally configured server values | SUSPENDED |
| D3 | Inspect the OAuth transaction schema | No authorization-code, provider-token, or secret column exists | SUSPENDED |
| D4 | Restart only the API container | PostgreSQL and business data remain unchanged | SUSPENDED |
| D5 | Exercise existing manual sync actions | Existing five-module manual sync behavior is unchanged | SUSPENDED |

## E. UI and Accessibility

| ID | Procedure | Expected | Status |
|---|---|---|---|
| E1 | Test Windows narrow and wide Account Security layouts | No overflow, clipping, or hidden action | SUSPENDED |
| E2 | Test Android portrait at normal and maximum font size | Text remains readable and controls remain reachable | SUSPENDED |
| E3 | Use Tab, Enter, Space, Back, and Android Back | Navigation remains usable | SUSPENDED |
| E4 | Disconnect the network with a restored session | Offline state disables provider binding safely | SUSPENDED |

## Result

- PASS: 0
- FAIL: 0
- SUSPENDED / NOT EXECUTED: 24
- WeChat OAuth Transaction Security Gate: `OPEN / SUSPENDED` pending manual
  execution.
- Sprint 13B.2 manual matrix also remains suspended and is not treated as PASS.
