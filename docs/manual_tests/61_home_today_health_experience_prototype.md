# Home / Today / Health Experience Prototype Manual Acceptance

> Sprint: 17A.1
> Baseline: `e0de17aa34f24040856d9b92869b295878b66225`
> Gate: **OPEN**
> Current result: **0 PASS / 0 FAIL / 57 NOT EXECUTED**

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

## Gate Rule

Close this prototype Gate only after applicable Windows and Android rows pass
and any visual objection is recorded as a product decision. A closed prototype
Gate permits a separate production-integration Sprint; it does not itself ship
the prototype as the product Home, Today, or Health UI.
