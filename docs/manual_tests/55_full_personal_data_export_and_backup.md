# Full Personal Data Export and Backup Manual Acceptance

> Sprint: **15A**  
> Source baseline: `c835a24c74c2ba3a92894ce6ba05d47fff1ab810`  
> Gate: **OPEN**  
> Result: **0 PASS / 0 FAIL / 54 NOT EXECUTED**  
> Last updated: **2026-08-05**

This matrix must record real Windows and Android product execution. Automated
tests, source inspection, and successful builds are supporting evidence only
and must not be entered as manual PASS.

The exported file is plaintext sensitive JSON. Use test accounts and test
content only. Store the artifact in a controlled test location and remove it
after acceptance according to the tester's data-handling policy.

## Active Acceptance Finding

- On 2026-08-05, the pre-fix Android arm64 build reached this page but stopped
  before the system document picker with the controlled source-read failure.
- The cause was an otherwise complete historical Journal prompt snapshot whose
  source definition was no longer present on that device after earlier sync or
  prompt-configuration history.
- The repository now accepts an absent historical source while still rejecting
  a source definition explicitly owned by another local account. Automated
  regression coverage passes, but C1-C3 remain `NOT EXECUTED` for the post-fix
  APK until the same physical device completes the export and file inspection.

## Preconditions

- Windows Release and Android arm64-v8a Release are built from the same reviewed
  Sprint 15A source.
- Two isolated test accounts, Account A and Account B, are available.
- Account A contains Profile, parent/child Plan goals, Today, dynamic and legacy
  Journal data, prompt configuration, Health notes, and an AI Report with more
  than one immutable version.
- Account B contains distinct sentinel text in every supported module.
- At least one `null`, one numeric `0`, one empty string, Unicode text, a long
  Journal or report body, an archived record, and a soft-deleted record exist.
- No production credentials or real private content are used.
- `$BackupPath` below means the file chosen by the tester; never commit it.

## A. Navigation and Disclosure

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| A1 | On Windows, open Settings -> Personal data and privacy -> Export all personal data. The dedicated page opens. | NOT EXECUTED | |
| A2 | On Android, open the same Settings entry. The dedicated page opens. | NOT EXECUTED | |
| A3 | Confirm the page lists Profile, Plan, Today, Journal, prompt configuration, Health, and AI Reports as the export scope. | NOT EXECUTED | |
| A4 | Confirm the page and confirmation dialog clearly say the JSON is plaintext, may contain sensitive bodies, and is not automatically encrypted. | NOT EXECUTED | |
| A5 | Confirm the page says the current version cannot import or restore the file. | NOT EXECUTED | |
| A6 | Use Back before confirming. Return to Settings without opening a picker or changing product data. | NOT EXECUTED | |

## B. Windows Export

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| B1 | Confirm export on Windows. The native save dialog opens only after confirmation. | NOT EXECUTED | |
| B2 | Verify the suggested name is `rebirth-personal-data-backup-YYYY-MM-DD.json` for the current local day. | NOT EXECUTED | |
| B3 | Save the file and parse it as UTF-8 JSON without replacement characters or truncation. | NOT EXECUTED | |
| B4 | Verify `format_id`, `format_version`, UTC `exported_at`, source schema 11, manifest, counts, hash, and data exist. | NOT EXECUTED | |
| B5 | Verify all seven module IDs are present in the documented stable order. | NOT EXECUTED | |
| B6 | Verify Plan parent/child IDs, dates, lifecycle, archive state, and soft-delete state are reconstructable. | NOT EXECUTED | |
| B7 | Verify expected test Journal responses, Health note/fields, and AI Report body are present and complete. | NOT EXECUTED | |
| B8 | Verify AI Report versions are present once each and sorted by ascending version number. | NOT EXECUTED | |
| B9 | Start another export and cancel the Windows save dialog. No new file is created and no success message is shown. | NOT EXECUTED | |
| B10 | Restart the app and export again. The flow remains available and the same unchanged source facts produce the same module/record structure. | NOT EXECUTED | |

## C. Android Export and Responsive Behavior

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| C1 | Install the reviewed arm64-v8a Release APK and reach the export page while signed in to Account A. | NOT EXECUTED | |
| C2 | Confirm export. Android opens its system document save flow and does not request a private app path. | NOT EXECUTED | |
| C3 | Save, reopen the chosen file with a trusted JSON viewer, and confirm the same manifest and records as Windows. | NOT EXECUTED | |
| C4 | Cancel the Android document flow. No file is created and local data is unchanged. | NOT EXECUTED | |
| C5 | Press Android Back from the confirmation dialog and export page. Dialog then page close normally without starting export. | NOT EXECUTED | |
| C6 | At 320, 360, and 412 logical pixels, scroll the page and dialog. There is no horizontal or RenderFlex overflow and every action remains reachable. | NOT EXECUTED | |
| C7 | At maximum supported font size / TextScaler 2.0, warnings, scope, progress, buttons, and dialog remain readable and operable. | NOT EXECUTED | |

