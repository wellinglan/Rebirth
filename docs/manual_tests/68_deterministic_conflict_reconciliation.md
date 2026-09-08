# Sprint 19B Deterministic Conflict Reconciliation Manual Matrix

> Matrix status: **OPEN / NOT EXECUTED**
> Initial result: **0 PASS / 0 FAIL / 68 NOT EXECUTED**
> Baseline: `c8c417c79c6d5b6e5cb270a005a127fe47d09505`
> Sprint 19A matrix 67 remains **SUSPENDED** and is not inherited as PASS.

Use the same private-Alpha account on Windows and Android unless a row explicitly
requires a second account. Record exact client commit/artifact identity first.
Do not enter secrets, credentials, or real sensitive text solely for this test.
`NOT EXECUTED + AUTOMATED EVIDENCE SUBSTITUTION` is the required result for an
unsafe internal failure injection; it is never manual PASS.

## A. Preconditions and Baseline Establishment

| ID | Procedure | Expected result | Status | Evidence / notes |
|---|---|---|---|---|
| A1 | Confirm Windows and Android clients are built from the same Sprint 19B commit. | Exact commit/artifact identity is recorded. | NOT EXECUTED | Pending user execution. |
| A2 | Confirm both clients show the same authenticated account, endpoint, and registered-device readiness. | Sync is eligible without exposing internal IDs. | NOT EXECUTED | Pending user execution. |
| A3 | Confirm API health still reports API Version 1 and Sync Protocol 2. | Existing Server remains healthy; no 19B API deployment was needed. | NOT EXECUTED | Pending user execution. |
| A4 | Manually synchronize all supported modules once on both devices. | Both devices begin from visibly equivalent records and no unresolved conflicts. | NOT EXECUTED | Pending user execution. |
| A5 | Close and reopen each client after A4. | Data remains present and synchronization stays eligible. | NOT EXECUTED | Pending user execution. |
| A6 | Open Sync Center before creating a conflict. | Automatic-coordination and needs-attention counts are readable and initially zero for this session. | NOT EXECUTED | Pending user execution. |
| A7 | Confirm AI Chat contains a local-only marker conversation on one device. | It is visible only on that device and is not listed as a sync module. | NOT EXECUTED | Pending user execution. |
| A8 | Confirm matrix 67 still states SUSPENDED with 0 / 0 / 58. | No Sprint 19A row has been converted to PASS by this matrix. | NOT EXECUTED | Documentation check after final commit. |

## B. Deterministic Safe Convergence

| ID | Procedure | Expected result | Status | Evidence / notes |
|---|---|---|---|---|
| B1 | Change one Profile field on Windows only, then reconcile Android. | Remote-only change is adopted without a manual conflict. | NOT EXECUTED | Pending user execution. |
| B2 | Change one Plan title on Android only, then reconcile Windows. | Local-only change retries against the current Server version and converges. | NOT EXECUTED | Pending user execution. |
| B3 | Set the same Today field to the same value on both devices before reconciliation. | Exact equality converges and creates no manual conflict. | NOT EXECUTED | Pending user execution. |
| B4 | Change Profile display data on Windows and timezone preference on Android. | Disjoint Profile groups merge and both values appear on both devices. | NOT EXECUTED | Pending user execution. |
| B5 | Change a Plan title on Windows and description on Android. | Disjoint Plan text groups merge without changing hierarchy or dates. | NOT EXECUTED | Pending user execution. |
| B6 | Change Today Mood description on Windows and Energy score on Android. | Disjoint groups merge; score scale remains 1-10. | NOT EXECUTED | Pending user execution. |
| B7 | Change Health water value/description on Windows and exercise value/description on Android. | Disjoint metric groups merge and hidden fields remain unchanged. | NOT EXECUTED | Pending user execution. |
| B8 | Repeat synchronization after B4-B7 with no further edits. | No duplicate records/conflicts appear and counts do not grow again. | NOT EXECUTED | Pending user execution. |
| B9 | Restart both Apps and reconcile once more. | The previously established common state survives restart and remains converged. | NOT EXECUTED | Pending user execution. |
| B10 | Inspect Sync Center after safe cases. | It shows a nonnegative `已自动协调 N 条` summary and zero remaining attention for these cases. | NOT EXECUTED | Pending user execution. |

## C. Entity Policy Boundaries

