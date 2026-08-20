# Rebirth Current Baseline

> Classification: **Active / authoritative**
> Audited: **2026-08-20**
> Audited code baseline: `cab60cf9cf74ee452f6b082ac37dba342894fc28`
> Sprint 15A starting HEAD: `c835a24c74c2ba3a92894ce6ba05d47fff1ab810`
> Sprint 15B starting HEAD: `3a65cf13ec468b7688b3472f5d156d51021cf25e`
> Sprint 16A starting HEAD: `72eb4ac2b5161aeefad3f101ad08ea6eac05e10b`
> Sprint 16B starting HEAD: `260356faf79deac1c72b8dd6f97f938185a4e6e3`
> Sprint 17A starting HEAD: `6f8415b8f7a69dfc61b39c8d98251604e200d92a`
> Sprint 17A.1 starting HEAD: `e0de17aa34f24040856d9b92869b295878b66225`
> Sprint 17A.1 Prototype Revision 1 starting HEAD: `7a056414896fdfd4ec9731429ef0cd8b7005098d`
> Sprint 17B starting HEAD: `3eaf4c11f9b7bfdf8b78d18992fd1aaa9abaa593`
> Sprint 17B implementation commit: `cab60cf9cf74ee452f6b082ac37dba342894fc28`
> Current working Sprint: **17B Home / Today / Health Production Experience Integration accepted; manual Gate CLOSED**
> Branch: `main`

This document is the single entry point for the current product and technical
state. Historical Sprint documents remain evidence of what was true at their
recorded time; when they conflict with this baseline, this document, the current
reviewed working change, and source code at its recorded commits take precedence.

## Evidence Vocabulary

| Term | Meaning |
|---|---|
| Implemented | The capability exists in source at the baseline commit. |
| Automated verified | Repository tests or CI exercise the capability. |
| Manually accepted | A named manual matrix records real product execution. |
| Deployed | The exact artifact/configuration was verified in a running environment. |
| Deferred | Intentionally postponed; the current product does not promise it. |
| Unsupported | No usable product flow exists at this baseline. |

These terms are not interchangeable. In particular, a CI PASS is not manual
acceptance, an image publication is not deployment, and a Provider abstraction
is not proof that a live Provider is configured.

## Version Baseline

| Component | Audited value | Source/evidence |
|---|---|---|
| Flutter | `3.44.4` stable | Local tool and `.github/workflows/quality.yml` |
| Dart | `3.12.2` | Flutter toolchain and `pubspec.yaml` SDK constraint |
| Python | `3.12` contract | CI and `python:3.12-slim`; patch version is not pinned |
| PostgreSQL | `17` | CI service and `postgres:17-alpine`; digest is not pinned |
| Flutter schemaVersion | `13` | `lib/core/database/app_database.dart` |
| Server Alembic head | `20260812_0008` | `server/alembic/versions/` |
| API Version | `1` | `/health` schema |
| Sync Protocol Version | `2` | `/health` schema and sync contracts |
| Flutter package version | `1.0.0+1` | `pubspec.yaml`; stale release metadata |
| Android application ID | `com.example.rebirth` | Development value; public-release blocker |

## Current Architecture

```text
Flutter Windows / Android
  -> feature presentation and Riverpod controllers
  -> domain repositories
  -> Drift / SQLite account-scoped local data
  -> Dio authenticated API client
  -> FastAPI services
  -> SQLAlchemy / Alembic
  -> PostgreSQL 17
```

The client is local-first and feature-first. The server owns authentication,
devices, generic Sync Protocol 2 transport, AI Provider calls, request/usage
ledgers, and server-only operational diagnostics. Widgets do not directly read
Drift or server implementation classes.

## Client Product Baseline