## D. Format Integrity and Privacy

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| D1 | Recalculate SHA-256 over canonical compact JSON of the `data` object with recursively sorted object keys. It equals `payload_sha256`. | NOT EXECUTED | |
| D2 | Count each module's records and compare with both manifest locations and the visible source records. | NOT EXECUTED | |
| D3 | Verify exported `null`, numeric `0`, empty string, and missing/not-applicable facts remain distinguishable. | NOT EXECUTED | |
| D4 | Verify timestamps use UTC ISO-8601 while Today, Journal, Health, and Plan natural dates remain `YYYY-MM-DD`. | NOT EXECUTED | |
| D5 | Verify `growth` and `personal_data_aggregation` appear only in `derived_data_excluded`, not as data modules or copied evidence. | NOT EXECUTED | |
| D6 | Search keys/content for password, password hash, access/refresh credentials, secure storage, API keys, secrets, cloud user/auth session/OAuth/proof/device identifiers. None exist. | NOT EXECUTED | |
| D7 | Search for server version, sync status, cursor, pending operation, conflict payload, remote snapshot, and transport tombstone. None exist. | NOT EXECUTED | |
| D8 | Search for Provider/model runtime data, prompts, canonical input, input hash/snapshot/scope, generation ledger, and usage ledger. None exist. | NOT EXECUTED | |
| D9 | Confirm the file and all UI feedback contain no database path, chosen save path, diagnostic log, stack trace, or internal exception. | NOT EXECUTED | |

## E. Account and Session Boundary

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| E1 | Export Account A and verify only Account A sentinel facts and stable business relations exist. | NOT EXECUTED | |
| E2 | Switch to Account B and export. No Account A title, body, ID, prompt, Health field, or AI Report appears. | NOT EXECUTED | |
| E3 | Start a deliberately long export, switch accounts before the picker, and verify the operation stops without a file. | NOT EXECUTED | |
| E4 | Start a deliberately long export, log out before the picker, and verify the operation stops without a file. | NOT EXECUTED | |
| E5 | In an approved safe SessionRejected fixture, reject the session before the picker and verify the operation stops without a file. | NOT EXECUTED | |
| E6 | Return to Account A and export again. Records are neither duplicated nor replaced by Account B data. | NOT EXECUTED | |

## F. Non-mutation and Local-only Behavior

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| F1 | Compare business bodies and `updatedAt` values before and after export. They are unchanged. | NOT EXECUTED | |
| F2 | Compare AI Report lifecycle/current version/version count and Plan/Journal lifecycle before and after. They are unchanged. | NOT EXECUTED | |
| F3 | Compare sync state, server version, cursor, conflicts, deleted/tombstone state, and last-sync display before and after. They are unchanged. | NOT EXECUTED | |
| F4 | Compare AI consent, personal usage display, and available operational ledger counts before and after. They are unchanged. | NOT EXECUTED | |
| F5 | Disconnect the network and export. No API, token refresh, endpoint probe, AI generation, or sync occurs; the local export still succeeds. | NOT EXECUTED | |

## G. Failure and Scale

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| G1 | Export an account with a large long-term history. Progress is visible, duplicate taps are blocked, and the app remains responsive. | NOT EXECUTED | |
| G2 | Verify an unusually long Journal or AI Report body is complete and not silently truncated or omitted. | NOT EXECUTED | |
| G3 | Verify a report with many immutable versions exports every version once in ascending order. | NOT EXECUTED | |
| G4 | Cause a safe destination write failure. A controlled path-free message appears; retry succeeds without restarting. | NOT EXECUTED | |
| G5 | In an approved source/integrity failure fixture, verify no partial or apparently successful backup file is written. | NOT EXECUTED | |

## H. Keyboard, Accessibility, and Final Regression

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| H1 | On Windows, Tab reaches the export, cancel, and confirm actions in a sensible order with visible focus. | NOT EXECUTED | |
| H2 | Enter and Space activate the focused action once; repeated activation while exporting does not start concurrent exports. | NOT EXECUTED | |
| H3 | Screen-reader semantics announce the sensitive plaintext warning, progress, failure, and action purpose without exposing private content. | NOT EXECUTED | |
| H4 | During export the primary button is disabled, progress is visible, current page content remains, and only one save dialog opens. | NOT EXECUTED | |
| H5 | After success, cancellation, and failure, Settings and all other product modules remain usable across an app restart. | NOT EXECUTED | |
| H6 | Confirm no crash, hidden action, leaked path, or unrelated regression on either Windows or Android. | NOT EXECUTED | |

## Hash Verification Reference

After assigning the exported test file to `$BackupPath`, the following local
Python command is a reference calculation. It reads only the chosen local file
and prints the expected and calculated digests. Do not paste its data into logs
or issue trackers.

```powershell
python -c "import hashlib,json,pathlib; p=pathlib.Path(r'$BackupPath'); d=json.loads(p.read_text(encoding='utf-8')); b=json.dumps(d['data'],ensure_ascii=False,sort_keys=True,separators=(',',':')).encode('utf-8'); print('expected=',d['payload_sha256']); print('actual  =',hashlib.sha256(b).hexdigest())"
```

## Gate Decision

The Gate remains **OPEN** until the user reports actual execution results for
the applicable rows. Any scenario without a safe product-level fixture must
remain `NOT EXECUTED` with its reason; it must not be inferred from automation.