| ID | Procedure | Expected result | Status | Evidence / notes |
|---|---|---|---|---|
| C1 | Edit the same Profile field differently on both devices. | One manual conflict appears; neither value is silently selected. | NOT EXECUTED | Pending user execution. |
| C2 | Edit a Plan title on one device and hierarchy on the other. | Only policy-proven disjoint groups may merge; hierarchy identity remains valid. | NOT EXECUTED | Pending user execution. |
| C3 | Edit the same Plan lifecycle/date group differently. | A manual conflict appears; dates/lifecycle are not field-spliced. | NOT EXECUTED | Pending user execution. |
| C4 | Edit Today priority text on one device and its completed flag on the other. | Text/completed/linked-goal atomicity is preserved through a manual conflict. | NOT EXECUTED | Pending user execution. |
| C5 | Set Today Research to null on one side and explicit 0 on the other. | Null and 0 remain distinguishable and the ambiguous same-group edit is manual. | NOT EXECUTED | Pending user execution. |
| C6 | Change Today Research duration on one side and its description on the other. | Duration plus description remains one atomic group and is not silently mixed. | NOT EXECUTED | Pending user execution. |
| C7 | Change Today Mood score and Mood description on opposite devices. | Independent score/description groups merge and the 1-10 score remains exact. | NOT EXECUTED | Pending user execution. |
| C8 | Change one Health metric to 0 while the other device changes a different metric. | Disjoint merge preserves explicit 0 and the unrelated value. | NOT EXECUTED | Pending user execution. |
| C9 | Change a Health metric and its description differently on both devices. | The metric pair is treated atomically and enters manual conflict. | NOT EXECUTED | Pending user execution. |
| C10 | Modify a Journal answer/body differently on both devices. | Journal content remains a conservative manual conflict; no text merge occurs. | NOT EXECUTED | Pending user execution. |
| C11 | Modify Journal status on one device and content on the other. | Result follows conservative lifecycle/body grouping without content loss. | NOT EXECUTED | Pending user execution. |
| C12 | Reorder/enable Journal Prompt Configuration differently on both devices. | The structure remains one manual conflict and prompt snapshots stay usable. | NOT EXECUTED | Pending user execution. |
| C13 | Archive an AI Report on one device while the other remains unchanged. | Archive converges; body and immutable version history remain byte-for-byte visible. | NOT EXECUTED | Pending user execution. |
| C14 | Change AI Report Feedback independently from an unrelated report state change. | Feedback uses its attached atomic path; report versions remain unchanged. | NOT EXECUTED | Pending user execution. |

## D. Delete and Lifecycle Races

| ID | Procedure | Expected result | Status | Evidence / notes |
|---|---|---|---|---|
| D1 | Delete an unchanged synchronized record on one device. | The deletion tombstone converges on the other device without resurrection. | NOT EXECUTED | Pending user execution. |
| D2 | Delete the same synchronized record on both devices. | Both deletions converge idempotently with no duplicate conflict. | NOT EXECUTED | Pending user execution. |
| D3 | Delete a Plan on one device while modifying it on the other. | A single manual conflict remains and the modified local value is retained. | NOT EXECUTED | Pending user execution. |
| D4 | Delete a Journal entry on one device while changing its answer/body on the other. | A manual conflict appears; body is not discarded automatically. | NOT EXECUTED | Pending user execution. |
| D5 | Archive an AI Report on one device and delete it on the other. | A manual conflict appears; neither archive nor deletion wins automatically. | NOT EXECUTED | Pending user execution. |
| D6 | Resolve D3 with Keep Local using the existing Conflict Center. | Conflict clears through the established flow and later reconciliation converges. | NOT EXECUTED | Pending user execution. |
| D7 | Recreate D3 and resolve with Adopt Remote. | Conflict clears through the established flow and deletion converges. | NOT EXECUTED | Pending user execution. |
| D8 | Inspect AI Report history after D5 and either manual resolution. | Existing immutable versions are preserved; no new version was synthesized by reconciliation. | NOT EXECUTED | Pending user execution. |

## E. Offline, Retry, and Partial Progress

| ID | Procedure | Expected result | Status | Evidence / notes |
|---|---|---|---|---|
| E1 | Disconnect Android, save changes, and return to the record. | Local save succeeds and content remains available without waiting for network. | NOT EXECUTED | Pending user execution. |
| E2 | While Android is offline, change a disjoint field on Windows and synchronize it. | Windows work completes; Android local content remains retained. | NOT EXECUTED | Pending user execution. |
| E3 | Restore Android networking and resume the foreground App. | Reconciliation merges only policy-proven disjoint changes and converges. | NOT EXECUTED | Pending user execution. |
| E4 | Tap manual synchronization repeatedly while one run is active. | Shared single-flight behavior prevents concurrent duplicate batches. | NOT EXECUTED | Pending user execution. |
| E5 | Save the same local field several times before synchronization. | The final local value is retained; coalescing loses no successful save. | NOT EXECUTED | Pending user execution. |
| E6 | Create one genuine conflict and an unrelated safe remote-only change in another module. | The safe module completes while the manual conflict remains. | NOT EXECUTED | Pending user execution. |
| E7 | Reconcile after an App restart following an interrupted/uncertain network response. | No duplicate record appears; current state is recalculated conservatively. | NOT EXECUTED | Pending user execution. |
| E8 | Move the App to background during a transient failure and wait. | No new retry begins while backgrounded. | NOT EXECUTED | Pending user execution. |
| E9 | Bring the App foreground again after E8. | Bounded reconciliation resumes without a notification or SnackBar storm. | NOT EXECUTED | Pending user execution. |
| E10 | Fully close the App after a local save. | No background completion is claimed; the save remains for the next foreground session. | NOT EXECUTED | Pending user execution. |

