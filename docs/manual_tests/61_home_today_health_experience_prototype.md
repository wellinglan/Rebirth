# Home / Today / Health Experience Prototype Manual Acceptance

> Sprint: 17A.1
> Baseline: `e0de17aa34f24040856d9b92869b295878b66225`
> Prototype Revision 1 baseline: `7a056414896fdfd4ec9731429ef0cd8b7005098d`
> Accepted implementation: `701e2068aefcf82c4f6012be10c0bb7b487a97f3`
> Accepted: **2026-08-20**
> Gate: **CLOSED**
> Current result: **81 PASS / 0 FAIL / 0 NOT EXECUTED**

This matrix is for a developer-enabled Alpha build. It does not approve a new
production Home page. The user accepted the complete Windows/Android prototype
matrix after reviewing the final layout and interaction behavior.

## Preconditions

- Build Windows and Android with `REBIRTH_ENABLE_DEV_LOGIN=true` in a
  non-production environment.
- Sign in and open `Settings -> Developer Options`.
- Record device, OS, build commit, width/orientation, and text scale.
- Before testing, note one real Today/Health value so accidental persistence can
  be detected after leaving the prototype.

## A. Entry and Isolation

| ID | Check | Status | Evidence / notes |
|---|---|---|---|
| A1 | Developer Options shows the prototype entry in an enabled Alpha build | PASS | User accepted final prototype layout and behavior. |
| A2 | The entry clearly says data is not written or synced | PASS | User accepted final prototype layout and behavior. |
| A3 | Production build does not expose the entry | PASS | User accepted final prototype layout and behavior. |
| A4 | Production direct path cannot open the prototype | PASS | User accepted final prototype layout and behavior. |
| A5 | Opening the prototype performs no save, AI call, or sync | PASS | User accepted final prototype layout and behavior. |
| A6 | Switching among all three views preserves only in-memory values | PASS | User accepted final prototype layout and behavior. |
| A7 | Reset clears prototype values without touching real records | PASS | User accepted final prototype layout and behavior. |
| A8 | Back returns naturally to Developer Options | PASS | User accepted final prototype layout and behavior. |

## B. Home Experience

| ID | Check | Status | Evidence / notes |
|---|---|---|---|
| B1 | Local date and clock are readable and correct | PASS | User accepted final prototype layout and behavior. |
| B2 | Current week and current day are understandable | PASS | User accepted final prototype layout and behavior. |
| B3 | The same date keeps a stable local quote after reopening | PASS | User accepted final prototype layout and behavior. |
| B4 | Quote is labelled local and does not imply an AI call | PASS | User accepted final prototype layout and behavior. |
| B5 | Day image is sharp, correctly cropped, and keeps text readable | PASS | User accepted final prototype layout and behavior. |
| B6 | Night image is sharp, correctly cropped, and keeps text readable | PASS | User accepted final prototype layout and behavior. |
| B7 | Priority summary is calm and scannable | PASS | User accepted final prototype layout and behavior. |
| B8 | Health summary does not make medical judgements | PASS | User accepted final prototype layout and behavior. |
| B9 | Today and Health cards open their corresponding prototype views | PASS | User accepted final prototype layout and behavior. |
| B10 | Journal, Plan, Growth, and AI Coach entries navigate correctly | PASS | User accepted final prototype layout and behavior. |

## C. Today Experience

| ID | Check | Status | Evidence / notes |
|---|---|---|---|
| C1 | The page no longer shows a permanent wall of preset chips | PASS | User accepted final prototype layout and behavior. |
| C2 | Android preset action opens a compact bottom sheet | PASS | User accepted final prototype layout and behavior. |
| C3 | Windows preset action opens a compact menu | PASS | User accepted final prototype layout and behavior. |
| C4 | Selecting a research preset updates only the prototype value | PASS | User accepted final prototype layout and behavior. |
| C5 | Selecting a learning preset updates only the prototype value | PASS | User accepted final prototype layout and behavior. |
| C6 | Minute totals split correctly into hours and minutes | PASS | User accepted final prototype layout and behavior. |
| C7 | Priority, mood, energy, and note controls remain usable | PASS | User accepted final prototype layout and behavior. |
| C8 | Simulated save reports that no local record was written | PASS | User accepted final prototype layout and behavior. |
| C9 | Real Today content is unchanged after leaving/restarting | PASS | User accepted final prototype layout and behavior. |

## D. Health and Water Model

| ID | Check | Status | Evidence / notes |
|---|---|---|---|
| D1 | Null water displays as not recorded and an empty cup | PASS | User accepted final prototype layout and behavior. |
| D2 | Explicit zero is visually distinct from null | PASS | User accepted final prototype layout and behavior. |
| D3 | Exact ml text and water level update together | PASS | User accepted final prototype layout and behavior. |
| D4 | Water level transition is gentle and finite | PASS | User accepted final prototype layout and behavior. |
| D5 | Reduced motion updates immediately | PASS | User accepted final prototype layout and behavior. |
| D6 | Above-capacity value remains exact while the cup stays full | PASS | User accepted final prototype layout and behavior. |
| D7 | UI never describes cup capacity as a medical target | PASS | User accepted final prototype layout and behavior. |
| D8 | Exercise and sleep show correct hour/minute conversions | PASS | User accepted final prototype layout and behavior. |
| D9 | Simulated save reports that no local record was written | PASS | User accepted final prototype layout and behavior. |
| D10 | Real Health content is unchanged after leaving/restarting | PASS | User accepted final prototype layout and behavior. |

## E. Increment Input

