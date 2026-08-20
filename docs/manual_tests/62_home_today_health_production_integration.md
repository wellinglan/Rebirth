# Home / Today / Health Production Integration Manual Acceptance

> Sprint: 17B
> Baseline: `3eaf4c11f9b7bfdf8b78d18992fd1aaa9abaa593`
> Implementation commit: `cab60cf9cf74ee452f6b082ac37dba342894fc28`
> Gate: **OPEN**
> Result: **0 PASS / 0 FAIL / 48 NOT EXECUTED**

Use current Windows release and Android arm64 release builds from the same
commit. Use two test accounts for account isolation and, where named, two
devices on the same account. Do not convert automated evidence into manual
PASS. Record exact observations and screenshots for any failure.

| ID | Platform | Check | Status | Evidence / note |
|---|---|---|---|---|
| A1 | Windows | Login opens the production Home by default | NOT EXECUTED | |
| A2 | Android | Login opens the production Home by default | NOT EXECUTED | |
| A3 | Both | Home shows local date, weekday, clock, and week calendar | NOT EXECUTED | |
| A4 | Both | The same natural day keeps the same local quote | NOT EXECUTED | |
| A5 | Both | Quote is labelled local and does not claim AI generation | NOT EXECUTED | |
| A6 | Both | Home shows six module cards and each route opens correctly | NOT EXECUTED | |
| A7 | Both | Opening and refreshing Home creates no blank Today/Health record | NOT EXECUTED | |
| A8 | Both | Opening Home starts no AI generation or sync | NOT EXECUTED | |
| A9 | Both | Missing Today/Health data shows a useful empty state | NOT EXECUTED | |
| A10 | Both | One unavailable summary does not hide the available summary | NOT EXECUTED | |
| B1 | Both | Three priorities save and completion state is retained | NOT EXECUTED | |
| B2 | Both | Clearing priority text clears its completed state | NOT EXECUTED | |
| B3 | Both | Mood accepts null and each integer from 1 through 10 | NOT EXECUTED | |
| B4 | Both | Mood description saves independently and empty text becomes null | NOT EXECUTED | |
| B5 | Both | Energy accepts null and each integer from 1 through 10 | NOT EXECUTED | |
| B6 | Both | Energy description saves independently and empty text becomes null | NOT EXECUTED | |
| B7 | Both | Research/Learning steppers preserve null, explicit 0, and positive minutes | NOT EXECUTED | |
| B8 | Both | Step selection is on demand and does not alter the current value | NOT EXECUTED | |
| B9 | Both | Daily note empty text becomes null | NOT EXECUTED | |
| B10 | Both | Saving disables the button; failure retains input and allows retry | NOT EXECUTED | |
| B11 | Both | Saving Today refreshes its Home summary | NOT EXECUTED | |
| C1 | Both | Water null, explicit 0, and positive values remain distinct | NOT EXECUTED | |
| C2 | Android | Repeated +250 ml taps lose no increments and cup updates | NOT EXECUTED | |
| C3 | Windows | Mouse and keyboard operate water increment/decrement/step selector | NOT EXECUTED | |
| C4 | Both | Water decrement never goes below 0 and null decrement stays null | NOT EXECUTED | |
| C5 | Both | 100/250/500 ml steps work; changing step does not change value | NOT EXECUTED | |
| C6 | Both | Above-capacity water stays exact in text while cup remains full | NOT EXECUTED | |
| C7 | Both | Sleep/Exercise steppers preserve null, 0, and total minutes | NOT EXECUTED | |
| C8 | Both | Physical State accepts null and each integer from 1 through 10 | NOT EXECUTED | |
| C9 | Both | Physical State description saves independently; blank becomes null | NOT EXECUTED | |
| C10 | Both | Weight, exercise type, note, and hidden Health fields are preserved | NOT EXECUTED | |
| C11 | Both | Saving Health refreshes its Home summary | NOT EXECUTED | |
| C12 | Both | Water capacity text makes no medical target or diagnosis claim | NOT EXECUTED | |
| D1 | Both | Restart preserves Today scores, descriptions, durations, and null/0 | NOT EXECUTED | |
| D2 | Both | Restart preserves Health water, durations, score, description, and hidden fields | NOT EXECUTED | |
| D3 | Migration | A schema-12 1/2/3/4/5 score reads as 2/4/6/8/10 | NOT EXECUTED | Requires retained pre-upgrade fixture |
| D4 | Migration | Upgrade does not make old records look newly edited or conflicted | NOT EXECUTED | Requires retained pre-upgrade fixture |
| E1 | Cross-device | Current clients sync Today score, scale, and both descriptions | NOT EXECUTED | |
| E2 | Cross-device | Current clients sync Health score, scale, and description | NOT EXECUTED | |
| E3 | Cross-device | null, 0, hidden fields, tombstones, and cursor behavior do not regress | NOT EXECUTED | |
| E4 | Conflict | Today Adopt Remote and Keep Local preserve normalized score/descriptions | NOT EXECUTED | Create separate conflicts for both choices |
| E5 | Conflict | Health Adopt Remote and Keep Local preserve normalized score/description | NOT EXECUTED | Create separate conflicts for both choices |
| E6 | Compatibility | Both devices are upgraded before editing new score/description fields | NOT EXECUTED | Old clients may strip unknown optional fields |
| F1 | Accounts | Account A Home/Today/Health data is invisible to Account B | NOT EXECUTED | |
| F2 | Accounts | Logout clears the previous account Home summary | NOT EXECUTED | |
| F3 | Export | Full export contains normalized 1-10 scores, descriptions, and scale metadata | NOT EXECUTED | Inspect without publishing personal content |
| F4 | Privacy | UI/logs expose no credential, token, endpoint secret, prompt, or other account data | NOT EXECUTED | |
| G1 | Responsive | Android 320/360/412 px has no horizontal or RenderFlex overflow | NOT EXECUTED | |
| G2 | Responsive | Windows 720/1200 px remains readable and reasonably compact | NOT EXECUTED | |
| G3 | Accessibility | TextScaler 1.0/1.3/1.5/2.0 keeps text and actions available | NOT EXECUTED | |
| G4 | Accessibility | Tab, Enter, Space, arrows, TalkBack, and Semantics identify values/actions | NOT EXECUTED | |

## Final Decision

- PASS: 0
- FAIL: 0
- NOT EXECUTED: 48
- Gate: **OPEN**
- Blocking evidence: Windows and Android production, persistence, migration,
  cross-device sync/conflict, account-isolation, and accessibility execution
  have not yet been recorded.