## F. Account and Scope Isolation

| ID | Procedure | Expected result | Status | Evidence / notes |
|---|---|---|---|---|
| F1 | Establish records for Account A, sign out, then sign into independent Account B. | B sees none of A's records, baselines, conflicts, or session counts. | NOT EXECUTED | Pending user execution. |
| F2 | Create a safe reconciliation for B, then return to A. | Each account retains only its own result and conflict state. | NOT EXECUTED | Pending user execution. |
| F3 | Start synchronization for A and sign out before it finishes. | Old A results do not apply after logout. | NOT EXECUTED | Pending user execution. |
| F4 | Start synchronization for A, switch to B, and wait for the old response. | A's response does not modify B; B can synchronize independently. | NOT EXECUTED | Pending user execution. |
| F5 | Change the configured endpoint while a request is in flight, using an approved safe endpoint setup. | The old-endpoint result is rejected from the new scope. | NOT EXECUTED | Pending safe setup; otherwise automated substitution. |
| F6 | Attempt synchronization from an unregistered device state. | No reconciliation write occurs and device registration is requested. | NOT EXECUTED | Pending safe setup; otherwise automated substitution. |
| F7 | Exercise an available session-expired/rejected product path. | Local data remains, old work is invalidated, and reauthentication is required. | NOT EXECUTED | Pending safe setup; otherwise automated substitution. |

## G. UI, Accessibility, and Privacy

| ID | Procedure | Expected result | Status | Evidence / notes |
|---|---|---|---|---|
| G1 | Open Sync Center on Windows at normal desktop width. | Both aggregate outcome labels and all existing manual actions are readable. | NOT EXECUTED | Pending user execution. |
| G2 | Use Sync Center on Android portrait at 320px-equivalent width. | Text wraps vertically with no RenderFlex or horizontal overflow. | NOT EXECUTED | Pending user execution. |
| G3 | Rotate Android to short landscape and scroll. | Summaries, module actions, and Conflict Center remain reachable. | NOT EXECUTED | Pending user execution. |
| G4 | Set system font/TextScaler near 2.0. | Counts, consent explanation, and buttons remain complete and usable. | NOT EXECUTED | Pending user execution. |
| G5 | Navigate Sync Center and Conflict Center on Windows with Tab, Enter, and Space. | Focus order and activation remain correct. | NOT EXECUTED | Pending user execution. |
| G6 | Inspect the surfaces with Android TalkBack. | Semantics announce automatic reconciliation and remaining-attention counts clearly. | NOT EXECUTED | Pending user execution. |
| G7 | Inspect Sync Center, Conflict Center, normal logs, and error messages. | No body, Prompt, token, secret, credential, raw UUID, cursor, server version, hash, or raw reason appears. | NOT EXECUTED | Pending user execution. |
| G8 | Reconcile with AI Chat data present on only one device. | Chat remains local-only and no AI Provider/generation action is triggered. | NOT EXECUTED | Pending user execution. |

## H. Controlled Automated Evidence Substitution

| ID | Procedure | Expected result | Status | Evidence / notes |
|---|---|---|---|---|
| H1 | Inject a second OCC exactly between merge calculation and retry. | Only one re-fetch/recalculation occurs; a further race becomes manual. | NOT EXECUTED | AUTOMATED EVIDENCE SUBSTITUTION: runner bounded-retry tests; no safe product injector. |
| H2 | Inject a database failure between remote apply/sync metadata and baseline write. | The whole local transaction rolls back and no false common baseline remains. | NOT EXECUTED | AUTOMATED EVIDENCE SUBSTITUTION: baseline adapter transaction test. |
| H3 | Deliver a stale response after logout/account/endpoint replacement. | Old asynchronous data cannot write into the new scope. | NOT EXECUTED | AUTOMATED EVIDENCE SUBSTITUTION: runner and foreground scope tests; no safe deterministic product injector. |

## Release Gate

The **Deterministic Conflict Reconciliation Safety Gate is OPEN**. It requires
matching final-commit CI/release artifacts plus all safely executable rows to be
reported by the product owner. H1-H3 remain honest `NOT EXECUTED` with named
automated evidence unless an approved safe fixture becomes available.

The **Foreground Automatic Sync Safety Gate remains OPEN**. Matrix 67 remains
SUSPENDED at `0 PASS / 0 FAIL / 58 NOT EXECUTED`; this matrix does not silently
complete or supersede its scheduling/lifecycle acceptance.
