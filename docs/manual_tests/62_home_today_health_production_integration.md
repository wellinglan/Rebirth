# Home / Today / Health Production Integration Manual Acceptance

> Sprint: 17B
> Baseline: `3eaf4c11f9b7bfdf8b78d18992fd1aaa9abaa593`
> Implementation commit: `cab60cf9cf74ee452f6b082ac37dba342894fc28`
> Sync contract repair commit: `f7b1bb6dcf5aedc1c50bc1951cf6eb7e82309668`
> Gate: **OPEN**
> Result: **34 PASS / 3 FAIL / 14 NOT EXECUTED**
> Blocker: current clients exposed a Server payload-validation mismatch during
> E1-E3; the source fix requires API deployment and cross-device retest.

Use current Windows release and Android arm64 release builds from the same
commit. Use two test accounts for account isolation and, where named, two
devices on the same account. Do not convert automated evidence into manual
PASS. Record exact observations and screenshots for any failure.

| ID | Platform | Check | Status | Evidence / note |
|---|---|---|---|---|
| A1 | Windows | Login opens the production Home by default | PASS | Accepted on 2026-08-20 |
| A2 | Android | Login opens the production Home by default | PASS | Accepted on 2026-08-20 |
| A3 | Both | Home shows local date, weekday, clock, and week calendar | PASS | Accepted on 2026-08-20 |
| A4 | Both | The same natural day keeps the same local quote | PASS | Accepted on 2026-08-20 |
| A5 | Both | Quote is labelled local and does not claim AI generation | PASS | Accepted on 2026-08-20 |
| A6 | Both | Home shows six module cards and each route opens correctly | PASS | Accepted on 2026-08-20 |
| A7 | Both | Opening and refreshing Home creates no blank Today/Health record | PASS | Accepted on 2026-08-20 |
| A8 | Both | Opening Home starts no AI generation or sync | PASS | Accepted on 2026-08-20 |
| A9 | Both | Missing Today/Health data shows a useful empty state | PASS | Accepted on 2026-08-20 |
| A10 | Both | One unavailable summary does not hide the available summary | NOT EXECUTED | No safe product-level module failure injection; automated coverage substitutes |
| B1 | Both | Three priorities save and completion state is retained | PASS | Accepted on 2026-08-20 |
| B2 | Both | Clearing priority text clears its completed state | PASS | Accepted on 2026-08-20 |
| B3 | Both | Mood accepts null and each integer from 1 through 10 | PASS | Accepted on 2026-08-20 |
| B4 | Both | Mood description saves independently and empty text becomes null | PASS | Accepted on 2026-08-20 |
| B5 | Both | Energy accepts null and each integer from 1 through 10 | PASS | Accepted on 2026-08-20 |
| B6 | Both | Energy description saves independently and empty text becomes null | PASS | Accepted on 2026-08-20 |
| B7 | Both | Research/Learning steppers preserve null, explicit 0, and positive minutes | PASS | Accepted on 2026-08-20 |
| B8 | Both | Step selection is on demand and does not alter the current value | PASS | Accepted on 2026-08-20 |
| B9 | Both | Daily note empty text becomes null | PASS | Accepted on 2026-08-20 |
| B10 | Both | Saving disables the button; failure retains input and allows retry | PASS | Accepted on 2026-08-20 |
| B11 | Both | Saving Today refreshes its Home summary | PASS | Accepted on 2026-08-20 |
| C1 | Both | Water null, explicit 0, and positive values remain distinct | PASS | Accepted on 2026-08-20 |
| C2 | Android | Repeated +250 ml taps lose no increments and cup updates | PASS | Accepted on 2026-08-20 |
| C3 | Windows | Mouse and keyboard operate water increment/decrement/step selector | PASS | Accepted on 2026-08-20 |
| C4 | Both | Water decrement never goes below 0 and null decrement stays null | PASS | Accepted on 2026-08-20 |
| C5 | Both | 100/250/500 ml steps work; changing step does not change value | PASS | Accepted on 2026-08-20 |
| C6 | Both | Above-capacity water stays exact in text while cup remains full | PASS | Accepted on 2026-08-20 |
| C7 | Both | Sleep/Exercise steppers preserve null, 0, and total minutes | PASS | Accepted on 2026-08-20 |
| C8 | Both | Physical State accepts null and each integer from 1 through 10 | PASS | Accepted on 2026-08-20 |
| C9 | Both | Physical State description saves independently; blank becomes null | PASS | Accepted on 2026-08-20 |
| C10 | Both | Weight, exercise type, note, and hidden Health fields are preserved | PASS | Accepted on 2026-08-20 |
| C11 | Both | Saving Health refreshes its Home summary | PASS | Accepted on 2026-08-20 |
| C12 | Both | Water capacity text makes no medical target or diagnosis claim | PASS | Accepted on 2026-08-20 |
| D1 | Both | Restart preserves Today scores, descriptions, durations, and null/0 | PASS | Accepted on 2026-08-20 |
| D2 | Both | Restart preserves Health water, durations, score, description, and hidden fields | PASS | Accepted on 2026-08-20 |
| D3 | Migration | A schema-12 1/2/3/4/5 score reads as 2/4/6/8/10 | NOT EXECUTED | No retained pre-upgrade fixture; automated migration coverage substitutes |
| D4 | Migration | Upgrade does not make old records look newly edited or conflicted | NOT EXECUTED | No retained pre-upgrade fixture; automated migration coverage substitutes |
| E1 | Cross-device | Current clients sync Today score, scale, and both descriptions | FAIL | Pre-fix Server rejected the expanded payload; deploy fixed API and retest |
| E2 | Cross-device | Current clients sync Health score, scale, and description | FAIL | Pre-fix Server rejected the expanded payload; deploy fixed API and retest |
| E3 | Cross-device | null, 0, hidden fields, tombstones, and cursor behavior do not regress | FAIL | Blocked by the same pre-fix payload rejection; deploy fixed API and retest |
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

- PASS: 34
- FAIL: 3
- NOT EXECUTED: 14
- Gate: **OPEN**
- Blocking evidence: the fixed API has not yet been deployed, E1-E5 have not
  passed after deployment, and account-isolation/accessibility execution is
  still outstanding. D3-D4 and A10 retain explicit automated substitutions.
