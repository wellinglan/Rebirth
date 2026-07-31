# Sprint 13B.4 Step-up Reauthentication Manual Matrix

> Baseline: `8fc3b8734196f9d142d05941f1eba49ece844038`
> Status: manual acceptance not executed
> Current result: `0 PASS / 0 FAIL / 36 NOT EXECUTED`

## Preconditions

- GitHub Quality and image publication have passed for the Sprint commit.
- The matching API image is deployed without enabling a real WeChat provider.
- Windows release and Android arm64 release use the same Alpha server.
- `/health` reports API Version `1` and Sync Protocol `2`.
- Use disposable test accounts. Never record passwords, JWTs, proofs, state,
  nonce, authorization codes, provider subjects, or server secrets here.

## A. Password Step-up

| ID | Procedure | Expected | Status |
|---|---|---|---|
| A1 | Log in with a password account and open Account Security | Existing identities load normally | NOT EXECUTED |
| A2 | Select the unbound WeChat action and cancel the first confirmation | No reauthentication request starts | NOT EXECUTED |
| A3 | Continue and leave the password empty | Submission remains unavailable | NOT EXECUTED |
| A4 | Submit an incorrect current password | One generic failure appears and binding does not start | NOT EXECUTED |
| A5 | Retry with the correct current password | Step-up succeeds and the provider remains safely unavailable | NOT EXECUTED |
| A6 | Repeat A5 quickly | Each attempt requires a fresh proof; no stale result is reused | NOT EXECUTED |
| A7 | Wait beyond the configured proof lifetime before binding start in a controlled test build | The expired proof is rejected | NOT EXECUTED |
| A8 | Restart after the flow | No password or proof is restored from local storage | NOT EXECUTED |

## B. Session and Account Boundary

| ID | Procedure | Expected | Status |
|---|---|---|---|
| B1 | Issue a proof, log out, then attempt to continue in a controlled test build | The revoked session cannot use the proof | NOT EXECUTED |
| B2 | Log in again after logout | The prior proof remains invalid | NOT EXECUTED |
| B3 | Create accounts A and B on separate clients | Each account keeps its own Account Boundary | NOT EXECUTED |
| B4 | Attempt to use A's controlled-test proof under B | The request fails without revealing A | NOT EXECUTED |
| B5 | Sign in to A with a second session and try A's first-session proof | The proof is rejected | NOT EXECUTED |
| B6 | Inspect Profile and all five manual sync modules after the checks | No local data, cursor, conflict, or sync state changes | NOT EXECUTED |

## C. OAuth Callback Contract

| ID | Procedure | Expected | Status |
|---|---|---|---|
| C1 | Use an authorized controlled Fake Provider environment to complete one transaction | One callback completes and one identity is bound | NOT EXECUTED |
| C2 | Replay the completed callback | It returns `already_consumed` and creates nothing | NOT EXECUTED |
| C3 | Submit a wrong transaction/state/nonce | It returns `invalid_transaction` without internal detail | NOT EXECUTED |
| C4 | Submit an expired controlled transaction | It returns `expired_transaction` | NOT EXECUTED |
| C5 | Make the Fake Provider reject its response | It returns `provider_error`; no identity is created | NOT EXECUTED |
| C6 | Bind the same controlled provider identity to account B | It returns `binding_conflict`; account A retains ownership | NOT EXECUTED |

## D. Authentication Regression

| ID | Procedure | Expected | Status |
|---|---|---|---|
| D1 | Register and log in with username/password | Existing public authentication succeeds | NOT EXECUTED |
| D2 | Restore and refresh a valid session | Existing session rotation/restoration succeeds | NOT EXECUTED |
| D3 | Log out and restart | Session remains revoked and login is shown | NOT EXECUTED |
| D4 | Use developer login in an eligible Alpha build | Existing developer login succeeds | NOT EXECUTED |
| D5 | Exercise Profile/Plan/Today/Journal/Health manual sync | Existing sync behavior is unchanged | NOT EXECUTED |

## E. Privacy and Database

| ID | Procedure | Expected | Status |
|---|---|---|---|
| E1 | Inspect authorized API and proxy logs after successful and failed attempts | No password, JWT, proof, state, nonce, code, or provider secret appears | NOT EXECUTED |
| E2 | Inspect `reauthentication_proofs` using authorized read-only access | Only proof hashes and security metadata are stored | NOT EXECUTED |
| E3 | Inspect `oauth_transactions` | Purpose is `wechat_bind`; new rows have a session ID; no code/token column exists | NOT EXECUTED |
| E4 | Restart only the API container | PostgreSQL and business data remain intact | NOT EXECUTED |
| E5 | Verify client storage after process restart | No password or one-time proof is persisted | NOT EXECUTED |

## F. UI and Accessibility

| ID | Procedure | Expected | Status |
|---|---|---|---|
| F1 | Test the confirmation and password dialogs on Windows narrow/wide layouts | No overflow, clipping, or hidden action | NOT EXECUTED |
| F2 | Repeat on Android portrait | Controls remain readable and reachable | NOT EXECUTED |
| F3 | Repeat at maximum system font size | Dialog content scrolls/fits without overflow | NOT EXECUTED |
| F4 | Use Tab, Enter, Space, Escape/Back, and Android Back | Keyboard and navigation behavior remains usable | NOT EXECUTED |
| F5 | Fail reauthentication, then retry without leaving Account Security | Retry succeeds and the page remains responsive | NOT EXECUTED |
| F6 | Disconnect the network before submitting | A controlled error appears; no credential remains visible | NOT EXECUTED |

## Result

- PASS: 0
- FAIL: 0
- NOT EXECUTED: 36
- Step-up Reauthentication Gate: `OPEN`.
- OAuth Callback Contract Gate: `OPEN`.
- Real WeChat login: unsupported.
