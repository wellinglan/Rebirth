# Rebirth Documentation Index

> Classification: **Active**
> Last consolidated: **2026-08-06 / Sprint 15B working tree**

Start with [Current Baseline](CURRENT_BASELINE.md). It is the only authoritative
snapshot of what is implemented, verified, manually accepted, deployed,
deferred, or unsupported now.

## Status Labels

| Label | Meaning |
|---|---|
| Active | Current operational or product authority. |
| Partially current | Contains valid principles plus historical Sprint snapshots; use Current Baseline for present facts. |
| Historical | Preserved evidence from a past Sprint; not a current-state claim. |
| Superseded by ... | A later document or matrix owns the current conclusion. |

## Active Baseline

| Document | Status | Purpose |
|---|---|---|
| [Current Baseline](CURRENT_BASELINE.md) | Active / authoritative | Current versions, modules, boundaries, evidence, and deployment certainty |
| [Release Readiness](RELEASE_READINESS.md) | Active | Private Alpha evidence and Production/store blockers |
| [Manual Acceptance Registry](manual_tests/README.md) | Active | Current Gate conclusions and historical inheritance |
| [Root README](../README.md) | Active | Developer and project entry point |

## Product and Architecture

| Document | Status | Notes |
|---|---|---|
| [AI Context](00_AI_CONTEXT.md) | Partially current | Mission and append-only Sprint boundaries; older technology/sync snapshots are historical |
| [Product Requirements](01_PRD.md) | Partially current | Long-term product baseline; Sprint 0 metadata is historical |
| [Architecture](02_ARCHITECTURE.md) | Partially current | Architecture principles plus append-only evolution; early future-server text is historical |
| [Database](03_DATABASE.md) | Partially current | Original schema design plus migration history through Flutter schema 11 |
| [Authentication and Sync](04_AUTH_SYNC.md) | Partially current | Current auth principles plus historical staged rollout; use Current Baseline for current module count |
| [API Contract](05_API_CONTRACT.md) | Partially current | Original Protocol contract and later appendices; source schemas remain decisive |

## Current Operational Runbooks

| Document | Status | Notes |
|---|---|---|
| [Server README](../server/README.md) | Active | Local Server operation, API groups, auth, sync, AI, and tests |
| [AI Operator Runbook](44_AI_OPERATOR_RUNBOOK.md) | Active | Provider config, limits, kill switch, audit, incident, and rollback procedures |
| [AI Operations and Observability](12_AI_OPERATIONS_AND_OBSERVABILITY.md) | Partially current | Durable ledger and reliability foundation; later operations are in the runbook |
| [Alpha GHCR Deployment](15_ALPHA_GHCR_DEPLOYMENT.md) | Partially current | Image publication and pull boundary; publication does not prove deployment |
| [Cloud Alpha Context](16_REBIRTH_CLOUD_ALPHA_CONTEXT.md) | Historical operational log / partially current topology | Private Alpha history; live state requires a fresh authorized check |
| [Cloud Deployment Foundation](06_CLOUD_DEPLOYMENT.md) | Historical Sprint 6E | Development foundation; superseded for current state by Current Baseline and the Server README |

## Current Feature Contracts

### Data, Growth, and Sync

- [Personal Data Aggregation](36_PERSONAL_DATA_AGGREGATION.md) - Active
- [Growth System Foundation](37_GROWTH_SYSTEM_FOUNDATION.md) - Active
- [Journal Prompt System](38_JOURNAL_PROMPT_SYSTEM.md) - Active
- [Settings and Sync Center](39_SETTINGS_INFORMATION_ARCHITECTURE_AND_SYNC_CENTER.md) - Active
- [Today Cross-device Sync](31_TODAY_CROSS_DEVICE_SYNC.md) - Active
- [Today Conflict Recovery](32_TODAY_CONFLICT_RECOVERY.md) - Active
- [Journal Cross-device Sync](33_JOURNAL_CROSS_DEVICE_SYNC.md) - Active
- [Health Cross-device Sync](33_HEALTH_CROSS_DEVICE_SYNC.md) - Active

### Authentication and Identity