| Area | Local product behavior | Manual sync | Conflict behavior | Current evidence |
|---|---|---|---|---|
| Profile | Account-scoped profile and settings | Yes | OCC and shared conflict framework | Unified Sync Center: 113 PASS / 0 FAIL / 0 NOT EXECUTED |
| Plan | Hierarchical goals, dates, lifecycle, archive/filter | Yes | Explicit shared conflict recovery | Unified matrix accepted; Android date layout regression accepted separately |
| Today | Daily priorities, nullable 1-10 Mood/Energy with descriptions, stepped durations, and note | Yes | Explicit Today recovery, null/zero preserved | Sprint 17B production matrix OPEN at 0 PASS / 0 FAIL / 48 NOT EXECUTED |
| Journal | Draft/complete/reopen and prompt snapshots | Yes | Explicit Journal recovery | 39 PASS / 0 FAIL / 0 NOT EXECUTED |
| Health | Sensitive local health records with water visualization/step input and nullable 1-10 physical-state description | Yes | Explicit shared conflict recovery | Sprint 17B production matrix OPEN at 0 PASS / 0 FAIL / 48 NOT EXECUTED |
| Growth | Read-only local projections | No | Not a sync aggregate | 71 PASS / 0 FAIL / 6 safe fault-injection rows NOT EXECUTED |
| Personal Data | Local aggregation boundary | No | Not a sync aggregate | 49 PASS / 0 FAIL / 5 safe fault-injection rows NOT EXECUTED |
| Full Personal Data Export | Explicit current-account plaintext JSON backup foundation | No | Not a sync operation | Manual Gate closed with accepted limitations at 49 PASS / 0 FAIL / 5 NOT EXECUTED |
| Journal Prompt | Versioned prompt configuration and entry snapshots | Yes, inside Journal | Shared conflict framework | 93 PASS / 0 FAIL / 0 NOT EXECUTED |
| AI Report | Persistent immutable versions, archive, library, export, and version-bound structured feedback | Yes, with dedicated feedback API after report sync | Explicit report and feedback OCC recovery | Sprint 14B-16B evidence summarized below |

The Sync Center registers exactly six user-facing modules in this order:

1. Profile
2. Plan
3. Today
4. Journal
5. Health
6. AI Report

Journal prompt configuration runs before Journal entries. Synchronization is
manual only. There is no startup, scheduled, background, or automatic sync.

The responsive HomeShell exposes the same six first-level destinations through
bottom navigation below 840px, a compact NavigationRail from 840px, and an
expanded product rail from 1200px at ordinary text scale. Shared Material 3
tokens define semantic state colors, responsive padding, 48px minimum targets,
reduced-motion-aware durations, and reusable page/loading/error foundations.
This changes presentation only and does not alter routes or feature behavior.

After authentication, `/home` is now the production default and provides a
read-only, account-scoped local-day overview. It uses `DateTimeService`, bundled
day/night imagery, a labelled deterministic local quote, the current Today and
Health summaries, and six module cards. Opening or refreshing Home does not
create records, call AI, or start synchronization.

## Authentication and Identity Boundary

| Capability | Current state | Verification and limitation |
|---|---|---|
| Public username/password register and login | Implemented and manually accepted | 107 PASS / 0 FAIL / 7 unavailable legacy-fixture rows; main auth gates closed |
| Session restore, refresh rotation, logout/revocation | Implemented and automated; product flows accepted | Access token is memory-only; refresh credential uses Android/Windows secure storage |
| Account Boundary | Implemented and manually accepted | Endpoint plus cloud user selects one local data space; no cross-account inheritance |
| Developer login | Implemented for explicitly enabled non-production builds | Production configuration forces it off |
| Canonical identity model | Implemented | `AuthIdentity` is the only identity store; no second provider-specific identity model |
| Multi-identity product matrix | Implemented/automated, manual Gate still open | Dedicated matrix remains 0 PASS / 0 FAIL / 38 NOT EXECUTED |
| WeChat identity foundation | Implemented and foundation Gate closed | 30 PASS / 0 FAIL / 0 NOT EXECUTED; this is not real WeChat login |
| OAuth transaction security | Implemented and foundation Gate closed | 24 PASS / 0 FAIL / 0 NOT EXECUTED; state/nonce and one-time consumption are server-side |
| Step-up reauthentication/callback contract | Implemented, manual Gate open | 24 PASS / 0 FAIL / 12 controlled scenarios NOT EXECUTED |
| Real WeChat login/SDK/QR | Unsupported | No production Provider Adapter, SDK, QR flow, App ID, or App Secret integration |
| Password recovery | Unsupported / deferred | No recovery product flow |
| MFA | Unsupported / deferred | No MFA product flow |

