# Sprint 19A Foreground Automatic Sync

> Matrix status: **OPEN / NOT EXECUTED**
> Initial result: **0 PASS / 0 FAIL / 58 NOT EXECUTED**
> Product-owner decision: **SUSPENDED for Sprint 19B; no row is PASS**
> Starting baseline: `17e9e9faea0f9be6cea268b8c55734e80ecbcc61`
> Implementation commit: `9a78c0dc117dbd0be87d107ea9b3da69d854ec96`
> Scope: user-authorized foreground automatic synchronization using the six
> existing Sync Center modules.

Automated tests are supporting evidence only. They do not turn any row into a
manual PASS. Record the exact Windows/APK source commit and endpoint before
execution. Use two registered devices and two accounts where the row requires
them. Do not reset cloud or local data unless the test plan explicitly allows
it.

Execution was suspended before Sprint 19B. The original 58 row states and Gate
remain unchanged. Matrix 68 evaluates deterministic reconciliation separately
and does not silently complete this foreground-scheduling matrix.

## A. Authorization And Scope

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| A1 | Open Sync Center on a Windows account that has never enabled automatic sync. | The switch is off by default; manual actions remain available. | NOT EXECUTED | Pending user execution. |
| A2 | Repeat A1 on a fresh Android installation/account space. | The switch is independently off. | NOT EXECUTED | Pending user execution. |
| A3 | Turn the switch on. | A confirmation names six modules, sensitive content, foreground-only behavior, conflict handling, AI Chat exclusion, and separate AI consent. | NOT EXECUTED | Pending user execution. |
| A4 | Cancel the confirmation. | The switch remains off and no automatic request starts. | NOT EXECUTED | Pending user execution. |
| A5 | Confirm enablement and restart the App. | The setting remains enabled for that local account/device. | NOT EXECUTED | Pending user execution. |
| A6 | Disable automatic sync, then edit a record. | No new automatic task starts; manual sync remains usable. | NOT EXECUTED | Pending user execution. |
| A7 | Enable on Windows and inspect Android without enabling there. | Android does not inherit the Windows preference. | NOT EXECUTED | Pending user execution. |

## B. Startup And Lifecycle

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| B1 | With the switch enabled, sign in or restore a valid session. | One full reconciliation is scheduled after the account/device is ready. | NOT EXECUTED | Pending user execution. |
| B2 | Keep the App foregrounded beyond one reconciliation interval while another device has a new change. | A low-frequency reconciliation pulls the change without repeated rapid requests. | NOT EXECUTED | Pending user execution. |
| B3 | Put the App in the background, change data on the other device, then resume. | A cooled-down foreground reconciliation obtains the change. | NOT EXECUTED | Pending user execution. |
| B4 | Observe the App while it remains backgrounded. | It starts no new periodic or retry task. | NOT EXECUTED | Pending user execution. |
| B5 | Fully close the App. | No system background synchronization is claimed or observed. | NOT EXECUTED | Pending user execution. |
| B6 | Reopen the App with a restored valid session and enabled preference. | Foreground coordination starts again without duplicate records. | NOT EXECUTED | Pending user execution. |

## C. Six Modules Cross-device

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| C1 | Save Profile on device A and allow foreground automatic sync; reconcile device B. | The same Profile identity and values converge without duplication. | NOT EXECUTED | Pending user execution. |
| C2 | Create/edit a Plan hierarchy on A and reconcile B. | Parent/child identity, dates, and lifecycle converge. | NOT EXECUTED | Pending user execution. |
| C3 | Save Today on A and reconcile B. | Today values, null/zero semantics, priorities, scores, descriptions, and note converge. | NOT EXECUTED | Pending user execution. |
| C4 | Save/complete/reopen a Journal entry on A and reconcile B. | Journal identity, status, and snapshots converge. | NOT EXECUTED | Pending user execution. |
| C5 | Change Journal Prompt Configuration and create an entry using it. | Prompt configuration reaches B before the dependent entry remains usable. | NOT EXECUTED | Pending user execution. |
| C6 | Save sensitive Health fields on A and reconcile B. | Health values converge only for the same account. | NOT EXECUTED | Pending user execution. |
| C7 | Complete or fail an AI Report into a syncable terminal state and reconcile B. | The report aggregate and immutable versions retain existing semantics. | NOT EXECUTED | Pending user execution. |
| C8 | Save/clear structured AI Report Feedback and reconcile B. | Feedback follows the existing AI Report attached synchronization behavior. | NOT EXECUTED | Pending user execution. |
| C9 | Delete a synchronized record on A and reconcile B. | The existing tombstone behavior removes it without resurrection or duplication. | NOT EXECUTED | Pending user execution. |
| C10 | Archive a Plan or AI Report on A and reconcile B. | Archive state converges without becoming deletion or rewriting immutable history. | NOT EXECUTED | Pending user execution. |

## D. Local Save Experience

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| D1 | Save while the endpoint is slow or unreachable. | Local save completes without waiting for automatic network work. | NOT EXECUTED | Pending user execution. |
| D2 | Save the same module several times quickly. | The final value is retained and automatic work is coalesced without duplicate records. | NOT EXECUTED | Pending user execution. |
| D3 | Edit a form while automatic sync is running. | Form content is not cleared or replaced by a loading screen. | NOT EXECUTED | Pending user execution. |
| D4 | Sync records containing null and explicit zero. | The two meanings remain distinct after reconciliation. | NOT EXECUTED | Pending user execution. |
| D5 | Trigger a normal product validation/save failure. | No successful-save message appears and no automatic sync is attributed to that failed write. | NOT EXECUTED | Pending user execution. |

