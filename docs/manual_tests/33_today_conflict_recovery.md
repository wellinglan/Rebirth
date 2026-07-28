# Manual Test: Today Conflict Recovery

> Sprint: 11A.1
> Execution date: 2026-07-28
> Status: PASS
> Baseline: `86f0f3ce35e44582374ae1b4863bd2c5f965e7e6`
> Flutter schema: 8
> API: 1
> Sync Protocol: 2

Record only `PASS`, `FAIL`, or `NOT EXECUTED`. Do not record a User Key,
token, complete private Endpoint, Today note body, raw payload, database copy,
or private UUID. Automated evidence does not count as manual PASS.

## Preconditions

- Install the exact Windows release and arm64-v8a Android release APK.
- Deploy the exact Sprint API image without rebuilding PostgreSQL or deleting
  its volume.
- Confirm `/health` reports API 1 and Sync Protocol 2.
- Use one disposable verified account on both registered devices.
- Confirm manual Profile, Plan, and Today sync are available.
- Prepare different local Health values on both devices.

## A. Delete

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Windows deletes current Today after confirmation | PASS | Confirmed deletion completed |
| 2 | Confirmation states Health is preserved and sync is manual | PASS | Confirmation wording was correct |
| 3 | Windows manually uploads the tombstone | PASS | Manual tombstone upload completed |
| 4 | Android pulls and deleted Today content disappears | PASS | Deleted Today disappeared after pull |
| 5 | Android same-day Health remains unchanged | PASS | Same-day Health was preserved |
| 6 | Android restart still shows preserved Health | PASS | Health remained after restart |
| 7 | Android creates and uploads a new same-date Today | PASS | New same-date Today uploaded |
| 8 | Windows pulls it with one active Today and no duplicate | PASS | One active record remained |
| 9 | Historical delete follows the same confirmation and Health rules | PASS | Historical delete matched the rules |

## B. Same UUID Conflict

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Both devices edit one synchronized Today before pulling | PASS | Competing edits were prepared |
| 2 | First device uploads successfully | PASS | First upload completed |
| 3 | Second device receives a visible conflict | PASS | Conflict was visible |
| 4 | Hydration completes without overwriting local content | PASS | Local content remained intact |
| 5 | Adopt confirmation uses Today-specific wording | PASS | Today wording was shown |
| 6 | Adopt makes both devices converge on the Server version | PASS | Both devices converged |
| 7 | A second conflict can be created after resolution | PASS | Follow-up conflict was created |
| 8 | Keep-local confirmation uses Today-specific wording | PASS | Today wording was shown |
| 9 | Keep-local upload makes both devices converge | PASS | Both devices converged |
| 10 | Restart during a requested operation preserves retry state | PASS | Retry state survived restart |

## C. Tombstone Conflict

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | One device deletes while the other edits Today | PASS | Delete/edit race was prepared |
| 2 | Stale device sees an explicit tombstone conflict | PASS | Tombstone conflict was explicit |
| 3 | Local content remains until a choice is confirmed | PASS | Local content was retained |
| 4 | Adopt remote delete soft-deletes local Today | PASS | Remote deletion was adopted |
| 5 | Same-day Health survives adopt remote delete | PASS | Same-day Health was preserved |
| 6 | Keep local upsert restores chosen local content | PASS | Chosen local content was restored |
| 7 | Keep local tombstone propagates deletion | PASS | Chosen deletion propagated |
| 8 | Repeated pull/push causes no duplicate or silent overwrite | PASS | No duplicate or overwrite occurred |

## D. Same-date Different UUID

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Both devices offline-create Today for the same date | PASS | Independent records were created |
| 2 | First identity uploads successfully | PASS | First identity uploaded |
| 3 | Second upload becomes a structured conflict | PASS | Structured conflict was shown |
| 4 | Second device retains its draft and shows remote summary | PASS | Draft and remote summary remained |
| 5 | Adopt converges to the cloud identity | PASS | Cloud identity became canonical |
| 6 | A recreated collision can use keep local | PASS | Keep-local path completed |
| 7 | Both devices finish with one active Today for the date | PASS | One active record remained |
| 8 | Same-day Health remains unchanged through both choices | PASS | Health remained unchanged |
| 9 | Restart preserves requested choice and remote identity | PASS | Choice and identity survived restart |

## E. Failure And Retry

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Offline hydration fails without losing local content | PASS | Local content survived failure |
| 2 | Reconnect and explicit hydration retry succeeds | PASS | Explicit retry completed |
| 3 | Adopt network failure remains retryable | PASS | Adopt remained retryable |
| 4 | Keep-local network failure remains retryable and pending | PASS | Pending state was preserved |
| 5 | Repeated taps while busy do not start parallel operations | PASS | Duplicate execution was blocked |
| 6 | Restart exposes Continue for a requested operation | PASS | Continue was available |
| 7 | No crash, duplicate Today, or silent Health change occurs | PASS | No regression was observed |

## F. UI And Accessibility

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Windows narrow conflict detail is readable and scrollable | PASS | Detail remained readable |
| 2 | Android portrait has no horizontal overflow | PASS | No overflow was observed |
| 3 | Android maximum font keeps summaries and actions readable | PASS | Content remained operable |
| 4 | Confirmation dialogs scroll with visible actions | PASS | Dialog actions remained visible |
| 5 | Back and cancel make no data change | PASS | No data changed |
| 6 | Status and actions do not rely on color alone | PASS | Text and controls conveyed state |
| 7 | Today conflict screens contain no incorrect Plan wording | PASS | Wording remained Today-specific |
| 8 | No raw JSON, full UUID, token, or Endpoint is exposed | PASS | No sensitive raw value was exposed |

## Final Gate

| Area | PASS | FAIL | NOT EXECUTED |
|---|---:|---:|---:|
| Delete | 9 | 0 | 0 |
| Same UUID conflict | 10 | 0 | 0 |
| Tombstone conflict | 8 | 0 | 0 |
| Same-date different UUID | 9 | 0 | 0 |
| Failure and retry | 7 | 0 | 0 |
| UI and accessibility | 8 | 0 | 0 |
| **Total** | **51** | **0** | **0** |

Today Sync Product Gate: `CLOSED / ACCEPTED`.

Account Boundary Isolation Gate:
`CONDITIONAL ACCEPTED / deferred environment evidence`.

The tester confirmed all 51 product checks behaved as expected on the
Windows and Android release clients. Sprint 11A.1 has no remaining Today
product release blocker. Internal invariant results remain documented as
automated evidence.
