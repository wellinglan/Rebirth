# Sprint 18A AI Coach Conversational MVP Manual Acceptance

> Sprint: **18A**
> Candidate baseline: `1ea0500bb6a670b69a6f4f65b00e110f0709af78`
> Matrix status: **NOT EXECUTED**
> Result: **0 PASS / 0 FAIL / 69 NOT EXECUTED**
> Gate: **OPEN**

This is the authoritative product-level matrix for the user-initiated,
non-streaming AI Coach Chat MVP. Automated evidence never becomes manual PASS.
Rows that cannot be injected safely in the Alpha product must remain
`NOT EXECUTED` with the named automated evidence recorded beside them.

## Preconditions

- Quality and Publish Alpha Images pass for the final full-SHA Candidate.
- Beijing Alpha pulls that exact API image and recreates only the API service.
- PostgreSQL remains running and its volume is not removed.
- `/health` reports healthy, API Version `1`, and Sync Protocol `2`.
- Windows Release and the Candidate `arm64-v8a` Android Release are rebuilt.
- Windows and Android can authenticate against the same Candidate endpoint.
- Use accounts whose test records may safely be read by an explicitly selected
  Chat context. Do not use secrets or third-party personal data as test text.

## A. Candidate And Deployment Identity

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| A1 | Confirm the final full-SHA GHCR API image and recorded digest. | Tag and digest match the Sprint 18A Candidate. | NOT EXECUTED | Requires final image publication. |
| A2 | Deploy by pulling the Candidate image and recreating only API. | PostgreSQL stays running; no volume or unrelated environment value changes. | NOT EXECUTED | Deployment pending. |
| A3 | Inspect API container status and recent startup logs. | API is running/healthy with no migration or startup error. | NOT EXECUTED | Deployment pending. |
| A4 | Request `/health`. | HTTP 200, API Version 1, Sync Protocol 2. | NOT EXECUTED | Deployment pending. |
| A5 | Launch the rebuilt Windows Release Candidate. | App starts and reaches authentication/Home normally. | NOT EXECUTED | Release build pending. |
| A6 | Install and launch the rebuilt `arm64-v8a` Android Release APK. | Installation succeeds and the Candidate starts normally. | NOT EXECUTED | Release build and device run pending. |
| A7 | Sign in on both clients and open Settings diagnostics. | Both use the intended endpoint/account; no raw token or secret is displayed. | NOT EXECUTED | Runtime check pending. |

## B. AI Coach Entry And Existing Features

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| B1 | Open the first-level AI Coach destination. | The page title and current AI availability/usage are readable. | NOT EXECUTED | Product run pending. |
| B2 | Inspect the top AI Coach actions. | `和 AI 教练聊一聊` and `开始对话` are clear without a marketing hero. | NOT EXECUTED | Product run pending. |
| B3 | Inspect `洞察与回顾`. | Daily Insight, Weekly Report, report library, and existing recovery paths remain available. | NOT EXECUTED | Regression run pending. |
| B4 | Open Chat but do not type or send. | A local empty conversation opens and no AI request or usage increment occurs. | NOT EXECUTED | Runtime request observation pending. |
| B5 | On Android, open conversation history and use Back. | History is a separate focused page; Back returns without losing the draft. | NOT EXECUTED | Android run pending. |
| B6 | On Windows at wide width, open Chat. | Thread list and active conversation use a readable two-pane layout. | NOT EXECUTED | Windows run pending. |
| B7 | Read the local-history notice. | It honestly states that Chat history stays on this device and is not cross-device sync. | NOT EXECUTED | Product run pending. |

## C. Basic Conversation And Keyboard Flow

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| C1 | Create a new conversation. | Composer is empty, context is unselected, and no request is sent. | NOT EXECUTED | Product run pending. |
| C2 | Send one ordinary text message. | User message and one complete AI reply appear; usage refreshes once. | NOT EXECUTED | Real/Fake configured Provider run pending. |
| C3 | Send a related follow-up in the same thread. | Reply reflects bounded prior turns without inventing personal records. | NOT EXECUTED | Multi-turn run pending. |
| C4 | Close and restart the app, then reopen the thread. | Local messages and order remain readable. | NOT EXECUTED | Persistence run pending. |
| C5 | On Windows, type a message and press Enter. | One explicit send occurs. | NOT EXECUTED | Keyboard run pending. |
| C6 | On Windows, press Shift+Enter in the composer. | A newline is inserted and no request is sent. | NOT EXECUTED | Keyboard run pending. |
| C7 | Rapidly activate Send more than once. | Single-flight behavior prevents duplicate Provider calls/messages. | NOT EXECUTED | Runtime run pending; automation also covers duplicate send. |
| C8 | Copy a completed AI reply. | Plain reply text is copied; no hidden Prompt, ID, hash, or metadata is copied. | NOT EXECUTED | Clipboard run pending. |
| C9 | Exercise an approved high-risk synthetic phrase if safe to do so. | A fixed support notice appears without diagnosis, certainty, or autonomous action. | NOT EXECUTED | May remain automated-only if no safe runtime fixture; Prompt fixtures cover the category. |