Cloud ownership always comes from the authenticated server session. Clients do
not submit a trusted cloud user ID for authentication, identity binding, or
sync ownership.

## AI Baseline

The Server has one Provider boundary with four selectable implementations:

- `disabled`: fail closed and do not invoke a model;
- `fake`: deterministic development/test Provider only;
- `openai`: real server-side Provider integration;
- `deepseek`: real server-side Provider integration.

Provider choice, model, credentials, timeouts, quotas, and kill switch are
server configuration. They are never client settings. The code supports
explicit Daily and Weekly generation through one consolidated client
application coordinator; it does not provide AI Chat, agents, tool calling,
automatic background generation, or client-selected credentials.

Sprint 16A exposes `AI 教练` as a stable first-level Windows/Android
destination. Its task-oriented home composes Daily, Weekly, recent reports,
and simple usage availability from existing controllers. Settings retains
consent/privacy only. The natural flow still uses the canonical coordinator,
report library, and report detail; opening the home never generates, polls,
syncs, or automatically recovers a request.

Current controls include:

- explicit account-scoped AI data consent;
- canonical input hashing and request idempotency;
- generation request and usage ledgers;
- UTC-day user/global quotas and concurrency reservations;
- timeout, failure, expiry, and processing-lease handling;
- authenticated personal usage transparency;
- server-only config, audit, monitor, consistency, and cleanup commands;
- allowlisted operational events without prompt or source-body logging.

Sprint 16B adds one mutable feedback aggregate per account and immutable report
version. Only helpful/not-helpful plus seven fixed reasons are accepted; there
is no free text. Feedback saves locally first, follows explicit AI Report sync
through a dedicated authenticated API, and uses independent OCC/tombstone
metadata without becoming a Sync Protocol 2 entity. Read-only quality audit
groups anonymous counts by report type and governed Prompt identity. It does
not train a model or automatically alter/activate a Prompt.

Sprint 15C adds a single Server-side immutable Prompt Registry for Daily and
Weekly active/candidate versions. Explicit active pointers remain on v1;
candidate v2 definitions are not accepted by Generate endpoints. Published
fingerprints prevent in-place Prompt edits. Nine repository-synthetic cases
drive deterministic Contract, Grounding, Safety, Coach Quality, and Operational
Gates. Level 1/2 are offline and required by Quality; real Provider evaluation
is explicit, cost-bounded, and not executed in this Sprint.

Manual evidence:

- Real Provider and cost safety: 32 PASS / 0 FAIL / 0 NOT EXECUTED;
- Usage transparency: 36 PASS / 0 FAIL / 0 NOT EXECUTED;
- Operations acceptance: 72 PASS / 0 FAIL / 0 NOT EXECUTED;
- Consent route integrity: 25 PASS / 0 FAIL / 0 NOT EXECUTED;
- Prompt governance and quality evaluation: 30 PASS / 0 FAIL / 8
  explicitly accepted NOT EXECUTED rows.
- AI Coach MVP product experience: 29 PASS / 0 FAIL / 8 NOT EXECUTED; all
  applicable platform and real-Provider rows passed, while eight dangerous
  runtime injections use explicitly accepted automated evidence.

Those results prove the recorded Alpha acceptance environment at the time of
execution. Sprint 14G does not inspect the current remote Provider selection or
credential readiness and therefore does not claim that a live Provider is
configured today.

## AI Report Baseline

