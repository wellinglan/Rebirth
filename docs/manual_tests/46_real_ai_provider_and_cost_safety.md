# Sprint 14A.1 Real AI Provider And Cost Safety Manual Matrix

> Status: `NOT EXECUTED`
> Current result: `0 PASS / 0 FAIL / 32 NOT EXECUTED`

## Preconditions

- GitHub Quality and image publication pass for the Sprint commit.
- Use a disposable account and low, reviewed limits.
- Store `DEEPSEEK_API_KEY` only in the Server environment. Never paste it into
  this document, Flutter, screenshots, chat, terminal history, or logs.
- Deploy the immutable API image by recreating only API. Keep PostgreSQL and all
  volumes running.
- Windows release and Android arm64 release use the same Alpha server.
- `/health` reports API Version `1` and Sync Protocol `2`.

## A. Provider And Kill Switch

| ID | Procedure | Expected | Status |
|---|---|---|---|
| A1 | Start API with `REBIRTH_AI_PROVIDER=disabled` | API is healthy; capabilities show Disabled | NOT EXECUTED |
| A2 | Attempt Daily and Weekly generation while disabled | Both show AI Disabled; no Provider request occurs | NOT EXECUTED |
| A3 | Configure `deepseek` without a key in a disposable environment | API fails closed without exposing configuration values | NOT EXECUTED |
| A4 | Configure `deepseek` without a model | API fails closed | NOT EXECUTED |
| A5 | Configure valid DeepSeek settings and recreate only API | API becomes healthy; PostgreSQL remains uninterrupted | NOT EXECUTED |
| A6 | Open AI capabilities from Windows and Android | Provider label and configured model are visible; no key is visible | NOT EXECUTED |

## B. Real Generation

| ID | Procedure | Expected | Status |
|---|---|---|---|
| B1 | Select one minimized Daily scope and inspect Preview | Only selected summarized fields appear | NOT EXECUTED |
| B2 | Cancel final confirmation | No local pending report and no paid request | NOT EXECUTED |
| B3 | Confirm one Daily Insight | Generating changes to Completed and a local report opens | NOT EXECUTED |
| B4 | Confirm one Weekly Report | Structured report completes without chat/tool UI | NOT EXECUTED |
| B5 | Compare Preview with report source navigation | Source data is unchanged | NOT EXECUTED |
| B6 | Restart the client | Completed local reports remain readable | NOT EXECUTED |

## C. Cost And Reliability

| ID | Procedure | Expected | Status |
|---|---|---|---|
| C1 | Double-click/tap Generate rapidly | One pending report and at most one Provider call | NOT EXECUTED |
| C2 | Repeat the same retained request through controlled diagnostics | Existing state replays/recovers; no second paid call | NOT EXECUTED |
| C3 | Set disposable user daily limit to 1 and make two unique requests | First runs; second shows Usage Limit Reached | NOT EXECUTED |
| C4 | Use another account after C3 | Other account retains its own user allowance | NOT EXECUTED |
| C5 | Set disposable global daily limit to 1 and use two accounts | Only the first reservation calls Provider | NOT EXECUTED |
| C6 | Saturate the configured concurrency with controlled requests | Additional request is rejected before Provider call | NOT EXECUTED |
| C7 | Simulate/observe a Provider timeout | Controlled timeout appears; no automatic retry | NOT EXECUTED |
| C8 | Interrupt client networking after submit | Pending recovery is preserved; status check does not POST again | NOT EXECUTED |

## D. Privacy And Audit

| ID | Procedure | Expected | Status |
|---|---|---|---|
| D1 | Inspect authorized API/proxy logs | No API key, JWT, prompt, payload, Journal/Health text, or output body | NOT EXECUTED |
| D2 | Inspect `ai_usage_records` read-only | Only safe metadata and token counts exist | NOT EXECUTED |
| D3 | Inspect one request with Journal scope not selected | Journal content is absent from Provider payload | NOT EXECUTED |
| D4 | Select Journal after explicit confirmation | Only existing minimized reflection fields are sent | NOT EXECUTED |
| D5 | Inspect Health input | Health note is absent | NOT EXECUTED |
| D6 | Review generated wording | No diagnosis, causal certainty, or deterministic life advice | NOT EXECUTED |

## E. UI And Regression

| ID | Procedure | Expected | Status |
|---|---|---|---|
| E1 | Exercise Generating, Completed, Failed, Disabled, and Usage Limit states on Windows | States are distinct and actionable | NOT EXECUTED |
| E2 | Repeat E1 on Android portrait | No overflow or hidden action | NOT EXECUTED |
| E3 | Repeat at 320px width and maximum font size | Text wraps; controls remain reachable | NOT EXECUTED |
| E4 | Use keyboard Tab, Enter, Space, Escape/Back | Focus and navigation remain usable | NOT EXECUTED |
| E5 | Exercise Profile/Plan/Today/Journal/Health sync | Sync behavior and data are unchanged | NOT EXECUTED |
| E6 | Confirm Flutter database diagnostics | `schemaVersion` remains `9` | NOT EXECUTED |

## Result

- PASS: 0
- FAIL: 0
- NOT EXECUTED: 32
- Real AI Provider Activation & Cost Safety Gate: `OPEN` pending deployment and
  authorized manual acceptance.
- This matrix must not be marked PASS from automated tests.