## D. Explicit Context And Privacy

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| D1 | Start a new thread and inspect `本次参考资料`. | No personal-data scope is selected by default. | NOT EXECUTED | Product run pending. |
| D2 | Open and close the context picker without sending. | Selection UI alone does not call AI or consume usage. | NOT EXECUTED | Runtime request observation pending. |
| D3 | Select Growth summary. | Selection is visibly named before send and changing it does not alter existing messages. | NOT EXECUTED | Product run pending. |
| D4 | Send with Growth explicitly selected. | Only the visible selection is attached for that send. | NOT EXECUTED | Runtime behavior pending. |
| D5 | Create another new thread. | Context selection resets to empty. | NOT EXECUTED | Product run pending. |
| D6 | Explicitly select Today metrics and send. | Chat can use bounded Today facts without silently adding other scopes. | NOT EXECUTED | Product run pending. |
| D7 | Explicitly select Health metrics and send. | Chat can use bounded Health facts and keeps health advice non-diagnostic. | NOT EXECUTED | Product run pending. |
| D8 | Explicitly select Journal reflections and send. | Journal text is included only after this explicit selection. | NOT EXECUTED | Product run pending. |
| D9 | Inspect the scope choices. | Active Goals is absent/unsupported and cannot be attached. | NOT EXECUTED | Product run pending. |
| D10 | Verify Sprint 17C-E metric descriptions are not silently attached. | Research/Learning/Sleep/Weight/Water/Exercise descriptions remain excluded unless typed by the user. | NOT EXECUTED | `ai_chat_input_assembler_impl_test.dart` is the authoritative automated privacy evidence if runtime payload inspection is unsafe. |

## E. Failure, Retry, And Outcome Recovery

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| E1 | Revoke AI consent, return to Chat, and try to send. | New sending is blocked immediately; draft and existing history remain. | NOT EXECUTED | Product run pending. |
| E2 | Grant consent again and explicitly send. | Sending becomes available, but consent restoration does not auto-send. | NOT EXECUTED | Product run pending. |
| E3 | Use an account at its daily limit. | Composer/send is disabled with an honest limit message; history remains readable. | NOT EXECUTED | Requires a safe quota fixture or accepted automated evidence. |
| E4 | Run with AI disabled at Server configuration. | Chat fails closed; no Provider call or generation is created. | NOT EXECUTED | Requires controlled operator window; automated Server coverage exists. |
| E5 | Trigger a known Provider failure through an approved fixture. | User text remains, assistant turn is failed, and explicit retry is offered. | NOT EXECUTED | May remain automated-only; coordinator tests cover preservation and new request ID. |
| E6 | Trigger an approved network-uncertain result. | State becomes result-unknown and offers only `检查结果`, not direct retry. | NOT EXECUTED | Safe network fault fixture may be unavailable; gateway/coordinator automation covers it. |
| E7 | Use `检查结果`. | Existing request status is queried without another generation or usage charge. | NOT EXECUTED | Runtime fixture pending; automated status recovery covers request binding. |
| E8 | Restart while a turn is pending/result-unknown, then reopen Chat. | State persists and recovery remains user-triggered. | NOT EXECUTED | Safe timing fixture may be unavailable; repository recreation tests cover persistence. |
| E9 | Inject a local transaction/binding write failure. | Provider is never called and local user content is not partially lost. | NOT EXECUTED | No safe product injection expected; coordinator automation is required evidence. |
| E10 | Inspect client and Server logs after success/failure. | No message, context body, Prompt, Authorization, token, API key, or secret is logged. | NOT EXECUTED | Controlled log review pending; automated privacy tests remain supporting evidence. |

## F. Local Lifecycle, Persistence, And Export

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| F1 | Send the first message in a new thread. | A concise local title is derived without a second AI call. | NOT EXECUTED | Product run pending. |
| F2 | Open Chat history after creating multiple threads. | Threads are ordered/readable and scoped to the signed-in account. | NOT EXECUTED | Product run pending. |
| F3 | Archive a completed thread and confirm. | Thread leaves the active list but its messages remain locally readable. | NOT EXECUTED | Product run pending. |
| F4 | Open an archived thread. | It is read-only; no new message can be sent. | NOT EXECUTED | Product run pending. |
| F5 | Start deletion, then cancel. | Thread and all messages remain unchanged. | NOT EXECUTED | Product run pending. |
| F6 | Confirm deletion of a test thread. | Thread and all of its local messages disappear after confirmation. | NOT EXECUTED | Product run pending. |
| F7 | Restart after archive/delete. | Archived state and completed deletion remain stable. | NOT EXECUTED | Persistence run pending. |
| F8 | Export all personal data with Chat included. | Optional `ai_chat` content is present, while user/request/provider/credential/recovery identifiers are absent. | NOT EXECUTED | Export inspection pending; export tests provide supporting evidence. |

