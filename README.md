# Rebirth

Rebirth is a local-first personal growth system for recording daily state,
reflection, plans, health, and long-term growth. AI is an explicit, consented
assistant to those workflows, not an autonomous agent and not the owner of the
user's data.

The repository is currently a **private Alpha codebase**. Windows and Android
are the supported client targets. It is not a production or app-store release.
The authoritative snapshot is [Current Baseline](docs/CURRENT_BASELINE.md), and
release blockers are tracked in
[Release Readiness](docs/RELEASE_READINESS.md).

## Current Architecture

| Layer | Current implementation |
|---|---|
| Client | Flutter 3.44.4, Dart 3.12.2, Material 3, Riverpod, GoRouter |
| Local data | Drift and SQLite, account-scoped, Flutter `schemaVersion` 11 |
| Network | Dio, authenticated API Version 1 |
| Server | FastAPI, SQLAlchemy, Alembic, Python 3.12 |
| Cloud data | PostgreSQL 17 and generic Sync Protocol 2 records |
| AI | Server-selected Disabled, Fake, OpenAI, or DeepSeek Provider |

The client is organized feature-first. Widgets use controllers and
repositories; they do not access Drift or Server implementation details
directly. Local SQLite remains the primary working data store.

## Product Areas

- **Today**: priorities, mood, energy, time use, notes, and same-day health
  summary.
- **Journal**: draft/completed reflections with versioned prompt snapshots.
- **Plan**: hierarchical goals, dates, lifecycle, archive, and filtering.
- **Health**: local health records with sensitive-data boundaries.
- **Growth**: read-only local projections over approved personal-data sources.
- **Profile and Settings**: public username/password sessions, account
  boundaries, consent, device state, and a unified manual Sync Center.
- **AI Coach**: a stable first-level, task-oriented entry for Daily and Weekly
  insight, account-scoped consent, simple availability/usage state, recent
  reports, and natural navigation into the one consolidated generation
  coordinator and canonical report library. Server-owned immutable Prompt
  versions and synthetic offline quality Gates govern active and candidate
  Prompts.
- **AI Reports**: local persistence, immutable versions, manual cross-device
  sync, conflict recovery, archive lifecycle, one report library, and explicit
  Markdown/JSON export.
- **Personal Data Export**: an explicit current-account plaintext JSON snapshot
  of Profile, Plan, Today, Journal, prompt configuration, Health, and AI Reports,
  with deterministic SHA-256 verification and native Windows/Android saving.

## Local-first Sync

Synchronization is **always user-triggered**. There is no startup, scheduled,
or background sync. The current Sync Center registers these six product
modules:

1. Profile
2. Plan
3. Today
4. Journal
5. Health
6. AI Report

The shared coordinator enforces authenticated account scope, device ownership,
optimistic concurrency, cursor discipline, tombstones, and explicit conflict
recovery. Journal prompt configuration is synchronized before Journal entries.

## AI and Privacy Boundary

AI Provider credentials and operational limits exist only on the Server. The
Flutter application does not contain Provider keys. Generation requires an
authenticated account, explicit consent, selected data scopes, and a manual
action. The Server uses request and usage ledgers for idempotency, quotas,
timeouts, and audits without persisting prompts or source record bodies in
those ledgers.

AI Report export is a local, explicit save operation. It does not trigger AI or
sync, and Sprint 14F does not provide import or restore.

Full personal data export is also local and explicit. It excludes credentials,
device/session state, Server endpoints, sync/conflict runtime state, and AI
Server ledgers. Its plaintext JSON may contain sensitive bodies. Sprint 15A
establishes a backup format foundation but still provides no import, restore,
scheduled backup, or cloud backup.

Daily and Weekly AI Report generation now share one client-side application
coordinator. The coordinator owns reusable-report lookup, pending report
creation, request binding, remote generation submission, terminal local writes,
and status-only pending recovery. There is still no automatic generation,
automatic retry, prompt change, Provider change, or AI Report sync expansion.

Prompt metadata, explicit active versions, published SHA-256 fingerprints, and
synthetic quality evaluation are owned only by the Server. Normal CI validates
the Registry and deterministic outputs without a database, network call, or
Provider fee. Candidate Prompts are never activated automatically.

Never commit credentials, environment files, access or refresh tokens,
database passwords, private endpoints, or personal data.

## Local Development

Prerequisites:

- Flutter 3.44.4 stable, including Dart 3.12.2;
- a Windows Flutter desktop toolchain for Windows builds;
- Python 3.12 for the Server;
- PostgreSQL 17 only when running PostgreSQL integration scenarios.

Flutter client:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

Local FastAPI with SQLite:

```powershell
cd server
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m alembic upgrade head
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

For an Alpha or Production-style client build, pass `REBIRTH_ENV`,
`REBIRTH_SERVER_ENDPOINT`, and `REBIRTH_ENABLE_DEV_LOGIN` through
`--dart-define`. Do not put a private deployment address in source control.

Server commands, environment boundaries, and AI operations are documented in
[Server README](server/README.md) and the
[AI Operator Runbook](docs/44_AI_OPERATOR_RUNBOOK.md).

## Documentation

- [Current Baseline](docs/CURRENT_BASELINE.md): authoritative product and
  technical state.
- [Documentation Index](docs/README.md): Active, partial, historical, manual,
  and release records.
- [Release Readiness](docs/RELEASE_READINESS.md): Alpha evidence and public
  release blockers.
- [Manual Acceptance Registry](docs/manual_tests/README.md): current Gate
  status and evidence lineage.
- [Product Requirements](docs/01_PRD.md) and
  [Architecture](docs/02_ARCHITECTURE.md): long-term product and architecture
  foundations, with historical sections identified in the index.

## Tests and CI

The `Quality` GitHub Actions workflow runs:

- Server tests on SQLite;
- Server PostgreSQL, Alembic, multiprocessing, and multi-worker checks;
- Flutter analyze and all Flutter tests;
- an Android Debug build.

CI does not currently build Windows and does not prove manual acceptance or a
live Alpha deployment. The latest audited baseline CI evidence is recorded in
[Current Baseline](docs/CURRENT_BASELINE.md).

## Current Non-production Limits

- no background synchronization or automatic AI generation;
- no real WeChat SDK, QR login, or production WeChat Provider Adapter;
- no password recovery or MFA;
- Android still uses the example application ID and Debug signing for release
  builds;
- no Windows installer, Windows CI job, or GitHub Release process;
- production backup/restore drills, monitoring, deletion-policy validation,
  dependency locking, and supply-chain signing are incomplete.

These are release constraints, not hidden claims of production readiness. See
[Release Readiness](docs/RELEASE_READINESS.md) for the complete list.
