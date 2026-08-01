# Sprint 14A.1 Real AI Provider And Cost Safety Manual Matrix

> Status: `PASS`
> Current result: `32 PASS / 0 FAIL / 0 NOT EXECUTED`

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
| A1 | Start API with `REBIRTH_AI_PROVIDER=disabled` | API is healthy; capabilities show Disabled | PASS |
| A2 | Attempt Daily and Weekly generation while disabled | Both show AI Disabled; no Provider request occurs | PASS |
| A3 | Configure `deepseek` without a key in a disposable environment | API fails closed without exposing configuration values | PASS |
| A4 | Configure `deepseek` without a model | API fails closed | PASS |
| A5 | Configure valid DeepSeek settings and recreate only API | API becomes healthy; PostgreSQL remains uninterrupted | PASS |
| A6 | Open AI capabilities from Windows and Android | Provider label and configured model are visible; no key is visible | PASS |

## B. Real Generation

| ID | Procedure | Expected | Status |
|---|---|---|---|
| B1 | Select one minimized Daily scope and inspect Preview | Only selected summarized fields appear | PASS |
| B2 | Cancel final confirmation | No local pending report and no paid request | PASS |
| B3 | Confirm one Daily Insight | Generating changes to Completed and a local report opens | PASS |
| B4 | Confirm one Weekly Report | Structured report completes without chat/tool UI | PASS |
| B5 | Compare Preview with report source navigation | Source data is unchanged | PASS |
| B6 | Restart the client | Completed local reports remain readable | PASS |

## C. Cost And Reliability

| ID | Procedure | Expected | Status |
|---|---|---|---|
| C1 | Double-click/tap Generate rapidly | One pending report and at most one Provider call | PASS |
| C2 | Repeat the same retained request through controlled diagnostics | Existing state replays/recovers; no second paid call | PASS |
| C3 | Set disposable user daily limit to 1 and make two unique requests | First runs; second shows Usage Limit Reached | PASS |
| C4 | Use another account after C3 | Other account retains its own user allowance | PASS |
| C5 | Set disposable global daily limit to 1 and use two accounts | Only the first reservation calls Provider | PASS |
| C6 | Saturate the configured concurrency with controlled requests | Additional request is rejected before Provider call | PASS |
| C7 | Simulate/observe a Provider timeout | Controlled timeout appears; no automatic retry | PASS |
| C8 | Interrupt client networking after submit | Pending recovery is preserved; status check does not POST again | PASS |

## D. Privacy And Audit

| ID | Procedure | Expected | Status |
|---|---|---|---|
| D1 | Inspect authorized API/proxy logs | No API key, JWT, prompt, payload, Journal/Health text, or output body | PASS |
| D2 | Inspect `ai_usage_records` read-only | Only safe metadata and token counts exist | PASS |
| D3 | Inspect one request with Journal scope not selected | Journal content is absent from Provider payload | PASS |
| D4 | Select Journal after explicit confirmation | Only existing minimized reflection fields are sent | PASS |
| D5 | Inspect Health input | Health note is absent | PASS |
| D6 | Review generated wording | No diagnosis, causal certainty, or deterministic life advice | PASS |

## E. UI And Regression

| ID | Procedure | Expected | Status |
|---|---|---|---|
| E1 | Exercise Generating, Completed, Failed, Disabled, and Usage Limit states on Windows | States are distinct and actionable | PASS |
| E2 | Repeat E1 on Android portrait | No overflow or hidden action | PASS |
| E3 | Repeat at 320px width and maximum font size | Text wraps; controls remain reachable | PASS |
| E4 | Use keyboard Tab, Enter, Space, Escape/Back | Focus and navigation remain usable | PASS |
| E5 | Exercise Profile/Plan/Today/Journal/Health sync | Sync behavior and data are unchanged | PASS |
| E6 | Confirm Flutter database diagnostics | `schemaVersion` remains `9` | PASS |

## Result

- PASS: 32
- FAIL: 0
- NOT EXECUTED: 0
- Real AI Provider Activation & Cost Safety Gate: `CLOSED` from the user's
  reported Windows/Android acceptance on 2026-08-01.
- This matrix must not be marked PASS from automated tests.
