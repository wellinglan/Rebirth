# Rebirth Manual Acceptance Registry

> Classification: **Active / authoritative Gate registry**
> Consolidated: **2026-08-20 / Sprint 17B production integration implementation**

Manual matrices record only real product execution. Automated tests never
become manual PASS. `NOT EXECUTED` is an honest capability or fixture limit,
not a hidden PASS and not automatically a product failure.

Current technical versions and implementation state are in
[Current Baseline](../CURRENT_BASELINE.md). This registry owns the current Gate
conclusion and its evidence lineage; individual matrices retain the facts that
were true when they were recorded.

## Gate States

| State | Meaning |
|---|---|
| CLOSED / ACCEPTED | Applicable manual product checks passed and no current blocker remains for that Gate. |
| CONDITIONALLY ACCEPTED | Applicable checks passed, but named unavailable scenarios remain outside the evidence. |
| CLOSED WITH ACCEPTED LIMITATION | A specific, documented NOT EXECUTED limitation was accepted for the current scope. |
| OPEN | Required manual evidence or a required capability is still missing. |
| HISTORICAL / SUPERSEDED | Preserve the old result; a later named matrix owns the current conclusion. |

## Unified Gate Registry

Counts are written as `PASS / FAIL / NOT EXECUTED`. A `matrix-wide` count means
the named Gate was exercised inside a larger accepted matrix; it does not claim
that a separate module-only matrix was rerun.

