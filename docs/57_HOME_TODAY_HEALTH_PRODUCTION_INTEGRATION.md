# Home / Today / Health Production Integration

> Sprint: 17B
> Baseline: `3eaf4c11f9b7bfdf8b78d18992fd1aaa9abaa593`
> Implementation commit: `cab60cf9cf74ee452f6b082ac37dba342894fc28`
> Sync contract repair commit: `f7b1bb6dcf5aedc1c50bc1951cf6eb7e82309668`
> Implementation status: complete in source; manual Gate OPEN

## Product Boundary

Sprint 17B promotes the accepted Sprint 17A.1 experience into the protected,
account-scoped product. After authentication, `/home` is the default route. It
is a read-only overview of the current local day and never creates blank rows,
starts sync, or invokes AI.

Home contains the local date and clock, a week calendar, a deterministic local
quote, current Today priorities, lightweight Today and Health summaries, and
cards for Today, Journal, Plan, Health, Growth, and AI Coach. The bundled day
and night images are offline assets. The quote is explicitly labelled as local
and must not be presented as AI-generated.

Home reads through Riverpod application providers and domain repositories.
Widgets do not import Drift, `AppDatabase`, or repository implementations.
Today and Health saves bump the shared record revision so a returning Home
reloads its summary. Partial Today or Health read failures keep the other
available content visible.

## Production Inputs

Today now uses the shared `WellbeingRatingField` for nullable Mood and Energy
scores from 1 through 10. Each score has an independent optional description,
trimmed to at most 80 characters. Research and Learning remain `int? minutes`
and use the shared 15/30/60 minute step control. Priorities, explicit zero,
daily-note null normalization, save retry, and duplicate-save prevention keep
their established semantics.

Health uses `WaterCupIndicator` and `QuickIncrementControl` for nullable water
intake with 100/250/500 ml choices and a default 250 ml step. Exact manual
entry remains available. Decrement clamps at zero; values above the visual
capacity remain exact in text while the cup stays visually full. Sleep and
Exercise remain `int? minutes`. Physical State uses the same nullable 1-10
rating and optional 80-character description. Weight, exercise type, note,
hidden fields, save retry, and explicit null/zero behavior are preserved.

These controls never auto-save or auto-sync. `visualCapacityMl` is a drawing
scale, not medical advice, and the UI makes no target or diagnosis claim.

## Score Compatibility And Migration

Flutter Drift advances from schema 12 to 13. The migration adds:

- `today_records.wellbeing_score_scale`;
- `today_records.mood_description`;
- `today_records.energy_description`;
- `health_records.physical_state_score_scale`;
- `health_records.physical_state_description`.

The migration does not rewrite scores, `updated_at`, sync metadata, tombstones,
or server versions. Existing rows therefore keep a null scale and are read as
legacy 1-5 values. Domain conversion is `oldScore * 2`, so 1/2/3/4/5 become
2/4/6/8/10. New writes store the entered 1-10 value and scale `10`. Null stays
null, and descriptions may exist without a score.

The same rule applies to Sync Protocol 2 payloads: a legacy exact key set with
no scale is decoded as scale 5; a current payload includes scale and the new
description fields. Domain, Growth, AI input, conflict presentation, Personal
Data, and export consume normalized 1-10 values. Full Personal Data Export
includes normalized scores, descriptions, and scale metadata.

Current Sprint 17B clients exchange the expanded payload without changing API
Version 1 or Sync Protocol 2. An older client can still read the legacy fields,
but if it edits and uploads the same record it cannot preserve fields it does
not understand. Both devices should therefore be upgraded before editing or
resolving Today/Health conflicts.

Manual acceptance exposed that the initially deployed Server still validated
only the legacy 1-5 payload and forbade the new fields. The source fix extends
the existing `TodaySyncPayload` and `HealthSyncPayload` validators to accept
either the exact legacy contract or the complete expanded contract. A partial
extension, a score above its declared 5/10 scale, blank descriptions, and
descriptions over 80 characters remain rejected. Payload JSON continues to be
stored and returned exactly as submitted, so legacy rows are not rewritten.
The fixed API image must be deployed before E1-E5 are retested.

## Data And Security Boundaries

- Home, Today, and Health remain scoped to the authenticated account.
- Account change or logout invalidates the overview state.
- No persistent server model, Alembic revision, Provider, Prompt, usage ledger,
  or quota changes are part of this Sprint. Server sync request validation is
  expanded only to carry the new client fields without data loss.
- No automatic AI, network image, automatic sync, background sync, medical
  target, or gamification is introduced.
- Date and time reads use `DateTimeService`; business code does not bypass it.
- The developer experience preview remains a labelled historical comparison,
  not a production persistence entry point.

API Version 1 and Sync Protocol 2 remain unchanged.

## Release Gate

The **Home / Today / Health Production Integration Gate** remains **OPEN**. The
initial cross-device run exposed and documented a Server validation blocker;
the fixed API must be deployed and E1-E5 must pass. The remaining matrix in
`docs/manual_tests/62_home_today_health_production_integration.md` must also be
executed on Windows and Android. Automated tests and builds are evidence for
the source implementation only and are not manual PASS.