## E. Offline Recovery

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| E1 | Disconnect networking and save local changes. | The local changes remain available. | NOT EXECUTED | Pending user execution. |
| E2 | Keep the App foregrounded through several failed attempts. | Status is concise and there is no notification/SnackBar storm. | NOT EXECUTED | Pending user execution. |
| E3 | Leave the App backgrounded during the retry window. | No new retry starts until foreground use resumes. | NOT EXECUTED | Pending user execution. |
| E4 | Restore networking and return to the foreground. | Bounded retry or reconciliation converges the retained data. | NOT EXECUTED | Pending user execution. |
| E5 | Use manual Sync All while automatic retry is pending. | Manual synchronization remains the explicit fallback and no concurrent batch is created. | NOT EXECUTED | Pending user execution. |

## F. Conflict Safety

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| F1 | Modify the same synchronized record differently on A and B before reconciliation. | Automatic sync records an OCC conflict and keeps local content. | NOT EXECUTED | Pending user execution. |
| F2 | Wait through another foreground reconciliation while the conflict is unresolved. | No winner is selected and no duplicate conflict is created. | NOT EXECUTED | Pending user execution. |
| F3 | Inspect Sync Center. | It shows a concise needs-attention state and a Conflict Center action. | NOT EXECUTED | Pending user execution. |
| F4 | Inspect the conflict alongside unrelated changed modules. | The conflicted module pauses; other modules can still reconcile. | NOT EXECUTED | Pending user execution. |
| F5 | Choose Keep Local in the existing Conflict Center. | The conflict clears through the existing flow and the local choice can converge. | NOT EXECUTED | Pending user execution. |
| F6 | Create another conflict and choose Adopt Remote. | The conflict clears and the remote choice is applied without hidden merge. | NOT EXECUTED | Pending user execution. |
| F7 | Reconcile both devices after each resolution. | Both devices converge; history/version/tombstone rules remain intact. | NOT EXECUTED | Pending user execution. |

## G. Account And Session Safety

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| G1 | Enable automatic sync for Account A, then sign into Account B. | B does not inherit A's preference or data. | NOT EXECUTED | Pending user execution. |
| G2 | Queue a local change, then log out before debounce completes. | Pending scheduling is cleared and no post-logout request starts. | NOT EXECUTED | Pending user execution. |
| G3 | Switch A to B while an A request is in flight. | A's response is not applied to B and B can later reconcile its own scope. | NOT EXECUTED | Pending user execution. |
| G4 | Use an unregistered device with the preference enabled. | Automatic sync waits and identifies device registration as required. | NOT EXECUTED | Pending user execution. |
| G5 | Enter binding/legacy ownership review state. | Automatic sync does not execute until explicit review is complete. | NOT EXECUTED | Pending user execution. |
| G6 | Exercise a safely available rejected/unknown session path. | Scheduling stops, local data remains, and reauthentication is required. | NOT EXECUTED | Pending user execution or accepted automated substitution if no safe fixture exists. |

## H. AI And Privacy

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| H1 | Send AI Chat messages on A, then reconcile B. | Chat threads/messages do not appear on B. | NOT EXECUTED | Pending user execution. |
| H2 | Observe Server/Provider behavior during automatic sync. | No AI generation or Provider call is triggered. | NOT EXECUTED | Pending user execution. |
| H3 | Toggle cloud sync consent and inspect AI data consent; then reverse. | Each consent remains independent. | NOT EXECUTED | Pending user execution. |
| H4 | Inspect Sync Center, conflict UI, normal logs, and errors. | No token, Authorization, secret, credential, Prompt, protected body, raw cursor, UUID, or server version is exposed. | NOT EXECUTED | Pending user execution. |

## I. UI And Accessibility

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| I1 | Use Sync Center on Windows at a normal desktop width. | Switch, status, Sync All, modules, and Conflict Center access are readable and usable. | NOT EXECUTED | Pending user execution. |
| I2 | Use it on Android portrait. | No hidden primary action or horizontal overflow. | NOT EXECUTED | Pending user execution. |
| I3 | Rotate Android to short landscape and scroll the page. | Every action remains reachable without overflow. | NOT EXECUTED | Pending user execution. |
| I4 | Exercise a 320px-wide viewport. | Content wraps/scrolls vertically without RenderFlex overflow. | NOT EXECUTED | Pending user execution. |
| I5 | Set TextScaler/system font to approximately 2.0. | Switch labels, status, confirmation, and buttons remain complete. | NOT EXECUTED | Pending user execution. |
| I6 | On Windows, navigate the switch/dialog/actions with Tab, Enter, and Space. | Focus and activation behavior remain correct. | NOT EXECUTED | Pending user execution. |
| I7 | Inspect the controls with Android TalkBack. | Switch state, live status, module names, and actions have readable semantics. | NOT EXECUTED | Pending user execution. |
| I8 | Watch automatic state changes during save, retry, success, and conflict. | No repeated success SnackBar, raw diagnostic field, crash, or inaccessible action appears. | NOT EXECUTED | Pending user execution. |

## Gate Decision

The **Foreground Automatic Sync Safety Gate is OPEN**. It cannot close until
the required Flutter checks, Windows/Android release artifacts, GitHub Quality,
and this manual matrix are reconciled against the same final commit. A future
update must preserve every original row and record `PASS`, `FAIL`,
`NOT EXECUTED`, or `AUTOMATED EVIDENCE SUBSTITUTION` honestly.