| Sprint | Capability | Database/protocol effect | Manual result | Current conclusion |
|---|---|---|---|---|
| 14B | Local report persistence and immutable versions | Flutter schema 10 | 34 PASS / 0 FAIL / 8 non-applicable rows | Conditionally accepted |
| 14C | Manual cross-device report sync | Sync Protocol remains 2 | 12 PASS / 0 FAIL / 9 unavailable UI rows | Applicable Gate closed; later lifecycle tests supersede missing archive/conflict UI |
| 14D | Archive lifecycle and conflict readiness | Flutter schema 11 | 25 PASS / 0 FAIL / 0 NOT EXECUTED | Closed |
| 14E | One canonical report library | No schema/API/protocol change | 31 PASS / 0 FAIL / 0 NOT EXECUTED | Closed |
| 14F | Explicit Markdown/JSON safe export | No schema/API/protocol change | 37 PASS / 0 FAIL / 1 safe SessionRejected row | Closed with accepted limitation |
| 15B | Generation pipeline consolidation | No schema/API/protocol change | 35 PASS / 0 FAIL / 7 controlled-fixture rows | Closed with accepted limitations |
| 15C | Prompt Registry and synthetic quality evaluation | No schema/API/protocol change | 30 PASS / 0 FAIL / 8 NOT EXECUTED | Closed with accepted automation and cost limitations; real Provider evaluation not authorized |
| 16A | First-level task-oriented AI Coach product experience | No schema/API/protocol change | 29 PASS / 0 FAIL / 8 NOT EXECUTED | Closed with accepted limitations; automated evidence replaces dangerous runtime injection only |
| 16B | Version-bound structured AI Report feedback and aggregate quality signal | Flutter schema 12; Alembic `20260812_0008`; API 1 and Sync Protocol 2 unchanged | 3 PASS / 0 FAIL / 36 NOT EXECUTED | Alpha deployment identity passed; remaining product matrix is open and explicitly suspended |
| 17A | Product experience audit and UI design system foundation | No schema/API/protocol change | 0 PASS / 0 FAIL / 30 NOT EXECUTED | Responsive and theme automation added; final feature visual direction remains open |
| 17A.1 Revision 1 | Developer-only Home / Today / Health experience prototype | No schema/API/protocol change | 81 PASS / 0 FAIL / 0 NOT EXECUTED | Gate closed on 2026-08-20; the accepted in-memory prototype adds nullable 1-10 wellbeing sliders, one-line descriptions, and restrained field icons while production 1-5 fields and routes remain unchanged |
| 17B | Home / Today / Health production experience integration | Flutter schema 13; dual-format Server validation; API 1 and Sync Protocol 2 unchanged | 48 PASS / 0 FAIL / 3 NOT EXECUTED | Gate closed; all product-level checks passed, with explicit automated substitutions for A10 and D3-D4 |

Sprint 16A does not add a report type or change report persistence. It exposes
the existing Daily/Weekly and report lifecycle through one first-level Coach
home. Its Gate closed with accepted limitations after real Provider
Daily/Weekly and Windows/Android product checks passed; only the eight named
automated-only fault scenarios remain manually unexecuted.

AI Report export is portability output, not a backup/restore promise. There is
no import, restore, scheduled export, cloud export, report editing, or
regeneration flow.

Sprint 15B consolidates Daily and Weekly generation behind
`AiReportGenerationCoordinator`. Presentation controllers keep UI state and
preview integrity checks, while the coordinator owns reusable completed-report
lookup, pending report creation, request binding, remote generation submission,
terminal local writes, single-flight suppression, endpoint/account safety, and
status-only pending recovery. Older completed reports without the new endpoint
metadata remain readable but are not reused by the consolidated generation
pipeline. The user reported all applicable Windows and Android rows as PASS.
The [AI Report Generation Pipeline](manual_tests/56_ai_report_generation_pipeline.md)
Gate is closed with accepted limitations: six controlled pending-recovery state
injections and one request-binding persistence failure injection remain
unavailable at product level and retain automated coverage only.

## Full Personal Data Export Baseline

Sprint 15A adds a protected Settings flow that exports the current authenticated
local account's Profile, Plan, Today, Journal and prompt configuration, Health,
and AI Reports with immutable versions. It uses explicit typed module exporters,
portable DTOs, one read transaction, deterministic JSON ordering, a SHA-256 over
the canonical `data` payload, and the shared Windows/Android file adapter from
Sprint 14F.

The export preserves business relationships, natural dates, lifecycle facts,
soft-deletion timestamps, `null`, numeric zero, and empty strings. It excludes
credentials, cloud/auth/device identifiers, endpoints, Provider inputs and
ledgers, sync metadata, cursors, conflicts, transport tombstones, paths, and
logs. Growth and Personal Data Aggregation remain derived and are recomputed
from source facts rather than copied into the backup.

The file is plaintext UTF-8 JSON and may contain Journal, Health, and AI Report
bodies. It is local-only, user-triggered, account-scoped, and non-mutating. It
does not call the Server, AI, or sync. It does not provide import, restore,
merge, encryption, scheduled backup, or cloud backup. The 54-row Windows and
Android matrix records 49 PASS / 0 FAIL / 5 NOT EXECUTED. The five unavailable
failure/timing injection rows have explicit reasons, so the feature Gate is
closed with accepted limitations.

