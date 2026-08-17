# Home / Today / Health Experience Prototype Manual Acceptance

> Sprint: 17A.1
> Baseline: `e0de17aa34f24040856d9b92869b295878b66225`
> Prototype Revision 1 baseline: `7a056414896fdfd4ec9731429ef0cd8b7005098d`
> Gate: **OPEN**
> Current result: **0 PASS / 0 FAIL / 81 NOT EXECUTED**

This matrix is for a developer-enabled Alpha build. It does not approve a new
production Home page. Record only observed execution as PASS or FAIL; keep every
unrun row as NOT EXECUTED.

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
| A1 | Developer Options shows the prototype entry in an enabled Alpha build | NOT EXECUTED | |
| A2 | The entry clearly says data is not written or synced | NOT EXECUTED | |
| A3 | Production build does not expose the entry | NOT EXECUTED | |
| A4 | Production direct path cannot open the prototype | NOT EXECUTED | |
| A5 | Opening the prototype performs no save, AI call, or sync | NOT EXECUTED | |
| A6 | Switching among all three views preserves only in-memory values | NOT EXECUTED | |
| A7 | Reset clears prototype values without touching real records | NOT EXECUTED | |
| A8 | Back returns naturally to Developer Options | NOT EXECUTED | |

## B. Home Experience

| ID | Check | Status | Evidence / notes |
|---|---|---|---|
| B1 | Local date and clock are readable and correct | NOT EXECUTED | |
| B2 | Current week and current day are understandable | NOT EXECUTED | |
| B3 | The same date keeps a stable local quote after reopening | NOT EXECUTED | |
| B4 | Quote is labelled local and does not imply an AI call | NOT EXECUTED | |
| B5 | Day image is sharp, correctly cropped, and keeps text readable | NOT EXECUTED | |
| B6 | Night image is sharp, correctly cropped, and keeps text readable | NOT EXECUTED | |
| B7 | Priority summary is calm and scannable | NOT EXECUTED | |
| B8 | Health summary does not make medical judgements | NOT EXECUTED | |
| B9 | Today and Health cards open their corresponding prototype views | NOT EXECUTED | |
| B10 | Journal, Plan, Growth, and AI Coach entries navigate correctly | NOT EXECUTED | |

## C. Today Experience

| ID | Check | Status | Evidence / notes |
|---|---|---|---|
| C1 | The page no longer shows a permanent wall of preset chips | NOT EXECUTED | |
| C2 | Android preset action opens a compact bottom sheet | NOT EXECUTED | |
| C3 | Windows preset action opens a compact menu | NOT EXECUTED | |
| C4 | Selecting a research preset updates only the prototype value | NOT EXECUTED | |
| C5 | Selecting a learning preset updates only the prototype value | NOT EXECUTED | |
| C6 | Minute totals split correctly into hours and minutes | NOT EXECUTED | |
| C7 | Priority, mood, energy, and note controls remain usable | NOT EXECUTED | |
| C8 | Simulated save reports that no local record was written | NOT EXECUTED | |
| C9 | Real Today content is unchanged after leaving/restarting | NOT EXECUTED | |

## D. Health and Water Model

| ID | Check | Status | Evidence / notes |
|---|---|---|---|
| D1 | Null water displays as not recorded and an empty cup | NOT EXECUTED | |
| D2 | Explicit zero is visually distinct from null | NOT EXECUTED | |
| D3 | Exact ml text and water level update together | NOT EXECUTED | |
| D4 | Water level transition is gentle and finite | NOT EXECUTED | |
| D5 | Reduced motion updates immediately | NOT EXECUTED | |
| D6 | Above-capacity value remains exact while the cup stays full | NOT EXECUTED | |
| D7 | UI never describes cup capacity as a medical target | NOT EXECUTED | |
| D8 | Exercise and sleep show correct hour/minute conversions | NOT EXECUTED | |
| D9 | Simulated save reports that no local record was written | NOT EXECUTED | |
| D10 | Real Health content is unchanged after leaving/restarting | NOT EXECUTED | |

## E. Increment Input