- [Authentication Protocol and Secure Session](40_AUTHENTICATION_PROTOCOL_AND_SECURE_SESSION.md) - Active foundation
- [Public Username/Password Login](41_PUBLIC_USERNAME_PASSWORD_LOGIN.md) - Active
- [Identity Foundation](40_IDENTITY_FOUNDATION.md) - Active architecture; dedicated manual Gate remains open
- [WeChat Identity Foundation](43_WECHAT_IDENTITY_FOUNDATION.md) - Active foundation; real WeChat login unsupported
- [WeChat OAuth Transaction Security](43_WECHAT_OAUTH_TRANSACTION_SECURITY.md) - Active security foundation
- [Step-up Reauthentication](45_STEP_UP_REAUTHENTICATION.md) - Active implementation; controlled manual Gate remains open

### AI and AI Reports

- [Real AI Provider and Cost Safety](46_REAL_AI_PROVIDER_AND_COST_SAFETY.md) - Active
- [AI Usage Transparency and Operational Safety](47_AI_USAGE_TRANSPARENCY_AND_OPERATIONAL_SAFETY.md) - Active
- [AI Report Persistence](45_AI_REPORT_PERSISTENCE.md) - Active foundation
- [AI Report Cross-device Sync](46_AI_REPORT_CROSS_DEVICE_SYNC.md) - Active
- [AI Report Lifecycle](47_AI_REPORT_LIFECYCLE.md) - Active
- [AI Report Library](48_AI_REPORT_LIBRARY.md) - Active
- [AI Report Safe Export](49_AI_REPORT_SAFE_EXPORT.md) - Active
- [Full Personal Data Export and Backup](50_FULL_PERSONAL_DATA_EXPORT_AND_BACKUP.md) - Active; manual Gate closed with accepted limitations
- [AI Report Generation Pipeline](51_AI_REPORT_GENERATION_PIPELINE.md) - Active; Gate closed with accepted limitations

## Historical Sprint Records

These documents retain design and acceptance history. They are not independent
current-state authorities:

- `07_GROWTH_ANALYTICS.md` through `11_AI_GENERATION_RELIABILITY.md`;
- `13_DAILY_INSIGHT_FOUNDATION.md`, `14_DAILY_INSIGHT_MANUAL_GENERATION.md`,
  and `17_DAILY_INSIGHT_FRESHNESS.md`;
- `18_SYNC_FOUNDATION.md` through `24_LEGACY_SYNC_REENTRY_REMEDIATION.md`;
- old status passages inside `00`-`06`, which are explicitly subordinate to
  Current Baseline;
- early manual matrices whose OPEN/FAIL state is linked to a later accepted
  matrix in the Gate Registry.

Historical limitations must not be deleted. When a later Sprint resolves one,
the old record stays intact and the registry records the succession.

## Manual Acceptance

The [Manual Acceptance Registry](manual_tests/README.md) distinguishes product
execution from automation and records PASS / FAIL / NOT EXECUTED counts. The
individual files in `manual_tests/` remain immutable evidence except when the
user explicitly reports new execution results.

## Release Records

| Record | Status |
|---|---|
| [v0.7.0-alpha Build Manifest](release/v0.7.0-alpha-build-manifest.md) | Historical Sprint 8F.1 artifact record |
| [v0.7.0-alpha Release Notes](release/v0.7.0-alpha-release-notes.md) | Historical Sprint 8F.1 release-gate record |
| [Android APK Build Guide](release/rebirth_android_apk_build_guide.md) | Partially current; validate commands against current Flutter and signing policy |
| [Client Environment Build Guide](release/rebirth_client_environment_build_guide.md) | Active build-variable reference; not a release-signing policy |

The old manifest does not describe the current HEAD and does not prove a
GitHub Release or Production artifact exists.

## Maintenance Rule

For a change that alters schema, API, Sync Protocol, supported modules,
authentication, AI Provider boundaries, manual Gates, or deployment evidence:

1. update [Current Baseline](CURRENT_BASELINE.md);
2. update the relevant feature contract;
3. preserve old Sprint evidence and mark its succession here or in the manual
   Gate Registry;
4. update [Release Readiness](RELEASE_READINESS.md) when a blocker opens or
   closes;
5. keep credentials, private endpoints, Authorization values, and personal data
   out of documentation.