## Server Baseline

Public API groups are:

- `/health`;
- `/auth` for register, login, developer login when allowed, refresh, logout,
  session, identities, and guarded identity foundations;
- `/devices/register`;
- `/sync/verify-ownership`, `/sync/push`, and `/sync/pull`;
- `/ai/capabilities`, `/ai/usage/me`, Daily/Weekly generation, and request
  status recovery;
- authenticated `/ai/report-feedback` list, upsert, and delete operations.

The PostgreSQL model contains cloud users, canonical auth identities,
OAuth/step-up state, credentials and sessions, devices, generic sync items and
clock, AI generation/usage ledgers, and the independent AI Report feedback
aggregate. AI Reports remain Sync Protocol payloads rather than a second server
report database model; feedback uses a dedicated API and does not change the
protocol entity registry.

## Verification Baseline

GitHub `Quality` run
[31073858896](https://github.com/wellinglan/Rebirth/actions/runs/31073858896)
completed successfully for the Sprint 15B implementation commit
`ab3bc862006ba21924595966190d93f6a661867a`. It passed:

- Server SQLite;
- Server PostgreSQL, Alembic, multiprocessing, and multi-worker checks;
- Flutter analyze and all Flutter tests;
- Android Debug build.

The workflow does not build Windows. CI PASS does not close manual Gates; the
manual evidence lineage is authoritative in
[Manual Acceptance Registry](manual_tests/README.md).

## Deployment Baseline

Repository evidence confirms:

- a GHCR workflow can build and publish API commit tags and `alpha-latest`;
- the workflow mirrors `postgres:17-alpine` into GHCR;
- historical records describe a private Tailscale-based Beijing Alpha Server;
- Windows and Android have previously exercised that private Alpha environment.

Sprint 14G performs no remote Docker, PostgreSQL, Tailscale, health, migration,
or Provider inspection. It therefore **cannot confirm**:

- which API image digest or commit tag is currently running;
- whether the current baseline commit is deployed;
- the live Alembic head or database backup state;
- the live AI Provider, model, quotas, or credential validity;
- current private-network reachability or `/health` output.

Publishing an image is not deployment. Any release decision needs a fresh,
separately authorized deployment check.

Sprint 16B was committed and passed Quality run
[31584652543](https://github.com/wellinglan/Rebirth/actions/runs/31584652543).
Its full-SHA GHCR API image and Alembic `20260812_0008` were subsequently
verified on Alpha together with `/health`; the user then explicitly suspended
the remaining product matrix at 3 PASS / 0 FAIL / 36 NOT EXECUTED. This proves
that recorded deployment only, not Provider readiness or wider release safety.

## Product Decisions Versus Release Debt

Current intentional product boundaries:

- local-first records with explicit, manual synchronization;
- no automatic sync or automatic AI generation;
- explicit AI consent and selected source scopes;
- account-scoped data, conflicts, usage, and reports;
- immutable AI Report versions;
- mutable structured feedback bound to an immutable report version, with no
  free text and explicit manual cross-device convergence;
- export without import/restore in Sprint 14F;
- explicit full personal data export without import/restore in Sprint 15A;
- no AI Chat, agents, or tool calling.

Current release debt/blockers:

- example Android application ID and Debug release signing;
- stale package description/version metadata;
- no Windows installer pipeline, Windows CI, or GitHub Release process;
- Python dependencies are ranged rather than fully locked;
- container base images are not digest-pinned;
- no SBOM, image signing, or dependency/security scan Gate;
- no production backup/restore drill;
- no formal monitoring, incident-response, or deletion-policy validation;
- incomplete controlled Step-up/OAuth callback manual scenarios;
- no real WeChat login, password recovery, or MFA.

The detailed classification and exit criteria are in
[Release Readiness](RELEASE_READINESS.md).

## Authority and Update Rule

When a future Sprint changes a version, module boundary, deployment fact, or
Gate status, update this file in the same change. Do not rewrite old manual or
release evidence. Mark old records Historical or Superseded and link the newer
authority from [Documentation Index](README.md).
