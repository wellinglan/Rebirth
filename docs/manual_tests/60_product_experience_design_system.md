# Product Experience and Design System Manual Acceptance

> Sprint: **17A**
> Gate: **Product Experience Foundation Gate**
> Current status: **OPEN / NOT EXECUTED**
> Starting HEAD: `6f8415b8f7a69dfc61b39c8d98251604e200d92a`

## Evidence Rules

- Use the reviewed Windows and Android build from the final Sprint commit.
- Check behavior and legibility, not personal preference about the final art
  direction. Visual preference remains open for later feature redesign.
- Do not mark automated responsive tests as manual PASS.
- Existing feature workflows, local data, sync, and AI behavior are regression
  boundaries rather than new claims.

## A. Theme and Controls

| ID | Check | Expected result | Status | Evidence / note |
|---|---|---|---|---|
| A1 | Inspect Today, Settings, Plan, Growth, and AI Coach surfaces | Text and controls remain legible; the interface is not dominated by one color | NOT EXECUTED | - |
| A2 | Focus a text field on Windows | A clear focus outline appears without moving the layout | NOT EXECUTED | - |
| A3 | Inspect filled, outlined, text, and icon buttons | Controls share restrained shape and a usable target size | NOT EXECUTED | - |
| A4 | Trigger a normal save SnackBar | It floats above navigation and does not obscure the active control | NOT EXECUTED | - |
| A5 | Open a menu and a dialog | Both remain readable and visually related without excessive rounding | NOT EXECUTED | - |
| A6 | Compare success, warning, information, and error states that naturally exist | State meaning is also expressed by icon/text, not color alone | NOT EXECUTED | Use natural states only |

## B. Responsive Home Shell

| ID | Check | Expected result | Status | Evidence / note |
|---|---|---|---|---|
| B1 | Open the Android app at normal width | Bottom navigation shows all six reachable destinations | NOT EXECUTED | - |
| B2 | Switch through all six destinations | Branch state and existing route behavior remain intact | NOT EXECUTED | - |
| B3 | Open Settings from each destination | The global Settings action remains reachable | NOT EXECUTED | - |
| B4 | Return from Settings | The previously selected destination remains active | NOT EXECUTED | - |
| B5 | Test 320px width | No RenderFlex or horizontal overflow appears | NOT EXECUTED | - |
| B6 | Test 360px width | Navigation and Settings remain usable | NOT EXECUTED | - |
| B7 | Test 412px width | Navigation and Settings remain usable | NOT EXECUTED | - |
| B8 | Resize Windows near 840px | The bottom bar changes to a compact NavigationRail without route loss | NOT EXECUTED | - |
| B9 | Resize Windows to at least 1200px | The rail expands and `Rebirth` is visible without squeezing content | NOT EXECUTED | - |
| B10 | Use TextScaler 2.0 at wide Windows width | Navigation returns to compact rail and no label overflows | NOT EXECUTED | - |

## C. Shared Loading and Error Experience

| ID | Check | Expected result | Status | Evidence / note |
|---|---|---|---|---|
| C1 | Observe Today initial loading when naturally visible | One stable loading indicator appears with no full-layout jump | NOT EXECUTED | Natural state only |
| C2 | Observe Settings initial loading when naturally visible | Loading remains centered and readable | NOT EXECUTED | Natural state only |
| C3 | Exercise a naturally available recoverable Today error | Message states that current input/data is preserved and offers retry | NOT EXECUTED | Otherwise cite automation |
| C4 | Exercise a naturally available recoverable Settings error | Message offers retry and does not expose implementation details | NOT EXECUTED | Otherwise cite automation |
| C5 | Retry a recoverable state | Retry is single, clear, keyboard reachable, and does not navigate elsewhere | NOT EXECUTED | Otherwise cite automation |

## D. Accessibility and Platform Quality

| ID | Check | Expected result | Status | Evidence / note |
|---|---|---|---|---|
| D1 | Android maximum font size | Main navigation, AppBar, forms, and Settings have no inaccessible action | NOT EXECUTED | - |
| D2 | Windows Tab and Shift+Tab | Focus order reaches navigation, Settings, fields, and actions predictably | NOT EXECUTED | - |
| D3 | Windows Enter and Space | Focusable navigation and controls activate normally | NOT EXECUTED | - |
| D4 | Android TalkBack or Windows Narrator spot check | navigation, Settings, loading, retry, and common icon actions have readable labels | NOT EXECUTED | - |
| D5 | Enable reduced motion in the operating system | No essential state depends on animation | NOT EXECUTED | - |
| D6 | Resize Windows repeatedly between compact and wide layouts | No crash, stale destination, or incoherent overlap occurs | NOT EXECUTED | - |
| D7 | Compare Android and Windows | Both share hierarchy and semantics without forcing identical geometry | NOT EXECUTED | - |

## E. Regression Boundaries

| ID | Check | Expected result | Status | Evidence / note |
|---|---|---|---|---|
| E1 | Save one ordinary Today change and navigate across modules | Existing data behavior remains unchanged | NOT EXECUTED | - |
| E2 | Inspect Settings, Sync Center, and AI Coach entry behavior | No route, automatic sync, generation, consent, or account behavior changed | NOT EXECUTED | - |

## Current Totals

- PASS: `0`
- FAIL: `0`
- NOT EXECUTED: `30`

Current result: **0 PASS / 0 FAIL / 30 NOT EXECUTED**. The Product Experience
Foundation Gate remains open until the applicable Windows and Android checks
are manually accepted. This Gate does not select the final feature-level visual
direction.