| ID | Check | Status | Evidence / notes |
|---|---|---|---|
| E1 | Android `+250 ml` updates number and water level | NOT EXECUTED | |
| E2 | Several rapid Android taps lose no increments | NOT EXECUTED | |
| E3 | Android decrement never creates a negative value | NOT EXECUTED | |
| E4 | Android step selection changes 250 to 500 without changing value | NOT EXECUTED | |
| E5 | The next Android increment uses 500 ml | NOT EXECUTED | |
| E6 | Windows mouse can increase, decrease, clear, and change step | NOT EXECUTED | |
| E7 | Windows Tab reaches every stepper action | NOT EXECUTED | |
| E8 | Windows Enter activates the focused increment action | NOT EXECUTED | |
| E9 | Windows Space activates the focused increment action | NOT EXECUTED | |
| E10 | Null, explicit zero, and positive values remain distinguishable | NOT EXECUTED | |
| E11 | Restart discards prototype increments and does not alter a record | NOT EXECUTED | |
| E12 | Increment actions do not trigger sync | NOT EXECUTED | |

## F. Responsive and Accessibility

| ID | Check | Status | Evidence / notes |
|---|---|---|---|
| F1 | Android 320 px portrait has no horizontal or RenderFlex overflow | NOT EXECUTED | |
| F2 | Android 360 px portrait has no horizontal or RenderFlex overflow | NOT EXECUTED | |
| F3 | Android 412 px portrait has no horizontal or RenderFlex overflow | NOT EXECUTED | |
| F4 | Windows 720 px remains usable and scrollable | NOT EXECUTED | |
| F5 | Windows 1200 px remains balanced without stretched controls | NOT EXECUTED | |
| F6 | TextScaler 1.3 and 1.5 preserve complete labels | NOT EXECUTED | |
| F7 | TextScaler 2.0 wraps controls and preserves complete labels | NOT EXECUTED | |
| F8 | TalkBack/Windows semantics announce current value, step, unit, increase, decrease, and selector | NOT EXECUTED | |

## G. Prototype Revision 1 Wellbeing Ratings

| ID | Check | Status | Evidence / notes |
|---|---|---|---|
| G1 | Android Mood moves through every discrete score from 1 to 10 | NOT EXECUTED | |
| G2 | Android Energy selects accurate integer positions with no fractional value | NOT EXECUTED | |
| G3 | A low score uses the restrained soft-red active state | NOT EXECUTED | |
| G4 | A middle score uses the restrained warm-yellow active state | NOT EXECUTED | |
| G5 | A high score uses the restrained soft-green active state | NOT EXECUTED | |
| G6 | The inactive track remains near-white with a visible light boundary | NOT EXECUTED | |
| G7 | The white thumb remains clearly distinguishable at every score | NOT EXECUTED | |
| G8 | Null and score 1 are visibly and semantically different | NOT EXECUTED | |
| G9 | Clearing a score returns it to `未记录` | NOT EXECUTED | |
| G10 | Clearing a score preserves its one-line description | NOT EXECUTED | |
| G11 | The Mood one-line optional description accepts and displays input | NOT EXECUTED | |
| G12 | The Energy one-line optional description accepts and displays input | NOT EXECUTED | |
| G13 | Health body feeling supports the same score and description behavior | NOT EXECUTED | |
| G14 | Switching Home, Today, and Health preserves the current in-memory ratings and descriptions | NOT EXECUTED | |
| G15 | Reset clears all prototype ratings and their descriptions | NOT EXECUTED | |
| G16 | Windows mouse can set and clear every wellbeing rating | NOT EXECUTED | |
| G17 | Windows Tab reaches the slider, clear action, and description; arrow keys adjust one point | NOT EXECUTED | |
| G18 | Windows Enter and Space start an unrecorded rating at a valid discrete value | NOT EXECUTED | |
| G19 | Maximum text size stacks rating regions with no overflow or hidden action | NOT EXECUTED | |
| G20 | A 320 px Android portrait layout has no horizontal overflow | NOT EXECUTED | |
| G21 | Mood, Energy, research, learning, water, exercise, sleep, body feeling, and weight icons are clear but restrained | NOT EXECUTED | |
| G22 | Rating and description operations do not alter production Today or Health records | NOT EXECUTED | |
| G23 | Rating and description operations do not start sync, AI, or network activity | NOT EXECUTED | |
| G24 | Restart discards prototype ratings/descriptions while real data remains unchanged | NOT EXECUTED | |

## Gate Rule

Close this prototype Gate only after applicable Windows and Android rows pass
and any visual objection is recorded as a product decision. A closed prototype
Gate permits a separate production-integration Sprint; it does not itself ship
the prototype as the product Home, Today, or Health UI.
