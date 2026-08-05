# Rebirth Release Readiness

> Classification: **Active**
> Audited: **2026-08-05 / Sprint 15A working tree**
> Sprint 15A source baseline: `c835a24c74c2ba3a92894ce6ba05d47fff1ab810`

This is a readiness inventory, not a release approval. It separates a private
Alpha codebase from a public Production or app-store release. Current versions
and product capabilities are authoritative in
[Current Baseline](CURRENT_BASELINE.md).

## Current Decision

| Target | Decision | Reason |
|---|---|---|
| Continued private Alpha testing | **Conditionally ready** | Quality CI and broad manual acceptance exist; every candidate deployment still needs current artifact, health, migration, configuration, and smoke verification |
| Wider external Alpha distribution | **No-go until release identity/signing and packaging decisions** | Development package identity, Debug signing, stale version metadata, and incomplete distribution controls |
| Public Production or app-store release | **No-go** | Security, operations, recovery, packaging, observability, and unsupported account capabilities remain open |

Neither Sprint 14G nor Sprint 15A performs deployment or certifies that the
reviewed source is running on the private Alpha Server.

## Private Alpha Foundations Present

| Area | Evidence present | Remaining qualification |
|---|---|---|
| Quality CI | Server SQLite, PostgreSQL/Alembic/multi-worker, Flutter analyze/test, and Android Debug passed for the last audited code baseline | Sprint 15A still requires its own post-review CI; no Windows CI or signed release artifact job exists |
| Windows client | Repeated local release builds and manual matrices exist | No installer, signing, update, or distribution pipeline |
| Android client | Release-mode APK and physical-device acceptance history exist | Example application ID and Debug signing make it non-distributable |
| Private cloud Alpha | GHCR publishing workflow and Tailscale/GHCR deployment history exist | Live image, migration, Provider, backup, and health state not inspected in Sprint 14G or 15A |
| Data migrations | Drift migration tests through schema 11 and Alembic through `20260801_0007` | Production backup/restore rehearsal is absent |
| Authentication | Public password login, secure sessions, refresh rotation, logout, and account isolation | Recovery, MFA, real WeChat, and some controlled Step-up cases are absent |
| Manual sync | Profile, Plan, Today, Journal, Health, and AI Report are registered | User-triggered only; no background sync by design |
| AI cost safety | Quotas, concurrency, usage ledger, kill switch, and audit tooling | Live Provider/config state must be checked per deployment |
| Manual acceptance | Unified Gate Registry and retained matrices | NOT EXECUTED rows remain limitations, not PASS |
| Personal data portability | Versioned, deterministic, integrity-checked local JSON export | Plaintext; no import/restore, encryption, scheduling, cloud backup, or manual device acceptance yet |

## Production and Store Blockers

| ID | Blocker | Evidence | Exit criterion |
|---|---|---|---|
| REL-ANDROID-ID-001 | Android application ID is `com.example.rebirth` | `android/app/build.gradle.kts` | Approve a unique organization-owned application ID and migrate build configuration |
| REL-ANDROID-SIGN-001 | Android release uses Debug signing | `android/app/build.gradle.kts` | Establish protected release keystore ownership, CI injection, rotation, and recovery process |
| REL-METADATA-001 | `pubspec.yaml` still says `A new Flutter project.` and `1.0.0+1` | `pubspec.yaml` | Approve release naming/version policy and update product metadata with release notes |
| REL-WINDOWS-PACKAGE-001 | No formal Windows installer or update channel | Repository audit | Select packaging/signing technology and validate install, upgrade, rollback, and uninstall |
| REL-GITHUB-RELEASE-001 | No GitHub Release process | Repository audit | Define tag, changelog, artifact checksums, approvals, and reproducible publication |
| REL-WINDOWS-CI-001 | Quality workflow has no Windows job | `.github/workflows/quality.yml` | Add Windows analyze/test/build packaging verification |
| REL-PYTHON-LOCK-001 | Python dependencies use ranges rather than a full lock | `server/requirements.txt` | Adopt a reviewed deterministic lock/update policy and prove CI/install parity |
| REL-IMAGE-DIGEST-001 | Base images use floating tags, not digests | `server/Dockerfile`, workflows | Pin reviewed image digests and define controlled update automation |
| REL-SUPPLY-CHAIN-001 | No SBOM, image signing, provenance Gate, or dependency scan | Workflow audit | Add generated SBOM, signed artifacts/images, provenance, and blocking vulnerability policy |
| REL-BACKUP-DR-001 | No Production backup/restore drill | Sprint 15A provides plaintext local export only | Define RPO/RTO, encrypted operational backups, a reviewed restore implementation and rehearsal, ownership, and evidence retention |
| REL-MONITORING-001 | No formal Production monitoring and incident validation | Operational docs | Define SLOs, alert routing, log retention, on-call/incident roles, and run a drill |
| REL-DELETION-001 | No end-to-end account/data deletion policy validation | Product/operations audit | Approve retention/deletion policy and verify local, cloud, backup, ledger, and export behavior |
| REL-STEP-UP-001 | Step-up and callback controlled scenarios remain incomplete | 24 PASS / 0 FAIL / 12 NOT EXECUTED | Execute safe proof expiry, replay, cross-session/account, callback, and persistence scenarios |
| REL-WECHAT-001 | Real WeChat login is unsupported | No SDK, QR flow, or real Adapter | Product/security/legal approval plus real Provider implementation and acceptance, if still in scope |
| REL-RECOVERY-MFA-001 | Password recovery and MFA are unsupported | Auth product audit | Define recovery and MFA threat model, implementation, abuse controls, and manual acceptance |

