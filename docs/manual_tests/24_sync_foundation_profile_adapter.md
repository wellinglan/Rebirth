# Manual Test: Sync Foundation And Profile Adapter

> Sprint: 10A
> Initial status: all items are `NOT EXECUTED`
> Scope: Development login, registered devices, manual canonical Profile sync

Automated tests do not replace this matrix. Use the configured Tailscale
private Alpha Endpoint. Do not record tokens, full cloud user IDs, full device
IDs, Profile private text, secrets, or public IP addresses as evidence.

## Preparation

1. Build the current Windows release client.
2. Install the current `app-arm64-v8a-release.apk` on the Android device.
3. Confirm `/health` reports API 1 and Sync Protocol 2.
4. Use Development login and the same Development User Key on both clients.
5. Keep a second Development User Key available for isolation checks.
6. Record each row as `PASS`, `FAIL`, or `NOT EXECUTED`.

## Windows Matrix

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Sign in and confirm the intended Endpoint | NOT EXECUTED | - | - |
| 2 | Register the current Windows installation | NOT EXECUTED | - | - |
| 3 | Edit local Profile and manually upload Profile | NOT EXECUTED | - | - |
| 4 | A successful upload shows controlled Profile status text | NOT EXECUTED | - | - |
| 5 | Repeating upload without a local change is idempotent | NOT EXECUTED | - | - |
| 6 | Pull can apply a newer Android Profile to the same local UUID | NOT EXECUTED | - | - |
| 7 | Offline push/pull fails without clearing local Profile | NOT EXECUTED | - | - |
| 8 | Restoring the network allows a manual retry | NOT EXECUTED | - | - |
| 9 | An unavailable Endpoint produces a readable error | NOT EXECUTED | - | - |
| 10 | An expired/invalid session asks the user to sign in again | NOT EXECUTED | - | - |
| 11 | Narrow window and large text do not overflow sync controls | NOT EXECUTED | - | - |
| 12 | No abnormal exit occurs | NOT EXECUTED | - | - |

Windows total: `0 PASS / 0 FAIL / 12 NOT EXECUTED`.

## Android Physical Matrix

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Install the current arm64-v8a release APK | NOT EXECUTED | - | - |
| 2 | Sign in with the same Development User Key as Windows | NOT EXECUTED | - | - |
| 3 | Register the Android installation as a separate device | NOT EXECUTED | - | - |
| 4 | Pull and display the Profile uploaded by Windows | NOT EXECUTED | - | - |
| 5 | The Android local Profile UUID remains its existing local UUID | NOT EXECUTED | - | - |
| 6 | Edit Android Profile and manually upload it | NOT EXECUTED | - | - |
| 7 | Repeating pull/upload does not create duplicate local Profiles | NOT EXECUTED | - | - |
| 8 | Offline failure preserves Android local Profile content | NOT EXECUTED | - | - |
| 9 | Maximum text remains readable and controls remain usable | NOT EXECUTED | - | - |
| 10 | Android back/navigation and sync produce no abnormal exit | NOT EXECUTED | - | - |

Android total: `0 PASS / 0 FAIL / 10 NOT EXECUTED`.

## Cross-Device Closure

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Windows edits and uploads Profile | NOT EXECUTED | - | - |
| 2 | Android pulls and sees that update | NOT EXECUTED | - | - |
| 3 | Android edits and uploads Profile | NOT EXECUTED | - | - |
| 4 | Windows pulls and sees that update | NOT EXECUTED | - | - |
| 5 | Windows and Android local Profile UUIDs remain different | NOT EXECUTED | - | - |
| 6 | Cloud canonical Profile identity remains one `user_profiles/profile` row | NOT EXECUTED | - | - |
| 7 | A different Development User Key cannot pull the first user's Profile | NOT EXECUTED | - | - |
| 8 | Endpoint change requires re-login/device registration but preserves local SQLite data | NOT EXECUTED | - | - |
| 9 | Plan records do not cross devices | NOT EXECUTED | - | - |
| 10 | Today records do not cross devices | NOT EXECUTED | - | - |
| 11 | Journal records do not cross devices | NOT EXECUTED | - | - |
| 12 | Health records do not cross devices | NOT EXECUTED | - | - |

Cross-device total: `0 PASS / 0 FAIL / 12 NOT EXECUTED`.

## Acceptance Status

- Sprint 10A Windows manual acceptance: `NOT EXECUTED`.
- Sprint 10A Android physical acceptance: `NOT EXECUTED`.
- Sprint 10A cross-device closure: `NOT EXECUTED`.
- Sprint 9C manual acceptance remains deferred and is not changed by this
  matrix.
- Development + Fake Provider + Tailscale private Alpha remains the current
  environment; it is not Production.