## G. Account, Consent, Usage, And Sync Boundary

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| G1 | In Account A, create a distinctive test conversation. | The thread is visible only while Account A is active. | NOT EXECUTED | Two-account run pending. |
| G2 | Sign out and sign in as Account B. | Account A thread/message text is not visible. | NOT EXECUTED | Two-account run pending. |
| G3 | Inspect a new Account B chat. | Context selection is empty and no Account A draft/state is inherited. | NOT EXECUTED | Two-account run pending. |
| G4 | Create a conversation under Account B. | It uses only Account B consent, quota, and local storage. | NOT EXECUTED | Two-account run pending. |
| G5 | Sign out while Chat is open. | Authenticated Chat closes without leaking prior content on the login surface. | NOT EXECUTED | Product run pending. |
| G6 | Return to Account A. | Account A local history returns; Account B history remains hidden. | NOT EXECUTED | Two-account run pending. |
| G7 | Run `同步全部` after creating Chat history. | Chat is not listed/uploaded; six existing sync modules behave unchanged. | NOT EXECUTED | Product sync regression pending; architecture test proves no Chat entity. |
| G8 | Open the same account on the other device and manually sync. | Chat threads do not appear cross-device; existing business sync still works. | NOT EXECUTED | Cross-device run pending; local-only behavior is intentional. |

## H. Responsive, Accessibility, Safety, And Regression

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| H1 | Exercise Chat at 320px width. | No horizontal overflow; composer and recovery actions wrap/read correctly. | NOT EXECUTED | Widget automation covers 320px and recovery states. |
| H2 | Exercise Chat at 360px width. | Timeline, context action, send action, and history navigation remain usable. | NOT EXECUTED | Widget automation covers 360px. |
| H3 | Exercise Chat at 412px width on Android. | Single-column layout and touch targets remain comfortable. | NOT EXECUTED | Android run pending. |
| H4 | Exercise Chat at 720px width. | Compact layout remains coherent without accidental wide split mode. | NOT EXECUTED | Widget automation covers 720px. |
| H5 | Exercise Chat at 1200px on Windows. | Two-pane layout is stable and neither pane hides essential actions. | NOT EXECUTED | Widget automation covers 1200px. |
| H6 | Set system text scaling to 2.0 and repeat key flows. | Text wraps without clipping/overlap; recovery and confirmation actions remain reachable. | NOT EXECUTED | Widget automation covers target widths at TextScaler 2.0. |
| H7 | Use Android TalkBack on messages, context, send, archive, and delete. | Roles/actions have readable labels and are not conveyed by color alone. | NOT EXECUTED | Device accessibility run pending; Semantics automation supports message/send labels. |
| H8 | Use Windows Tab navigation through history, timeline actions, context, and composer. | Focus order is usable and visible. | NOT EXECUTED | Windows keyboard run pending. |
| H9 | Activate relevant focused actions with Enter/Space and use Shift+Enter in composer. | Buttons activate once; Shift+Enter remains a newline. | NOT EXECUTED | Widget automation covers composer keyboard contract. |
| H10 | Smoke Daily/Weekly generation, report library/feedback, Today, Journal, Plan, Health, Growth, login, and six-module sync. | Existing product paths remain functional and Chat creates no AI Report or business write. | NOT EXECUTED | Full regression and platform smoke pending. |

## Automated Evidence Available Before Manual Execution

- Server Chat endpoint tests cover strict JWT payloads, role injection,
  idempotency, concurrency, quota, Provider failure/timeout, request-status
  recovery, logging privacy, SQLite, and configured multi-worker suites.
- `ai_chat_coordinator_test.dart` covers local-first ordering, duplicate send,
  known failure retry, usage rejection, and result-unknown recovery.
- `local_ai_chat_repository_test.dart` covers account isolation, restart,
  archive, cascade delete, and state transitions.
- `ai_chat_input_assembler_impl_test.dart` covers text-only defaults, explicit
  scopes, bounded history, unsupported goals, and narrative exclusion.
- `ai_chat_page_test.dart` covers send/draft behavior, safety notice,
  recovery-state layout, target widths, TextScaler 2.0, Enter/Shift+Enter, and
  message/send Semantics.
- Migration and export tests cover schema 15 and the privacy-filtered optional
  `ai_chat` export module.

## Gate Decision

Current result: **0 PASS / 0 FAIL / 69 NOT EXECUTED**.

Gate: **OPEN**. It may close only after final CI, Candidate image publication,
digest-verified API-only Alpha deployment, Windows/Android Candidate builds,
and this matrix are recorded. Any unsafe row left `NOT EXECUTED` must retain a
specific reason and named automated substitute; it must never be rewritten as
manual PASS.
