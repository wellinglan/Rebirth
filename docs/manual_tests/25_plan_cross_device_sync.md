# Manual Test: Plan Cross-device Sync

> Sprint: 10B
> Initial status: all rows are `NOT EXECUTED`
> Environment: Development + Fake Provider + Tailscale private Alpha

Automated tests do not replace this matrix. Do not record tokens, secrets,
public IP addresses, full cloud user IDs, full device IDs, or private Goal text
as evidence.

## Preparation

1. Commit and push the reviewed Sprint 10B changes.
2. Confirm GitHub Quality, including the PostgreSQL marker, passes.
3. Publish the matching API GHCR image.
4. Recreate only the Alpha API container and verify `/health` reports API 1
   and Sync Protocol 2.
5. Build the Windows release client.
6. Install the matching `app-arm64-v8a-release.apk` on Android.
7. Use the same Development User Key on Windows and Android.
8. Register both installations as separate devices.
9. Keep a second Development User Key for isolation testing.
10. Record every row as `PASS`, `FAIL`, or `NOT EXECUTED`.

## Windows Matrix

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Settings says Profile and Plan support manual sync | NOT EXECUTED | - | - |
| 2 | Today, Journal, and Health remain explicitly unsynchronized | NOT EXECUTED | - | - |
| 3 | Create a root Goal and child Goal, then sync Plan | NOT EXECUTED | - | - |
| 4 | Sync progress disables the Plan button and prevents duplicate clicks | NOT EXECUTED | - | - |
| 5 | Success shows upload, pull, delete, and conflict information | NOT EXECUTED | - | - |
| 6 | Repeating sync without changes creates no duplicate Goals | NOT EXECUTED | - | - |
| 7 | Offline failure preserves the current Plan page and local rows | NOT EXECUTED | - | - |
| 8 | Restoring connectivity allows manual retry | NOT EXECUTED | - | - |
| 9 | Profile manual upload and pull still work | NOT EXECUTED | - | - |
| 10 | Restarting the app preserves local Plan data | NOT EXECUTED | - | - |

Windows total: `0 PASS / 0 FAIL / 10 NOT EXECUTED`.

## Android Physical Matrix

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Install the matching arm64-v8a release APK | NOT EXECUTED | - | - |
| 2 | Login and register the Android installation | NOT EXECUTED | - | - |
| 3 | Pull the Windows root and child with readable hierarchy | NOT EXECUTED | - | - |
| 4 | Root and child UUIDs match the Windows records | NOT EXECUTED | - | - |
| 5 | Complete the child and sync Plan | NOT EXECUTED | - | - |
| 6 | Archive and restore the subtree without losing descendants | NOT EXECUTED | - | - |
| 7 | Delete the subtree and confirm it disappears after sync/restart | NOT EXECUTED | - | - |
| 8 | Offline sync failure preserves Android local Plan content | NOT EXECUTED | - | - |
| 9 | Android Back/navigation produces no abnormal exit | NOT EXECUTED | - | - |
| 10 | No background or startup sync occurs | NOT EXECUTED | - | - |

Android total: `0 PASS / 0 FAIL / 10 NOT EXECUTED`.

## Cross-device Closure

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Windows creates and syncs a root and child | NOT EXECUTED | - | - |
| 2 | Android pulls the same Goal UUIDs and parentGoalId | NOT EXECUTED | - | - |
| 3 | Android completes the child and syncs | NOT EXECUTED | - | - |
| 4 | Windows syncs and sees the completed child | NOT EXECUTED | - | - |
| 5 | Windows archives the subtree; Android receives both changes | NOT EXECUTED | - | - |
| 6 | Windows restores the subtree; Android receives both changes | NOT EXECUTED | - | - |
| 7 | Windows deletes the subtree; Android receives tombstones | NOT EXECUTED | - | - |
| 8 | Repeated pulls do not recreate deleted rows or duplicate Goals | NOT EXECUTED | - | - |
| 9 | A second Development User Key cannot pull the first user's Plan | NOT EXECUTED | - | - |
| 10 | Logout and Endpoint changes preserve local Plan SQLite data | NOT EXECUTED | - | - |

Cross-device total: `0 PASS / 0 FAIL / 10 NOT EXECUTED`.

## Conflict And Atomicity

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Edit the same synced Goal independently on both devices | NOT EXECUTED | - | - |
| 2 | First device sync succeeds | NOT EXECUTED | - | - |
| 3 | Second device reports conflict instead of overwriting cloud data | NOT EXECUTED | - | - |
| 4 | Second device retains its local conflicting title/status/dates | NOT EXECUTED | - | - |
| 5 | Conflict count is visible and the Plan cursor is not advanced | NOT EXECUTED | - | - |
| 6 | A mixed conflicting batch creates no partial new Goal | NOT EXECUTED | - | - |
| 7 | Parent-only tombstone is rejected while an active child remains | NOT EXECUTED | - | - |
| 8 | Complete subtree tombstone succeeds atomically | NOT EXECUTED | - | - |

Conflict/atomicity total: `0 PASS / 0 FAIL / 8 NOT EXECUTED`.

## Responsive And Accessibility

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Settings has no overflow at 320/360/412 px | NOT EXECUTED | - | - |
| 2 | Settings remains compact at 720/840/1200 px | NOT EXECUTED | - | - |
| 3 | Text scales 1.0/1.3/1.5/2.0 remain readable | NOT EXECUTED | - | - |
| 4 | Plan status wraps and button Wrap does not overflow | NOT EXECUTED | - | - |
| 5 | Screen reader announces the Plan sync button and status text | NOT EXECUTED | - | - |
| 6 | Tab focuses the Plan button; Enter and Space activate it | NOT EXECUTED | - | - |
| 7 | Existing Plan large-text filter layout remains usable | NOT EXECUTED | - | - |

Responsive/accessibility total:
`0 PASS / 0 FAIL / 7 NOT EXECUTED`.

## Acceptance Status

- Windows: `NOT EXECUTED`.
- Android physical device: `NOT EXECUTED`.
- Cross-device closure: `NOT EXECUTED`.
- Conflict/atomicity: `NOT EXECUTED`.
- Responsive/accessibility: `NOT EXECUTED`.
- Explicit cloud-adoption conflict recovery: deferred to Sprint 10B.1 and not
  represented as a passing row.