| Gate | Current state | Latest authoritative evidence | Result | Succession and remaining limitation |
|---|---|---|---|---|
| Profile Sync | CLOSED / ACCEPTED | [Settings and Sync Center](39_settings_information_architecture_and_sync_center.md) | 113 / 0 / 0 matrix-wide | Unified Profile flow supersedes separate upload/pull UX; manual-only sync remains |
| Plan | CLOSED / ACCEPTED | [Settings and Sync Center](39_settings_information_architecture_and_sync_center.md) and [Plan Date UX](05_plan_hierarchy_date_ux.md) | 113 / 0 / 0 matrix-wide; final date regression PASS | Old [Plan Sync](25_plan_cross_device_sync.md) and [Conflict Recovery](26_sync_conflict_recovery.md) blockers are historical; later account isolation/remediation and unified acceptance own current state |
| Today | CLOSED / ACCEPTED | [Today Conflict Recovery](33_today_conflict_recovery.md) | 51 / 0 / 0 | Supersedes the partial OPEN conclusion in [Today Sync](32_today_cross_device_sync.md) |
| Journal | CLOSED / ACCEPTED | [Journal Cross-device Sync](34_journal_cross_device_sync.md) | 39 / 0 / 0 | Transport and retained-conflict repairs are included in later regression evidence |
| Health | CLOSED / ACCEPTED at unified-product level | [Settings and Sync Center](39_settings_information_architecture_and_sync_center.md) | 113 / 0 / 0 matrix-wide | Dedicated [Health Sync](35_health_cross_device_sync.md) remains historical at 0 / 0 / 43; no claim of a dedicated 43-row rerun |
| Growth | CLOSED / ACCEPTED | [Growth System Foundation](37_growth_system_foundation.md) | 71 / 0 / 6 | Six safe Provider-failure injections remain NOT EXECUTED; Growth is local derived data, not sync |
| Personal Data | CLOSED / ACCEPTED | [Personal Data Aggregation](36_personal_data_aggregation.md) | 49 / 0 / 5 | Five safe Provider-failure injections remain NOT EXECUTED; aggregation is not persisted or synced |
| Journal Prompt | CLOSED / ACCEPTED | [Journal Prompt System](38_journal_prompt_system.md) | 93 / 0 / 0 | Prompt configuration sync is part of Journal and precedes entries |
| Settings / Sync Center | CLOSED / ACCEPTED | [Settings and Sync Center](39_settings_information_architecture_and_sync_center.md) | 113 / 0 / 0 | Includes final retained Today/Journal conflict repair and the five-module UI; AI Report was added later as the sixth module |
| Authentication | CLOSED / ACCEPTED for public password/session scope | [Public Username/Password Login](41_public_username_password_login.md) | 107 / 0 / 7 | Supersedes carried Gates in [Auth Protocol](40_authentication_protocol_and_secure_session.md); recovery remains open and the seven legacy-binding rows remain unavailable |
| Account Boundary | CLOSED / ACCEPTED | [Settings and Sync Center](39_settings_information_architecture_and_sync_center.md) and [Public Login](41_public_username_password_login.md) | 113 / 0 / 0 matrix-wide; 107 / 0 / 7 auth matrix | Supersedes the all-NOT-EXECUTED [Account Isolation](27_account_boundary_isolation.md); no automatic legacy ownership guess |
| Multi Identity Product | OPEN | [Multi Identity Foundation](42_multi_identity_foundation.md) | 0 / 0 / 38 | Source and automation exist, but the dedicated Windows/Android/offline/privacy matrix was never manually executed |
| WeChat Identity Foundation | CLOSED | [WeChat Identity Foundation](43_wechat_identity_foundation.md) | 30 / 0 / 0 | Foundation only; real WeChat login remains unsupported |
| WeChat OAuth Transaction | CLOSED | [WeChat OAuth Transaction Security](44_wechat_oauth_transaction_security.md) | 24 / 0 / 0 | Transaction/replay foundation only; no real SDK, QR, or Provider exchange |
| Step-up Reauthentication | OPEN | [Step-up Reauthentication](45_step_up_reauthentication.md) | 24 / 0 / 12 | Controlled expiry, replay, cross-session/account, callback, and database inspection scenarios remain |
| AI Provider Cost Safety | CLOSED | [Real AI Provider and Cost Safety](46_real_ai_provider_and_cost_safety.md) | 32 / 0 / 0 | Proves recorded Alpha execution, not current remote Provider configuration |
| AI Usage Transparency | CLOSED | [AI Usage Transparency](47_ai_usage_transparency_and_operational_safety.md) | 36 / 0 / 0 | User sees own usage only; global limits and credentials remain server-only |
| AI Operations | CLOSED | [AI Operations Acceptance](49_ai_operations_acceptance.md) | 72 / 0 / 0 | Supersedes the 0 / 0 / 34 OPEN result in [AI Audit and Operations](48_ai_usage_audit_and_operations.md) |
| AI Consent Route | CLOSED | [AI Consent Route Repair](50_ai_consent_settings_route_repair.md) | 25 / 0 / 0 | Its historical statement that operations Gates were OPEN is superseded by matrix 49 |
| AI Report Persistence | CONDITIONALLY ACCEPTED | [AI Report Persistence](51_ai_report_persistence.md) | 34 / 0 / 8 | Unavailable loading/failure/multi-version/log-capture product fixtures remain honestly NOT EXECUTED |
| AI Report Sync | CLOSED for applicable product scope | [AI Report Cross-device Sync](45_ai_report_cross_device_sync.md) | 12 / 0 / 9 | The nine unavailable archive/conflict UI rows are historical and superseded by the 14D lifecycle matrix |
| AI Report Lifecycle | CLOSED | [AI Report Lifecycle](52_ai_report_lifecycle_conflict_readiness.md) | 25 / 0 / 0 | Archive, delete conflict, both resolutions, privacy, and account scope accepted |
| AI Report Library | CLOSED | [AI Report Library](53_ai_report_library_consolidation.md) | 31 / 0 / 0 | One canonical list/detail entry and lifecycle/sync regression accepted |
| AI Report Export | CLOSED WITH ACCEPTED LIMITATION | [AI Report Safe Export](54_ai_report_safe_export.md) | 37 / 0 / 1 | SessionRejected injection was unavailable; export has no import/restore promise |
| Full Personal Data Export | CLOSED WITH ACCEPTED LIMITATIONS | [Full Personal Data Export and Backup](55_full_personal_data_export_and_backup.md) | 49 / 0 / 5 | Windows/Android applicable rows passed; five safe failure/timing injection fixtures remain unavailable; plaintext export has no import/restore promise |
| AI Report Generation Pipeline | CLOSED WITH ACCEPTED LIMITATIONS | [AI Report Generation Pipeline](56_ai_report_generation_pipeline.md) | 35 / 0 / 7 | Applicable rows passed and Quality run 31073858896 passed; six controlled recovery states and one binding-write failure fixture remain unavailable and automated only |
| Prompt Governance and Quality Evaluation | CLOSED WITH ACCEPTED AUTOMATION AND COST LIMITATIONS | [Prompt Governance and Quality Evaluation](57_prompt_governance_and_quality_evaluation.md) | 30 / 0 / 8 | Deployed CLI and privacy boundaries passed; runtime protocol repetitions use named automated evidence; Level 3 real Provider evaluation has no cost authorization |
| AI Coach MVP Product Experience | CLOSED WITH ACCEPTED LIMITATIONS | [AI Coach MVP Product Experience](58_ai_coach_mvp_product_experience.md) | 29 / 0 / 8 | Applicable Windows/Android, consent, real Provider Daily/Weekly, reuse, account, privacy, and product UX rows passed; eight dangerous runtime injections retain accepted automated evidence |
| AI Coach Feedback & Quality Signal | OPEN / SUSPENDED | [AI Coach Feedback and Quality Signal](59_ai_coach_feedback_and_quality_signal.md) | 3 / 0 / 36 | Alpha image, migration, and health identity passed; remaining product matrix was explicitly suspended for Sprint 17A |
| Product Experience Foundation | OPEN | [Product Experience and Design System](60_product_experience_design_system.md) | 0 / 0 / 30 | Foundation is implemented; Windows and Android visual/accessibility acceptance remains NOT EXECUTED |
| Home / Today / Health Experience Prototype | CLOSED | [Home / Today / Health Experience Prototype](61_home_today_health_experience_prototype.md) | 81 / 0 / 0 | Developer-only in-memory prototype including Revision 1 wellbeing ratings accepted on Windows and Android; production integration remains a separate decision |
| Home / Today / Health Production Integration | OPEN | [Home / Today / Health Production Integration](62_home_today_health_production_integration.md) | 34 / 3 / 14 | Home, form, and persistence batches passed; deploy the dual-format Server validation fix and retest E1-E5 before continuing |

