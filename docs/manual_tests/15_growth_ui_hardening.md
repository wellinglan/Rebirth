# Growth UI Hardening Manual Test

## Status Legend

- `已执行并通过`: the listed check was actually performed and passed.
- `已执行但发现问题`: the check was performed and a defect was observed.
- `未执行`: no claim is made for this environment or device.

Automated Widget tests complement this checklist but do not count as a manual
Windows resize or physical Android result.

## Automated Verification (2026-07-17)

| Check | Result | Status |
|---|---|---|
| `flutter pub get` | Existing dependency graph resolved; no dependency added | 已执行并通过 |
| `flutter analyze` | No issues found | 已执行并通过 |
| `flutter test` | 481 tests passed | 已执行并通过 |
| Responsive Widget matrix | 320/360/412/720/840/1200 and 1.0/1.3/1.5/2.0 text scales | 已执行并通过 |
| `flutter run -d windows` | Debug executable started and exposed a Dart VM Service | 已执行并通过 |
| Split release APK build | armeabi-v7a, arm64-v8a, and x86_64 APKs generated | 已执行并通过 |

These automated results do not change the `未执行` status of physical-device
or hands-on resize, hover, screen-reader, and touch checks below.

## Preconditions

- Use a Sprint 7C build with Flutter database `schemaVersion` 3.
- No FastAPI, Docker, login, server, or network connection is required.
- Prepare local Today, Health, and Journal data containing missing values,
  explicit zeroes, non-zero values, Journal drafts, and completed Journals.
- Confirm Growth is read only and does not alter source records.

## Windows Matrix

| Check | Expected result | Status |
|---|---|---|
| Launch with `flutter run -d windows` | App opens without startup exception | 已执行并通过 |
| 320px window | No horizontal or RenderFlex overflow | 未执行 |
| 360px window | Content remains readable and vertically scrollable | 未执行 |
| 720px window | Summary and chart layout adapts without clipping | 未执行 |
| 840px window | Constrained content and recovery charts remain stable | 未执行 |
| 1200px window | Content stays constrained and does not over-stretch | 未执行 |
| Tab navigation | Focus order is 7 days, 30 days, refresh, Daily Details | 未执行 |
| Enter and Space | Period, refresh, and details controls activate | 未执行 |
| Mouse hover | Refresh tooltip and chart tooltips are readable | 未执行 |
| 2.0 text scale | Header, cards, charts, Journal, and details do not overflow | 未执行 |
| Rapid 7/30 switching | The final selection wins; stale data cannot overwrite it | 未执行 |
| Daily Details | 7/30 rows expand, stay read only, and scroll with the page | 未执行 |
| Refresh success | Old data remains during refresh, then updates atomically | 未执行 |
| Refresh failure | Old data remains; live feedback appears; retry can recover | 未执行 |

Automated coverage exercises widths 320, 360, 412, 720, 840, and 1200 with
text scales 1.0, 1.3, 1.5, and 2.0. Record actual manual results above when the
Windows interactions are performed.

## Android Physical Device Matrix

| Check | Expected result | Status |
|---|---|---|
| Open Growth in portrait | Page opens and the current period is announced | 未执行 |
| Scroll to the bottom | Daily Details and final padding are not obscured | 未执行 |
| Switch 7/30 days | Old data remains during loading; selected state updates | 未执行 |
| Touch chart points | Tooltips show exact date and recorded value | 未执行 |
| Expand Daily Details | All dates and exact values are readable | 未执行 |
| Leave and re-enter | Growth reloads without navigation or state exception | 未执行 |
| Default system font | No clipping or horizontal overflow | 未执行 |
| Large system font | Controls wrap and the page stays vertically scrollable | 未执行 |
| Touch refresh | One request starts and the target remains at least Material size | 未执行 |
| Narrow portrait width | No horizontal or RenderFlex overflow | 未执行 |
| Repeated interaction | No visible stall, crash, or unexpected exit | 未执行 |
| Bottom navigation | Final Daily Details content remains reachable | 未执行 |

Physical Android testing is intentionally marked `未执行` until a device is
connected and each check is performed. For a modern arm64 device, install the
`arm64-v8a` APK from the split release build.

## Data And Accessibility Checks

1. Expand Daily Details in 7-day and 30-day modes and confirm dates are
   ascending and every date appears exactly once.
2. Confirm missing numeric values read `未记录`; confirm explicit zero reads
   `0 分钟`; confirm 65 minutes reads `1 小时 5 分钟`.
3. Confirm Journal reads `未记录`, `已记录，未完成`, or `已完成` without relying on
   color and without describing a draft as failure.
4. With a screen reader or Semantics inspector, verify the page title, selected
   period, date range, refresh state, empty state, expanded state, and complete
   daily row descriptions.
5. Trigger refresh failure and confirm the announcement contains no database
   path, SQL, stack trace, Journal body, or other sensitive content.

## Scope Confirmation

- No previous-period comparison, growth score, streak, AI, network, or sync.
- No Growth persistence table, migration, or database schema change.
- Daily Details reads only the already-loaded `GrowthSnapshot.days`.
- Growth MVP is feature frozen after Sprint 7C; only concrete defect fixes
  should extend this surface.
