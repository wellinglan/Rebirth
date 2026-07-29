# Journal Prompt System

> Sprint: 12C
>
> Flutter schemaVersion: 9
>
> API Version: 1
>
> Sync Protocol Version: 2

## 1. Purpose

Journal previously encoded five questions in the domain model, SQLite columns,
widgets, and sync payload. That design could not safely support user-defined
questions, ordering, disabling, historical wording, or future user-approved AI
proposals.

Sprint 12C replaces that fixed UI contract with a prompt-driven aggregate. It
does not add model calls, automatic sync, background sync, or prompt templates.

## 2. Aggregate Model

Each local user owns one active `JournalPromptConfiguration` with
`logicalKey = default`. The aggregate contains ordered
`JournalPromptDefinition` records and carries one OCC/sync identity.

A definition records:

- stable identity and optional system `stableKey`;
- source: `system`, `user`, or reserved `futureAi`;
- question and optional helper text;
- response kind, currently only `longText`;
- enabled state, display order, prompt version, and timestamps;
- logical deletion state.

The five default questions are a version-controlled catalog. Initialization is
idempotent. Migrated installations use deterministic configuration, prompt,
and entry-item UUIDs; fresh installs create the same logical catalog without
requiring identical physical UUIDs across devices. Cross-device identity for
the default aggregate is `logicalKey`, with semantic convergence for identical
configurations.

System prompts cannot be edited or deleted directly. "Customize" disables the
system definition and creates an editable user copy. User prompts support
create, edit, enable, disable, reorder, and confirmed logical deletion. At
least one prompt remains enabled. A no-op mutation does not advance the
configuration version.

## 3. Entry Snapshots

`JournalEntryPromptItem` is the response source of truth. Every saved item
captures:

- item ID;
- source prompt ID, optional system stable key, and prompt version;
- prompt source and response kind;
- question/helper snapshots;
- display order;
- nullable answer and timestamps.

The form binds text controllers by item ID, never by list index. Reordering or
editing the active configuration therefore cannot attach an answer to another
question. Historical entries render their snapshots and are not rewritten
when configuration changes.

For a draft, "Apply latest prompts" is explicit and confirmed. Matching items
preserve answers, new enabled prompts are appended, and answered retired items
remain available. Completed entries cannot apply a new configuration until the
user explicitly reopens them.

Draft, completed, and reopen semantics remain unchanged. Parent entry and child
items are saved transactionally.

## 4. SQLite Migration

Schema 9 adds:

- `journal_prompt_configurations`;
- `journal_prompt_definitions`;
- `journal_entry_prompt_items`.

The v8-to-v9 migration creates one default configuration per user, the five
catalog definitions, and five item snapshots per existing Journal entry. IDs
are deterministic, making the migration retry-safe. All supported upgrade
paths continue through the same migration chain, and fresh schema creation
installs the same constraints and indexes.

The five legacy columns on `journal_entries` remain temporarily for v1 sync
compatibility. They are derived mirrors of system stable-key items and are no
longer the application source of truth. A later protocol retirement sprint may
remove them only after old Journal clients are no longer supported.

## 5. Synchronization

Manual Journal synchronization runs in this order:

1. `journal_prompt_configurations`;
2. `journal_entries`.

The prompt configuration is synchronized as one aggregate payload with
`payload_schema_version = 1`. It includes definitions and uses the normal
server-version OCC flow. Identical default configurations with different local
UUIDs converge by `logicalKey`; semantic differences produce an explicit
conflict. Push acknowledgement checks the submitted timestamp so an edit made
during upload remains pending.

Journal payload v2 contains `journal_payload_schema_version = 2` and ordered
`prompt_items`. The server still accepts strict legacy v1 payloads. New clients
convert v1 fields deterministically to the five catalog snapshots and write v2
on the next change. Custom prompts are never truncated into v1 fields.

All devices participating in Journal sync must be upgraded for reliable custom
prompt behavior. Compatibility does not promise that old clients can display
or preserve custom prompt items.

Configuration and entry pull/application are transactional. Cursor advancement
remains owned by `SyncCoordinator`; failed validation, partial application, or
unresolved conflicts do not advance the relevant cursor. Tombstone and
same-date Journal conflict semantics are unchanged.

## 6. Conflict Recovery

Prompt configuration conflicts are registered in the existing generic conflict
UI. Lists show only configuration version and prompt counts, not full question
or answer text. Detail supports explicit Adopt Remote and Keep Local actions.
Neither action performs field merging or silently selects a winner.

Keep Local adopts the current remote OCC baseline and preserves the complete
local aggregate. Adopt Remote replaces the local aggregate transactionally.
Historical Journal snapshots are not modified by either configuration action.

## 7. Account And Privacy Boundaries

Every configuration is scoped to the active local user. Logout, account
switching, offline authentication, and `bindingRequired` rules reuse the
existing account boundary. Another account cannot read or mutate the first
account's prompt configuration.

Prompt and response text must not enter logs, exception messages, crash
payloads, test evidence, Growth evidence, or Personal Data Overview. Growth
continues to consume only Journal date/status metadata. No prompt or response
is sent to AI in this Sprint.

## 8. Future AI Boundary

`futureAi` is a reserved provenance value only. A future implementation must
follow this consent flow:

Growth Evidence -> AI Context Builder -> purpose-based consent -> model
proposal -> user review -> explicit acceptance -> create disabled or
user-controlled prompt -> optional manual enablement.

Sprint 12C does not call a model, create proposals, enable prompts
automatically, or implement a reusable Prompt Template aggregate.

## 9. Gates

- Journal Prompt System Product Gate: `OPEN / MANUAL ACCEPTANCE REQUIRED`
- Journal Migration Gate: `OPEN / MANUAL ACCEPTANCE REQUIRED`
- Journal Prompt Sync Gate: `OPEN / MANUAL ACCEPTANCE REQUIRED`
- Account Boundary Isolation Gate: `CLOSED / ACCEPTED`

The manual matrix is `docs/manual_tests/38_journal_prompt_system.md`.