| ID | Check | Status | Evidence / notes |
|---|---|---|---|
| E1 | Android `+250 ml` updates number and water level | PASS | User accepted final prototype layout and behavior. |
| E2 | Several rapid Android taps lose no increments | PASS | User accepted final prototype layout and behavior. |
| E3 | Android decrement never creates a negative value | PASS | User accepted final prototype layout and behavior. |
| E4 | Android step selection changes 250 to 500 without changing value | PASS | User accepted final prototype layout and behavior. |
| E5 | The next Android increment uses 500 ml | PASS | User accepted final prototype layout and behavior. |
| E6 | Windows mouse can increase, decrease, clear, and change step | PASS | User accepted final prototype layout and behavior. |
| E7 | Windows Tab reaches every stepper action | PASS | User accepted final prototype layout and behavior. |
| E8 | Windows Enter activates the focused increment action | PASS | User accepted final prototype layout and behavior. |
| E9 | Windows Space activates the focused increment action | PASS | User accepted final prototype layout and behavior. |
| E10 | Null, explicit zero, and positive values remain distinguishable | PASS | User accepted final prototype layout and behavior. |
| E11 | Restart discards prototype increments and does not alter a record | PASS | User accepted final prototype layout and behavior. |
| E12 | Increment actions do not trigger sync | PASS | User accepted final prototype layout and behavior. |

## F. Responsive and Accessibility

| ID | Check | Status | Evidence / notes |
|---|---|---|---|
| F1 | Android 320 px portrait has no horizontal or RenderFlex overflow | PASS | User accepted final prototype layout and behavior. |
| F2 | Android 360 px portrait has no horizontal or RenderFlex overflow | PASS | User accepted final prototype layout and behavior. |
| F3 | Android 412 px portrait has no horizontal or RenderFlex overflow | PASS | User accepted final prototype layout and behavior. |
| F4 | Windows 720 px remains usable and scrollable | PASS | User accepted final prototype layout and behavior. |
| F5 | Windows 1200 px remains balanced without stretched controls | PASS | User accepted final prototype layout and behavior. |
| F6 | TextScaler 1.3 and 1.5 preserve complete labels | PASS | User accepted final prototype layout and behavior. |
| F7 | TextScaler 2.0 wraps controls and preserves complete labels | PASS | User accepted final prototype layout and behavior. |
| F8 | TalkBack/Windows semantics announce current value, step, unit, increase, decrease, and selector | PASS | User accepted final prototype layout and behavior. |

## G. Prototype Revision 1 Wellbeing Ratings

| ID | Check | Status | Evidence / notes |
|---|---|---|---|
| G1 | Android Mood moves through every discrete score from 1 to 10 | PASS | User accepted final prototype layout and behavior. |
| G2 | Android Energy selects accurate integer positions with no fractional value | PASS | User accepted final prototype layout and behavior. |
| G3 | A low score uses the restrained soft-red active state | PASS | User accepted final prototype layout and behavior. |
| G4 | A middle score uses the restrained warm-yellow active state | PASS | User accepted final prototype layout and behavior. |
| G5 | A high score uses the restrained soft-green active state | PASS | User accepted final prototype layout and behavior. |
| G6 | The inactive track remains near-white with a visible light boundary | PASS | User accepted final prototype layout and behavior. |
| G7 | The white thumb remains clearly distinguishable at every score | PASS | User accepted final prototype layout and behavior. |
| G8 | Null and score 1 are visibly and semantically different | PASS | User accepted final prototype layout and behavior. |
| G9 | Clearing a score returns it to `未记录` | PASS | User accepted final prototype layout and behavior. |
| G10 | Clearing a score preserves its one-line description | PASS | User accepted final prototype layout and behavior. |
| G11 | The Mood one-line optional description accepts and displays input | PASS | User accepted final prototype layout and behavior. |
| G12 | The Energy one-line optional description accepts and displays input | PASS | User accepted final prototype layout and behavior. |
| G13 | Health body feeling supports the same score and description behavior | PASS | User accepted final prototype layout and behavior. |
| G14 | Switching Home, Today, and Health preserves the current in-memory ratings and descriptions | PASS | User accepted final prototype layout and behavior. |
| G15 | Reset clears all prototype ratings and their descriptions | PASS | User accepted final prototype layout and behavior. |
| G16 | Windows mouse can set and clear every wellbeing rating | PASS | User accepted final prototype layout and behavior. |
| G17 | Windows Tab reaches the slider, clear action, and description; arrow keys adjust one point | PASS | User accepted final prototype layout and behavior. |
| G18 | Windows Enter and Space start an unrecorded rating at a valid discrete value | PASS | User accepted final prototype layout and behavior. |
| G19 | Maximum text size stacks rating regions with no overflow or hidden action | PASS | User accepted final prototype layout and behavior. |
| G20 | A 320 px Android portrait layout has no horizontal overflow | PASS | User accepted final prototype layout and behavior. |
| G21 | Mood, Energy, research, learning, water, exercise, sleep, body feeling, and weight icons are clear but restrained | PASS | User accepted final prototype layout and behavior. |
| G22 | Rating and description operations do not alter production Today or Health records | PASS | User accepted final prototype layout and behavior. |
| G23 | Rating and description operations do not start sync, AI, or network activity | PASS | User accepted final prototype layout and behavior. |
| G24 | Restart discards prototype ratings/descriptions while real data remains unchanged | PASS | User accepted final prototype layout and behavior. |

## Gate Rule

Close this prototype Gate only after applicable Windows and Android rows pass
and any visual objection is recorded as a product decision. A closed prototype
Gate permits a separate production-integration Sprint; it does not itself ship
the prototype as the product Home, Today, or Health UI.
