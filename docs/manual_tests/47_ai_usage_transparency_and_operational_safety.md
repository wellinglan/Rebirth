# Sprint 14A.2 AI Usage Transparency And Operational Safety Manual Matrix

> Status: `NOT EXECUTED`
> Current result: `0 PASS / 0 FAIL / 36 NOT EXECUTED`

Automated tests do not become manual PASS. Use a disposable account, reviewed
low limits, and the approved immutable API image. Never place an API key, JWT,
prompt, Journal/Health text, or database credential in this document.

## Preconditions

- GitHub Quality and image publication pass for the Sprint commit.
- `/health` reports API Version `1` and Sync Protocol `2`.
- The API uses PostgreSQL and the reviewed real Provider configuration.
- Windows release and Android arm64 release point to the same Alpha server.
- Prepare Account A and Account B. Record starting usage without recording JWTs.

## A. Endpoint And Identity

| ID | Procedure | Expected | Status |
|---|---|---|---|
| A1 | Call `GET /ai/usage/me` without authentication | Request is rejected; no usage data is returned | NOT EXECUTED |
| A2 | Call it with Account A authentication | Response contains enabled, status, personal limit, used, remaining, and UTC reset | NOT EXECUTED |
| A3 | Add a `user_id` query parameter for Account B while authenticated as A | Result still belongs to A; the parameter cannot select another user | NOT EXECUTED |
| A4 | Inspect the response keys | No global limit, concurrency value, key, secret, prompt, content, or other user data | NOT EXECUTED |
| A5 | Read usage as Account B | B sees only B's independent count | NOT EXECUTED |
| A6 | Compare `used + remaining` with the personal limit | Values are non-negative and internally consistent | NOT EXECUTED |
| A7 | Inspect reset metadata | Timezone is UTC and reset is the next UTC natural-day boundary | NOT EXECUTED |
| A8 | Restart only the API container and read again | Usage remains consistent through PostgreSQL | NOT EXECUTED |

## B. Counting And Refresh

| ID | Procedure | Expected | Status |
|---|---|---|---|
| B1 | Open a prepared Preview | Current AI usage is visible before generation | NOT EXECUTED |
| B2 | Cancel final confirmation | No Provider request and no usage increment | NOT EXECUTED |
| B3 | Complete one Daily Insight | Used increments once and remaining decrements once | NOT EXECUTED |
| B4 | Complete one Weekly Report | Usage refreshes after completion and increments once | NOT EXECUTED |
| B5 | Exercise a controlled Provider failure after reservation | Failure is controlled and usage increments once | NOT EXECUTED |
| B6 | Exercise a controlled Provider timeout | No automatic retry; usage increments once | NOT EXECUTED |
| B7 | Repeat the same retained request ID through approved diagnostics | Existing request state is reused; usage does not increment again | NOT EXECUTED |
| B8 | Trigger a local quota rejection | Provider is not called and rejected attempt does not add a usage row | NOT EXECUTED |

## C. Presentation States

| ID | Procedure | Expected | Status |
|---|---|---|---|
| C1 | Use an enabled account below its personal limit | State is Available and Generate is enabled | NOT EXECUTED |
| C2 | Reach the disposable personal daily limit | State is Limit reached and Generate is disabled | NOT EXECUTED |
| C3 | Activate the Server AI kill switch in an approved window | State is Disabled and Generate is disabled | NOT EXECUTED |
| C4 | Restore the approved Provider configuration | State returns after refresh without changing source data | NOT EXECUTED |
| C5 | Temporarily make only the usage query unavailable | State becomes Unknown; Preview and local reports remain available | NOT EXECUTED |
| C6 | Restore connectivity after C5 and reopen/refresh | Current usage is shown again | NOT EXECUTED |
| C7 | Change allowance state after Preview but before Generate | Pre-generation check blocks a now-ineligible request | NOT EXECUTED |

## D. Responsive And Accessible UI

| ID | Procedure | Expected | Status |
|---|---|---|---|
| D1 | Inspect Available on Windows release | Used, remaining, limit, and reset are readable | NOT EXECUTED |
| D2 | Inspect Disabled and Limit reached on Windows | States are distinct; disabled button is obvious | NOT EXECUTED |
| D3 | Repeat D1-D2 on Android portrait | No overflow or hidden operation | NOT EXECUTED |
| D4 | Test at 320px width | Text wraps and controls remain reachable | NOT EXECUTED |
| D5 | Test at `TextScaler 2.0` | No RenderFlex overflow or clipped quota value | NOT EXECUTED |
| D6 | Navigate using Tab, Enter, Space, Escape/Back | Focus, confirmation, and back behavior remain usable | NOT EXECUTED |
| D7 | Read the summary with screen reader semantics | Status, used, remaining, limit, and reset are understandable | NOT EXECUTED |

## E. Privacy And Regression

| ID | Procedure | Expected | Status |
|---|---|---|---|
| E1 | Inspect API and reverse-proxy logs during query/generation | No API key, Authorization, prompt, or user正文 is present | NOT EXECUTED |
| E2 | Inspect `ai_usage_records` read-only | Only safe request/provider metadata, status, timestamps, and token counts exist | NOT EXECUTED |
| E3 | Exercise Today/Journal/Health source selection | Usage display does not reveal source content | NOT EXECUTED |
| E4 | Exercise Profile/Plan/Today/Journal/Health sync | Sync behavior is unchanged | NOT EXECUTED |
| E5 | Restart Windows and Android clients | Usage reloads; local reports and source data remain intact | NOT EXECUTED |
| E6 | Inspect Flutter diagnostics | Drift `schemaVersion` remains `9`; no migration runs | NOT EXECUTED |

## Result

- PASS: 0
- FAIL: 0
- NOT EXECUTED: 36
- AI Usage Transparency & Operational Safety Gate: `OPEN` pending deployment
  and authorized manual acceptance.