## Important Succession Rules

- An OPEN status in a historical file is not deleted. The registry names the
  later evidence that supersedes it.
- The Sprint 10B Plan/account conflict in matrices 25-29 is historical. Later
  remediation, account-bound auth, and matrix 39 own the current product
  conclusion.
- Matrix 35 is still a valid record that its dedicated Health run did not occur.
  Matrix 39 later accepted Health inside the unified cross-device product flow;
  the two facts are not contradictory.
- Matrix 40's carried authentication Gates are superseded by matrix 41. Public
  account recovery is still OPEN / DEFERRED.
- Matrix 42 remains OPEN even though narrower WeChat identity and transaction
  foundations in matrices 43 and 44 passed. Those foundations do not prove the
  complete multi-identity product matrix.
- Matrix 48 remains historical evidence of a then-unexecuted operations Gate;
  matrix 49 closes that Gate in the authorized Alpha acceptance scope.
- Matrix 50 closes the consent routing bug. Its older operations-Gate lines are
  superseded by matrix 49.
- Matrix 45 AI Report Sync keeps nine unavailable UI rows. Matrix 52 provides
  the later archive/conflict product evidence instead of rewriting matrix 45.

## Current Matrix Index

### Sync, Account, and Data

- [Plan Cross-device Sync](25_plan_cross_device_sync.md) - Historical blocker
- [Sync Conflict Recovery](26_sync_conflict_recovery.md) - Historical blocker
- [Account Boundary Isolation](27_account_boundary_isolation.md) - Historical, superseded
- [Legacy Local Data Resolution](28_legacy_local_data_resolution.md) - Historical
- [Legacy Cloud Ownership Verification](29_legacy_cloud_ownership_verification.md) - Historical blocker
- [Legacy Sync Re-entry Remediation](30_legacy_sync_reentry_remediation.md) - Historical partial acceptance
- [Today Cross-device Sync](32_today_cross_device_sync.md) - Historical partial acceptance
- [Today Conflict Recovery](33_today_conflict_recovery.md) - Current Today authority
- [Journal Cross-device Sync](34_journal_cross_device_sync.md) - Current Journal authority
- [Health Cross-device Sync](35_health_cross_device_sync.md) - Historical dedicated matrix
- [Personal Data Aggregation](36_personal_data_aggregation.md) - Current
- [Growth System Foundation](37_growth_system_foundation.md) - Current
- [Journal Prompt System](38_journal_prompt_system.md) - Current
- [Settings and Sync Center](39_settings_information_architecture_and_sync_center.md) - Current unified authority
- [Full Personal Data Export and Backup](55_full_personal_data_export_and_backup.md) - Current Gate closed with accepted limitations
- [AI Report Generation Pipeline](56_ai_report_generation_pipeline.md) - Current Gate closed with accepted limitations
- [Prompt Governance and Quality Evaluation](57_prompt_governance_and_quality_evaluation.md) - Current Gate closed with accepted automation and cost limitations
- [AI Coach MVP Product Experience](58_ai_coach_mvp_product_experience.md) - Current Gate closed with accepted limitations at 29 / 0 / 8
- [AI Coach Feedback and Quality Signal](59_ai_coach_feedback_and_quality_signal.md) - Current Gate OPEN / SUSPENDED at 3 / 0 / 36
- [Product Experience and Design System](60_product_experience_design_system.md) - Current Gate OPEN at 0 / 0 / 30
- [Home / Today / Health Experience Prototype](61_home_today_health_experience_prototype.md) - Gate CLOSED at 81 / 0 / 0
- [Home / Today / Health Production Integration](62_home_today_health_production_integration.md) - Gate OPEN at 34 / 3 / 14; E1-E5 require fixed API deployment and retest