None of these blockers is resolved merely by generating an APK, pushing an
image, or passing the existing Quality workflow.

## Known Non-blocking Engineering Warnings

- Existing Flutter Android builds may report a future Kotlin Gradle Plugin
  migration warning from `flutter_file_dialog`; it is not a current build
  failure but should be tracked before the required toolchain upgrade.
- Current GitHub runs may annotate Node.js 20 deprecation for
  `actions/checkout@v4` and `actions/setup-python@v5`; current jobs pass, but
  action upgrades need a planned compatibility update.

Warnings must be re-evaluated when Flutter, Gradle, Java, or GitHub Actions
versions change.

## Candidate Private Alpha Checklist

Before every separately authorized Alpha deployment:

1. select an exact source commit and API image digest;
2. confirm Quality CI belongs to that commit;
3. back up the existing database and confirm restore material is usable;
4. review additive Alembic requirements and current database head;
5. review all server-only auth and AI configuration without printing values;
6. deploy only the intended API service unless the change explicitly requires
   another service;
7. verify `/health`, API Version 1, Sync Protocol 2, authentication, and device
   registration;
8. perform smoke checks for local save, manual Sync Center behavior, account
   isolation, consent, AI usage state, AI Report library/export, and full
   personal data export;
9. record exact artifact identity and any honestly NOT EXECUTED scenario;
10. provide rollback criteria before expanding testers.

This checklist does not authorize remote access, deployment, migration, or
secret changes.

## Public Release Exit Themes

A public release needs explicit owner decisions for:

- product name, package/application identifiers, versioning, and release
  channels;
- Android and Windows signing custody;
- Windows installer/update format and Android store target;
- privacy policy, consent language, data export, retention, and deletion;
- supported authentication recovery and MFA posture;
- whether real WeChat remains deferred or becomes a launch dependency;
- Provider vendors, regional/privacy terms, budget ownership, and kill-switch
  authority;
- backup RPO/RTO, monitoring SLOs, incident response, and support ownership;
- dependency update cadence and vulnerability severity policy.

## Evidence Boundaries

- The last audited Quality run is linked in
  [Current Baseline](CURRENT_BASELINE.md).
- Manual conclusions and supersession are in
  [Manual Acceptance Registry](manual_tests/README.md).
- The old [v0.7.0-alpha Build Manifest](release/v0.7.0-alpha-build-manifest.md)
  and [Release Notes](release/v0.7.0-alpha-release-notes.md) are historical;
  they do not identify the current HEAD.
- GHCR image publication is documented in
  [Alpha GHCR Deployment](15_ALPHA_GHCR_DEPLOYMENT.md), but publication alone
  is not proof of a running deployment.

## Sprint 15A Boundary

Sprint 15A adds only an explicit local full-personal-data export foundation.
It does not close the Production backup/disaster-recovery blocker because it
has no import/restore path, encryption, RPO/RTO policy, scheduled operation, or
restore drill. It does not change package identity, signing, dependencies,
images, workflows, database schemas, API Version, Sync Protocol, Server runtime,
remote services, or GitHub releases. Its manual Gate remains OPEN.
