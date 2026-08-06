# AI Report Generation Pipeline Manual Acceptance

> Sprint: **15B**
> Source baseline: `3a65cf13ec468b7688b3472f5d156d51021cf25e`
> Gate: **CLOSED WITH ACCEPTED LIMITATIONS**
> Result: **35 PASS / 0 FAIL / 7 NOT EXECUTED**
> Quality: [Run 31073858896](https://github.com/wellinglan/Rebirth/actions/runs/31073858896) PASS for `ab3bc862006ba21924595966190d93f6a661867a`
> Last updated: **2026-08-06**

This matrix records real Windows and Android product execution only. Automated
tests, source inspection, and successful builds are supporting evidence and must
not be entered as manual PASS.

Use test accounts and non-sensitive test data. Do not use a paid real Provider
unless a later release checklist explicitly authorizes it. For Sprint 15B manual
acceptance, Fake Provider or a safe controlled Alpha provider is sufficient.

## Preconditions

- Windows Release and Android arm64-v8a Release are built from the same reviewed
  Sprint 15B source.
- The Server endpoint used by both clients is stable for the test run.
- The tested account has AI data consent enabled.
- AI usage quota is available.
- Test data exists for Weekly and Daily selected scopes.
- Existing AI Reports may be present; record whether a completed matching report
  already exists before generation.
- No production credentials, real private journal content, or private health
  content are used.

## A. Windows Daily and Weekly Generation

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| A1 | On Windows, open AI Coach Weekly generation, select allowed scopes, generate local preview, and confirm. Exactly one pending report appears during generation. | PASS | User-reported Windows product execution. |
| A2 | Confirm Weekly completes or enters a controlled pending-recovery state; no duplicate local report is created by one click. | PASS | User-reported Windows product execution. |
| A3 | Repeat the same Weekly request immediately. If a completed matching report exists for the same endpoint/input, the app reuses it rather than creating another pending report. | PASS | User-reported Windows product execution. |
| A4 | Open Daily generation for a single target date, select allowed scopes, generate local preview, and confirm. Daily uses the same visible lifecycle and history behavior as Weekly. | PASS | User-reported Windows product execution. |
| A5 | Confirm Daily completion appears in the canonical AI Report Library and detail page with the correct single target date. | PASS | User-reported Windows product execution. |
| A6 | Rapidly click the generate/confirm action where the UI permits. Only one operation proceeds and duplicate taps are blocked or coalesced. | PASS | User-reported Windows product execution. |

## B. Android Daily and Weekly Generation

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| B1 | Install the reviewed arm64-v8a Release APK and sign in to the same test account. | PASS | User-reported Android product execution. |
| B2 | Generate or open a Weekly report with the same endpoint and input as Windows. Existing completed output is reused when eligible; otherwise one explicit generation occurs. | PASS | User-reported Android product execution. |
| B3 | Generate or open a Daily report. It follows the same confirmation, pending, completed, failed, and library behavior as Windows. | PASS | User-reported Android product execution. |
| B4 | Navigate away and back while a report is pending. The report remains recoverable through the existing pending detail action. | PASS | User-reported Android product execution. |
| B5 | Restart the Android app. Pending/completed/failed AI Report state remains visible in the canonical library. | PASS | User-reported Android product execution. |
| B6 | Confirm no automatic sync or automatic generation starts on app launch, route entry, or history/library open. | PASS | User-reported Android product execution. |

## C. Pending Recovery and Network Uncertainty

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| C1 | In a safe controlled network-interruption scenario after request submission, confirm the local report stays pending and the UI says the outcome requires checking. | NOT EXECUTED | No safe, stable product-level pending/processing/expired/not-found injection; automated coverage retained. |
| C2 | Use the pending detail action to check Server status. The app performs status recovery only and does not create a second pending report. | NOT EXECUTED | No safe, stable product-level pending/processing/expired/not-found injection; automated coverage retained. |
| C3 | If the Server returns completed, the local report becomes completed and the binding is cleared. | NOT EXECUTED | No safe, stable product-level pending/processing/expired/not-found injection; automated coverage retained. |
| C4 | If the Server returns processing, the local report remains pending and the user can retry checking later. | NOT EXECUTED | No safe, stable product-level pending/processing/expired/not-found injection; automated coverage retained. |
| C5 | If the Server result is expired or outcome unknown, the local report becomes a controlled failed report without exposing raw errors. | NOT EXECUTED | No safe, stable product-level pending/processing/expired/not-found injection; automated coverage retained. |
| C6 | If the Server record is not found, the app does not silently delete or regenerate; explicit user confirmation is required before marking local failed. | NOT EXECUTED | No safe, stable product-level pending/processing/expired/not-found injection; automated coverage retained. |

## D. Consent, Account, and Endpoint Boundary

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| D1 | Revoke AI consent before confirming generation. No pending report, binding, or remote request is created. | PASS | User-reported product execution. |
| D2 | Revoke AI consent after a request is already pending, then use pending recovery. Recovery status remains available because it does not send new source input. | PASS | User-reported product execution. |
| D3 | Switch from Account A to Account B before a pending report is recovered. Account B cannot see or recover Account A's report. | PASS | User-reported account-boundary execution. |
| D4 | Return to Account A. The pending report is still scoped to Account A and can be recovered from Account A only. | PASS | User-reported account-boundary execution. |
| D5 | Change to a different Server endpoint in an approved test build while a pending binding exists. The app refuses recovery under the wrong endpoint and does not call status. | PASS | User-reported endpoint-boundary execution. |
| D6 | Switch back to the original endpoint. The pending report can be checked again without creating a new request. | PASS | User-reported endpoint-boundary execution. |
| D7 | Confirm Account B does not inherit Account A's reusable completed reports or AI consent state. | PASS | User-reported account-boundary execution. |

## E. Failure, Retry, and Usage Behavior

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| E1 | Use a controlled Provider failure or disabled Provider scenario. The app stores only a controlled failed report and no raw Provider response. | PASS | User-reported controlled Provider failure execution. |
| E2 | After a terminal controlled failure, explicitly retry by starting a new manual generation. The retry creates a new request only after the user action. | PASS | User-reported explicit retry execution. |
| E3 | Exhaust the user quota in a safe test account. The app blocks generation before creating a local pending report. | PASS | User-reported quota execution. |
| E4 | Trigger a request-binding save failure only in an approved test fixture. No remote POST is sent and the local report records a controlled failure. | NOT EXECUTED | No product-level fixture unless explicitly prepared. |
| E5 | Confirm a failed or pending state never auto-retries when reopening AI Coach, Report Library, or report detail. | PASS | User-reported no-auto-retry execution. |

## F. Sync, Library, Export, and Data Non-mutation

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| F1 | Sync AI Reports manually after a completed generation. The report uses the existing Sync Center and no new sync module appears. | PASS | User-reported sync regression execution. |
| F2 | Open the AI Report Library. Daily and Weekly generated reports appear in the canonical list/detail routes. | PASS | User-reported library execution. |
| F3 | Export an AI Report and full personal data after generation. Exported content reflects local report state without triggering generation or sync. | PASS | User-reported export regression execution. |
| F4 | Confirm source Today, Journal, Health, Plan, Profile, Growth, and Personal Data views are not modified by report generation. | PASS | User-reported data non-mutation execution. |
| F5 | Confirm version history is appended only by terminal report results and old versions are not overwritten. | PASS | User-reported version-history execution. |
| F6 | Confirm no automatic cross-device sync occurs after generation; the other device changes only after manual sync/pull. | PASS | User-reported manual-sync boundary execution. |

## G. Privacy, UI, and Accessibility

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| G1 | Inspect visible UI during success, pending, and failed states. No token, API key, endpoint credential, full user ID, request binding payload, canonical JSON, or stack trace is shown. | PASS | User-reported privacy inspection. |
| G2 | Confirm failure SnackBars/messages are controlled and path-free. | PASS | User-reported controlled-error inspection. |
| G3 | On Android 320, 360, and 412 logical-pixel widths, Daily/Weekly preview, confirmation, pending detail, and library remain scrollable without horizontal overflow. | PASS | User-reported responsive product execution. |
| G4 | At TextScaler 2.0 / maximum font size, all actions remain readable and reachable. | PASS | User-reported accessibility execution. |
| G5 | On Windows, Tab, Enter, Space, Back, and route navigation remain usable throughout preview, confirmation, generation, pending recovery, and detail. | PASS | User-reported keyboard/navigation execution. |
| G6 | Restart both apps after successful and pending flows. The library/history state is stable and no generation starts automatically. | PASS | User-reported restart execution. |

## Gate Decision

The Gate is **CLOSED WITH ACCEPTED LIMITATIONS** at **35 PASS / 0 FAIL / 7 NOT
EXECUTED**. The user reported all applicable Windows and Android product rows
as PASS. C1-C6 remain honestly NOT EXECUTED because no safe, stable product-level
fixture can force each pending/processing/expired/not-found state. E4 remains
NOT EXECUTED because no safe product-level request-binding persistence failure
fixture exists. Automated tests cover these seven controlled paths; they are
supporting evidence and are not reclassified as manual PASS.
GitHub Quality run 31073858896 passed for the Sprint 15B implementation
commit, so no automated or manual blocker remains inside the accepted Gate
scope.