### Authentication and Identity

- [Authentication Protocol and Secure Session](40_authentication_protocol_and_secure_session.md) - Historical foundation, partly superseded
- [Public Username/Password Login](41_public_username_password_login.md) - Current public auth authority
- [Multi Identity Foundation](42_multi_identity_foundation.md) - Current OPEN Gate
- [WeChat Identity Foundation](43_wechat_identity_foundation.md) - Closed foundation
- [WeChat OAuth Transaction Security](44_wechat_oauth_transaction_security.md) - Closed foundation
- [Step-up Reauthentication](45_step_up_reauthentication.md) - Current OPEN Gate

### AI and AI Reports

- [Real AI Provider and Cost Safety](46_real_ai_provider_and_cost_safety.md)
- [AI Usage Transparency](47_ai_usage_transparency_and_operational_safety.md)
- [AI Audit and Operations](48_ai_usage_audit_and_operations.md) - Historical OPEN, superseded
- [AI Operations Acceptance](49_ai_operations_acceptance.md) - Current operations authority
- [AI Consent Route Repair](50_ai_consent_settings_route_repair.md)
- [AI Report Persistence](51_ai_report_persistence.md)
- [AI Report Cross-device Sync](45_ai_report_cross_device_sync.md)
- [AI Report Lifecycle](52_ai_report_lifecycle_conflict_readiness.md)
- [AI Report Library](53_ai_report_library_consolidation.md)
- [AI Report Safe Export](54_ai_report_safe_export.md)
- [AI Report Generation Pipeline](56_ai_report_generation_pipeline.md) - Current Gate closed with accepted limitations
- [Prompt Governance and Quality Evaluation](57_prompt_governance_and_quality_evaluation.md) - Current Gate closed with accepted automation and cost limitations; real Provider evaluation not authorized
- [AI Coach MVP Product Experience](58_ai_coach_mvp_product_experience.md) - Current Gate closed with accepted limitations at 29 / 0 / 8
- [AI Coach Feedback and Quality Signal](59_ai_coach_feedback_and_quality_signal.md) - Current Gate OPEN / SUSPENDED at 3 / 0 / 36

Older UI, persistence, cloud, and AI reliability matrices `01` through `24`
remain in this directory as historical Sprint evidence. They do not override
the current Gate conclusions above.

## Updating This Registry

Only update a manual count after the user actually executes and reports the
matrix. When a later matrix supersedes an old result, retain the old file,
update the succession column, and state any remaining NOT EXECUTED scope.
