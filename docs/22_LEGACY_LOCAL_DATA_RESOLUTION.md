# Legacy Local Data Ownership Resolution

> Sprint: 10B.2-B
> Flutter schema: 6
> Server API / Sync Protocol: 1 / 2, unchanged
> Environment: Development + Fake Provider + Tailscale private Alpha

## Why Binding Was Required

Sprint 10B.2-A introduced a durable boundary between a normalized Endpoint +
cloud user and one local `UserProfile`. A database upgraded from an older
version can contain Profiles that predate this binding. Automatically
assigning one of them to the next Development User Key could disclose private
data or reuse another account's sync versions. The safe response was
`bindingRequired`, but its original page offered only logout and therefore
left upgrades incomplete.

Sprint 10B.2-B keeps the safety invariant and adds an explicit completion
flow. The system never guesses which account owns old data.

## Separate Concepts

The implementation intentionally does not collapse these concepts:

1. **Login identity**: the current Alpha AuthSession from Development login.
2. **Local ownership**: the `cloud_account_bindings` relationship.
3. **Sync eligibility**: whether historical cloud metadata is safe to use.
4. **Manual sync**: an explicit Profile or Plan action by the user.
5. **AI sharing consent**: the existing independent privacy authorization.

Local ownership can be confirmed while cloud sync remains quarantined. None
of these states enables AI sharing or background synchronization.

## Privacy-safe Summary

Each unbound, non-deleted Profile receives a temporary label such as
`本地数据空间 1`. The UI may show:

- Profile creation date and latest business update time;
- active Today, Journal, Goal, Health, and AI Report counts;
- tombstone count;
- whether sync history, conflict history, or AI pending state exists.

The model and UI do not expose business text, Profile display name, health
values, report content, raw JSON, credentials, complete Endpoint, complete
cloud/local UUID, or complete device ID. `origin_device_id` alone is not
treated as proof of prior synchronization. SharedPreferences cursors are not
guessed to belong to any legacy Profile.

## Bind Existing State Machine

```text
bindingRequired
  -> load anonymous summaries
  -> user selects one space
  -> second confirmation
  -> re-read AuthSession and validate expected scope
  -> transaction validates Profile remains unbound
  -> create legacy_claim binding
  -> activate selected Profile
  -> invalidate account-scoped providers
  -> authenticated / authenticatedOffline
  -> local access allowed, cloud sync quarantined
```

The binding stores `sync_eligibility_status = legacy_review_required`.
Cancellation performs no write. Any validation or database failure rolls back
the binding and active-Profile switch together.

## Create Fresh State Machine

```text
bindingRequired
  -> user selects fresh space
  -> second confirmation
  -> re-read AuthSession and validate expected scope
  -> transaction creates an empty Profile and app_settings
  -> create fresh_space + ready binding
  -> activate the new Profile
  -> invalidate account-scoped providers
  -> authenticated / authenticatedOffline
```

Existing legacy Profiles and all of their records remain untouched and
unbound. No row, conflict, cursor, or sync version is copied. Cloud data can
enter the fresh space only through a later explicit manual pull.

## Defer And Logout

`暂不处理并退出` clears the development Session, deactivates all Profiles,
invalidates account-scoped runtime state, and returns to login. It does not
create a binding, delete data, clear installation identity, or modify sync and
AI metadata.

## Atomicity, Idempotence, And Recovery

Repository mutations run in Drift transactions. Each operation revalidates
the Session scope, target Profile, existing binding, and installation record.
Unique constraints retain one binding per Endpoint + cloud user and one
binding per local Profile.

If a previous attempt committed but the App stopped before navigation,
restart resolves the existing binding and activates the same Profile.
Repeated calls return that binding rather than creating duplicate Profiles.
Multiple unbound Profiles remain separately listed; claiming one does not
claim the others. Bound and soft-deleted Profiles are excluded.

## Sync Quarantine

`legacy_review_required` allows Today, Journal, Plan, Health, Growth, and local
AI Coach access. It blocks Profile and Plan push, pull, and two-way sync.
`SyncCoordinator` returns `accountSyncReviewRequired` before:

- device validation;
- cursor read or write;
- pending-item collection;
- push, pull, acknowledge, or apply;
- conflict creation.

This differs from `accountScopeMismatch`, where the active Profile does not
belong to the current Endpoint and cloud user at all. Settings displays the
ownership and eligibility states and disables manual Profile/Plan actions,
but the Coordinator guard is authoritative.

## Preservation Rules

Claiming a legacy Profile does not change:

- `server_version`, `last_synced_at`, or `sync_status`;
- active or historical tombstones;
- SharedPreferences cursor values;
- conflict rows, snapshots, or resolution history;
- AI pending requests or AI Consent.

The conflict inbox receives no actionable scope while eligibility is
quarantined.

## Schema 6 Migration

`cloud_account_bindings` adds:

- `binding_origin`;
- `sync_eligibility_status`;
- `ownership_confirmed_at`.

Schema 5 bindings backfill to `clean_first_login`, `ready`, and their existing
`created_at`. This preserves already-established account spaces. Legacy
unbound Profiles receive no automatic binding. The migration does not change
`installation_info`, compatibility mirrors, business tables, conflict tables,
or Server storage.

## Remaining Gate

This Sprint does not prove which historical cloud account produced a claimed
Profile's old sync metadata. A later Sprint must design an explicit,
auditable verification or migration before changing
`legacy_review_required` to `ready`.

Windows and Android release builds must execute
`docs/manual_tests/28_legacy_local_data_resolution.md`. Automated tests do not
close that Gate. Sprint 10C remains blocked until legacy claim, fresh space,
restart, logout/re-login, account isolation, Endpoint isolation, sync
quarantine, and data preservation pass manually.
