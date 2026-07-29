# Sprint 12C Journal Prompt System Manual Matrix

> Status rule: automated tests never become manual PASS.
>
> Acceptance evidence: User acceptance, 2026-07-30.
>
> Result: `93 PASS / 0 FAIL / 0 NOT EXECUTED`.

## A. Default Prompts

| ID | Check | Status |
|---|---|---|
| A1 | The five legacy prompts exist after upgrade. | PASS |
| A2 | Default prompt order is correct. | PASS |
| A3 | Existing Journal answers remain complete. | PASS |
| A4 | Existing draft status remains correct. | PASS |
| A5 | Existing completed status remains correct. | PASS |
| A6 | Historical question snapshots are correct. | PASS |
| A7 | Initialization creates no duplicate defaults. | PASS |

## B. Custom Prompts

| ID | Check | Status |
|---|---|---|
| B1 | Add a custom prompt. | PASS |
| B2 | Edit a custom prompt. | PASS |
| B3 | Disable a prompt. | PASS |
| B4 | Re-enable a prompt. | PASS |
| B5 | Move a prompt up. | PASS |
| B6 | Move a prompt down. | PASS |
| B7 | Reorder prompts by drag. | PASS |
| B8 | Delete a custom prompt. | PASS |
| B9 | Deletion requires confirmation. | PASS |
| B10 | A system prompt cannot be deleted directly. | PASS |
| B11 | Customize a system prompt through a user copy. | PASS |
| B12 | Configuration survives application restart. | PASS |

## C. New Journal

| ID | Check | Status |
|---|---|---|
| C1 | A new Journal uses current enabled prompts. | PASS |
| C2 | Disabled prompts are absent. | PASS |
| C3 | Custom prompts are visible. | PASS |
| C4 | Reordering does not mismatch answers. | PASS |
| C5 | Save Draft succeeds. | PASS |
| C6 | Complete Reflection succeeds. | PASS |
| C7 | Restart restores all answers. | PASS |
| C8 | Historical snapshots remain stable. | PASS |

## D. Prompt Changes And History

| ID | Check | Status |
|---|---|---|
| D1 | Edit the active prompt configuration. | PASS |
| D2 | Old Journal wording is unchanged. | PASS |
| D3 | A new Journal uses new wording. | PASS |
| D4 | Delete a custom prompt. | PASS |
| D5 | Historical answers remain available. | PASS |
| D6 | Disabling a prompt does not change history. | PASS |
| D7 | Apply Latest Prompts preserves matching answers. | PASS |
| D8 | A completed entry cannot Apply Latest Prompts. | PASS |

## E. Cross-device Sync

| ID | Check | Status |
|---|---|---|
| E1 | Add a custom prompt on Windows. | PASS |
| E2 | Run the manual Journal sync action. | PASS |
| E3 | Android pulls the configuration. | PASS |
| E4 | Prompt order matches. | PASS |
| E5 | Enabled states match. | PASS |
| E6 | Edit the configuration on Android. | PASS |
| E7 | Windows pulls the edit. | PASS |
| E8 | Logical deletion synchronizes. | PASS |
| E9 | Dynamic entry responses match across devices. | PASS |
| E10 | Payload v2 loses no answer. | PASS |
| E11 | Repeated sync creates no duplicate configuration. | PASS |

## F. Configuration Conflict

| ID | Check | Status |
|---|---|---|
| F1 | Edit the configuration offline on both devices. | PASS |
| F2 | The first device sync succeeds. | PASS |
| F3 | The second device receives an explicit conflict. | PASS |
| F4 | Conflict list does not expose full prompt text. | PASS |
| F5 | Detail clearly compares local and remote metadata. | PASS |
| F6 | Adopt Remote succeeds. | PASS |
| F7 | Keep Local succeeds. | PASS |
| F8 | Restart preserves a retryable conflict. | PASS |
| F9 | Both devices eventually converge. | PASS |
| F10 | Historical Journal entries remain unchanged. | PASS |

## G. Journal Payload V1 And V2

| ID | Check | Status |
|---|---|---|
| G1 | Upgraded client reads an old cloud Journal. | PASS |
| G2 | Legacy answers convert correctly. | PASS |
| G3 | A later write synchronizes payload v2. | PASS |
| G4 | Another upgraded client reads that v2 entry. | PASS |
| G5 | Custom prompt answers remain complete. | PASS |
| G6 | Journal status remains correct. | PASS |
| G7 | Tombstone behavior remains correct. | PASS |
| G8 | Existing conflict recovery remains correct. | PASS |

## H. Privacy

| ID | Check | Status |
|---|---|---|
| H1 | Prompt list shows no account ID. | PASS |
| H2 | Prompt list shows no UUID. | PASS |
| H3 | UI and logs show no token. | PASS |
| H4 | Prompt UI shows no endpoint. | PASS |
| H5 | Growth shows no prompt text. | PASS |
| H6 | Personal Data Overview shows no prompt text. | PASS |
| H7 | Logs contain no prompt or response body. | PASS |
| H8 | No AI request is made. | PASS |
| H9 | No automatic sync is triggered. | PASS |
| H10 | Conflict list does not expose full text. | PASS |

## I. Account Boundary

| ID | Check | Status |
|---|---|---|
| I1 | Account A creates a prompt configuration. | PASS |
| I2 | Account A logs out. | PASS |
| I3 | Account B cannot see Account A prompts. | PASS |
| I4 | Account B creates an independent configuration. | PASS |
| I5 | Re-login restores Account A configuration. | PASS |
| I6 | `authenticatedOffline` remains usable. | PASS |
| I7 | `bindingRequired` cannot enter Journal. | PASS |

## J. UI And Accessibility

| ID | Check | Status |
|---|---|---|
| J1 | Windows release behavior is correct. | PASS |
| J2 | Android arm64 release behavior is correct. | PASS |
| J3 | 320 px width has no overflow. | PASS |
| J4 | Maximum text size has no overflow. | PASS |
| J5 | Long question text wraps. | PASS |
| J6 | Long answers remain scrollable. | PASS |
| J7 | Keyboard operation remains available. | PASS |
| J8 | Buttons provide a non-drag reorder path. | PASS |
| J9 | Back protects unsaved edits. | PASS |
| J10 | No RenderFlex overflow occurs. | PASS |
| J11 | No crash occurs. | PASS |
| J12 | State is not communicated by color alone. | PASS |

## Release Gates

- Journal Prompt System Product Gate: `CLOSED / ACCEPTED`
- Journal Migration Gate: `CLOSED / ACCEPTED`
- Journal Prompt Sync Gate: `CLOSED / ACCEPTED`
- Account Boundary Isolation Gate: `CLOSED / ACCEPTED`
