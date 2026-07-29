# Sprint 12C Journal Prompt System Manual Matrix

> Status rule: automated tests never become manual PASS.
>
> Initial state: every item is `NOT EXECUTED`.

## A. Default Prompts

| ID | Check | Status |
|---|---|---|
| A1 | The five legacy prompts exist after upgrade. | NOT EXECUTED |
| A2 | Default prompt order is correct. | NOT EXECUTED |
| A3 | Existing Journal answers remain complete. | NOT EXECUTED |
| A4 | Existing draft status remains correct. | NOT EXECUTED |
| A5 | Existing completed status remains correct. | NOT EXECUTED |
| A6 | Historical question snapshots are correct. | NOT EXECUTED |
| A7 | Initialization creates no duplicate defaults. | NOT EXECUTED |

## B. Custom Prompts

| ID | Check | Status |
|---|---|---|
| B1 | Add a custom prompt. | NOT EXECUTED |
| B2 | Edit a custom prompt. | NOT EXECUTED |
| B3 | Disable a prompt. | NOT EXECUTED |
| B4 | Re-enable a prompt. | NOT EXECUTED |
| B5 | Move a prompt up. | NOT EXECUTED |
| B6 | Move a prompt down. | NOT EXECUTED |
| B7 | Reorder prompts by drag. | NOT EXECUTED |
| B8 | Delete a custom prompt. | NOT EXECUTED |
| B9 | Deletion requires confirmation. | NOT EXECUTED |
| B10 | A system prompt cannot be deleted directly. | NOT EXECUTED |
| B11 | Customize a system prompt through a user copy. | NOT EXECUTED |
| B12 | Configuration survives application restart. | NOT EXECUTED |

## C. New Journal

| ID | Check | Status |
|---|---|---|
| C1 | A new Journal uses current enabled prompts. | NOT EXECUTED |
| C2 | Disabled prompts are absent. | NOT EXECUTED |
| C3 | Custom prompts are visible. | NOT EXECUTED |
| C4 | Reordering does not mismatch answers. | NOT EXECUTED |
| C5 | Save Draft succeeds. | NOT EXECUTED |
| C6 | Complete Reflection succeeds. | NOT EXECUTED |
| C7 | Restart restores all answers. | NOT EXECUTED |
| C8 | Historical snapshots remain stable. | NOT EXECUTED |

## D. Prompt Changes And History

| ID | Check | Status |
|---|---|---|
| D1 | Edit the active prompt configuration. | NOT EXECUTED |
| D2 | Old Journal wording is unchanged. | NOT EXECUTED |
| D3 | A new Journal uses new wording. | NOT EXECUTED |
| D4 | Delete a custom prompt. | NOT EXECUTED |
| D5 | Historical answers remain available. | NOT EXECUTED |
| D6 | Disabling a prompt does not change history. | NOT EXECUTED |
| D7 | Apply Latest Prompts preserves matching answers. | NOT EXECUTED |
| D8 | A completed entry cannot Apply Latest Prompts. | NOT EXECUTED |

## E. Cross-device Sync

| ID | Check | Status |
|---|---|---|
| E1 | Add a custom prompt on Windows. | NOT EXECUTED |
| E2 | Run the manual Journal sync action. | NOT EXECUTED |
| E3 | Android pulls the configuration. | NOT EXECUTED |
| E4 | Prompt order matches. | NOT EXECUTED |
| E5 | Enabled states match. | NOT EXECUTED |
| E6 | Edit the configuration on Android. | NOT EXECUTED |
| E7 | Windows pulls the edit. | NOT EXECUTED |
| E8 | Logical deletion synchronizes. | NOT EXECUTED |
| E9 | Dynamic entry responses match across devices. | NOT EXECUTED |
| E10 | Payload v2 loses no answer. | NOT EXECUTED |
| E11 | Repeated sync creates no duplicate configuration. | NOT EXECUTED |

## F. Configuration Conflict

