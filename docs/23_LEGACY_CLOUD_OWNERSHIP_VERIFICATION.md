# Legacy Cloud Ownership Verification

> Sprint: 10B.3
> Status: implemented; automated and manual release evidence recorded separately
> API: 1
> Sync Protocol: 2
> Flutter schema: 7

## Why Verification Exists

`legacy_claim` proves that the signed-in account now owns one local Profile
data space. It does not prove that historical `server_version`,
`last_synced_at`, tombstones, conflicts, or origin-device metadata were
created under that same cloud account. Automatically enabling sync could send
old account data through a new account scope.

The safe default is `legacy_review_required`. Local business features remain
available, while Profile and Plan synchronization stop before cursor access,
local collection, or network work.

## Separate States

The implementation keeps five concepts independent:

1. Development login proves the current Alpha identity.
2. `cloud_account_bindings` defines local data ownership.
3. ownership verification proves historical cloud metadata.
4. sync eligibility controls whether the Coordinator may run.
5. AI Consent controls AI data sharing and is never changed here.

## Server Contract

`POST /sync/verify-ownership` requires a valid Rebirth access token. The
request is:

```json
{
  "evidence": [
    {
      "table": "goals",
      "id": "<record-id>",
      "server_version": 17,
      "metadata_fingerprint": "<64 lowercase hex characters>"
    }
  ]
}
```

Only `user_profiles` and `goals` are allowed. The Profile record ID is the
existing canonical `profile` key. The SHA-256 input is canonical JSON
containing:

- `deleted_at`;
- `origin_device_id`;
- `record_id`;
- `server_version`;
- `table`;
- `updated_at`.

No business payload, token, user ID, local Profile ID, cursor, conflict
snapshot, or AI data appears in the body. Pydantic rejects extra ownership
claims. The Server derives the owner exclusively from the JWT.

The response contains `status`, verified/rejected/unknown counts, and a
whitelisted reason. Outcomes are:

- `verified`: every submitted row exactly matches current-JWT remote metadata,
  or a stable Goal UUID is now at a newer version under that same account;
- `unknown`: evidence is absent on this Server or there is no verifiable row;
- `rejected`: metadata mismatches the current user's row or exact evidence is
  owned by another user.

The response never identifies another user or returns stored payload.

## Stable And Conservative Evidence

The current Server stores each sync item's latest state, not version history.
Goal UUID is stable identity, so a newer version under the same authenticated
account verifies legitimate stale evidence. The same Goal UUID under another
account is rejected.

The canonical Profile record ID is shared by all accounts and cannot provide
that proof. Stale Profile-only evidence therefore returns unknown unless an
exact row under another account proves rejection. The client prefers synced
Goal evidence and falls back to Profile only when no synced Goal exists.
A personal data space with more than 500 verifiable rows remains blocked
pending a future bounded proof design.

## Flutter State Machine

```text
legacy_review_required + not_verified/failed
  -> user taps verify
  -> recheck Session, Endpoint, active Profile, binding
  -> collect metadata-only evidence
  -> authenticated Server verification
  -> recheck Session and binding
     -> verified: ready + verified
     -> unknown: legacy_review_required + not_verified
     -> rejected: legacy_review_required + failed
```

The result transaction records `verification_time`,
`server_sync_metadata_v1`, and a structured reason. It never overwrites
`ownership_confirmed_at`.

Schema 6 to 7 adds:

- `verification_status`;
- `verification_time`;
- `verification_method`;
- `verification_reason`.

Existing `ready` bindings migrate to `verified` using
`account_space_creation`; existing legacy quarantine remains not verified.
No business table changes.

## Sync Guard

The authoritative order remains:

```text
Auth scope
  -> exact binding
  -> sync eligibility and verified ownership
  -> endpoint/device/cursor/collect/network
```

Settings disables sync for usability, but cannot bypass the Coordinator
guard. Success refreshes Account, Profile/Plan sync, Settings, cursor scope,
and conflict providers. It does not start a sync.

## Preservation

Verification does not:

- read, clear, advance, or reassign a cursor;
- delete, recreate, resolve, or supersede a conflict;
- modify a tombstone or local `server_version`;
- upload or download Profile/Plan data;
- add Today, Journal, Health, Growth, or AI synchronization;
- change AI pending state or AI Consent.

## Failure And Retry

Network and parsing failures write no verification result and can be retried.
Unknown and rejected Server decisions are persisted for honest UI state but
keep synchronization closed. Session, Endpoint, Profile, or binding changes
during the request reject the result before commit.

## Production Authentication Route

This proof currently runs under Development User Key JWT sessions. Future
OAuth, WeChat, refresh/revoke, secure token storage, and signing-key rotation
can replace the login mechanism without changing the ownership proof:
verification must continue to derive cloud identity from a valid Server-side
session and must never trust a client-provided user ID.

## Release Gate

Automated tests cannot prove the deployed Alpha account and Endpoint history.
Windows, Android, and cross-device execution first followed
`docs/manual_tests/29_legacy_cloud_ownership_verification.md` and found two
blockers. Sprint 10B.3.1 remediation is defined in
`docs/24_LEGACY_SYNC_REENTRY_REMEDIATION.md`; clean release evidence must be
recorded in `docs/manual_tests/30_legacy_sync_reentry_remediation.md`.