| ID | Check | Status |
|---|---|---|
| F1 | Edit the configuration offline on both devices. | NOT EXECUTED |
| F2 | The first device sync succeeds. | NOT EXECUTED |
| F3 | The second device receives an explicit conflict. | NOT EXECUTED |
| F4 | Conflict list does not expose full prompt text. | NOT EXECUTED |
| F5 | Detail clearly compares local and remote metadata. | NOT EXECUTED |
| F6 | Adopt Remote succeeds. | NOT EXECUTED |
| F7 | Keep Local succeeds. | NOT EXECUTED |
| F8 | Restart preserves a retryable conflict. | NOT EXECUTED |
| F9 | Both devices eventually converge. | NOT EXECUTED |
| F10 | Historical Journal entries remain unchanged. | NOT EXECUTED |

## G. Journal Payload V1 And V2

| ID | Check | Status |
|---|---|---|
| G1 | Upgraded client reads an old cloud Journal. | NOT EXECUTED |
| G2 | Legacy answers convert correctly. | NOT EXECUTED |
| G3 | A later write synchronizes payload v2. | NOT EXECUTED |
| G4 | Another upgraded client reads that v2 entry. | NOT EXECUTED |
| G5 | Custom prompt answers remain complete. | NOT EXECUTED |
| G6 | Journal status remains correct. | NOT EXECUTED |
| G7 | Tombstone behavior remains correct. | NOT EXECUTED |
| G8 | Existing conflict recovery remains correct. | NOT EXECUTED |

## H. Privacy

| ID | Check | Status |
|---|---|---|
| H1 | Prompt list shows no account ID. | NOT EXECUTED |
| H2 | Prompt list shows no UUID. | NOT EXECUTED |
| H3 | UI and logs show no token. | NOT EXECUTED |
| H4 | Prompt UI shows no endpoint. | NOT EXECUTED |
| H5 | Growth shows no prompt text. | NOT EXECUTED |
| H6 | Personal Data Overview shows no prompt text. | NOT EXECUTED |
| H7 | Logs contain no prompt or response body. | NOT EXECUTED |
| H8 | No AI request is made. | NOT EXECUTED |
| H9 | No automatic sync is triggered. | NOT EXECUTED |
| H10 | Conflict list does not expose full text. | NOT EXECUTED |

## I. Account Boundary

| ID | Check | Status |
|---|---|---|
| I1 | Account A creates a prompt configuration. | NOT EXECUTED |
| I2 | Account A logs out. | NOT EXECUTED |
| I3 | Account B cannot see Account A prompts. | NOT EXECUTED |
| I4 | Account B creates an independent configuration. | NOT EXECUTED |
| I5 | Re-login restores Account A configuration. | NOT EXECUTED |
| I6 | `authenticatedOffline` remains usable. | NOT EXECUTED |
| I7 | `bindingRequired` cannot enter Journal. | NOT EXECUTED |

## J. UI And Accessibility

| ID | Check | Status |
|---|---|---|
| J1 | Windows release behavior is correct. | NOT EXECUTED |
| J2 | Android arm64 release behavior is correct. | NOT EXECUTED |
| J3 | 320 px width has no overflow. | NOT EXECUTED |
| J4 | Maximum text size has no overflow. | NOT EXECUTED |
| J5 | Long question text wraps. | NOT EXECUTED |
| J6 | Long answers remain scrollable. | NOT EXECUTED |
| J7 | Keyboard operation remains available. | NOT EXECUTED |
| J8 | Buttons provide a non-drag reorder path. | NOT EXECUTED |
| J9 | Back protects unsaved edits. | NOT EXECUTED |
| J10 | No RenderFlex overflow occurs. | NOT EXECUTED |
| J11 | No crash occurs. | NOT EXECUTED |
| J12 | State is not communicated by color alone. | NOT EXECUTED |

## Release Gates

- Journal Prompt System Product Gate: `OPEN / MANUAL ACCEPTANCE REQUIRED`
- Journal Migration Gate: `OPEN / MANUAL ACCEPTANCE REQUIRED`
- Journal Prompt Sync Gate: `OPEN / MANUAL ACCEPTANCE REQUIRED`
- Account Boundary Isolation Gate: `CLOSED / ACCEPTED`
