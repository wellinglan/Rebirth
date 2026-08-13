# Product Experience Audit and UI Design System Foundation

> Sprint: **17A**
> Classification: **Active foundation / visual direction intentionally open**
> Starting HEAD: `6f8415b8f7a69dfc61b39c8d98251604e200d92a`

## Purpose

Sprint 17A establishes a coherent product-experience foundation before the
feature pages receive deeper visual redesign. It does not treat UI polish as
decoration and does not make one speculative art direction irreversible. The
foundation defines layout, color, control, navigation, state, motion, and
accessibility contracts that future Today, Journal, Plan, Growth, Health, and
AI Coach work can share.

No business workflow, repository, local or server database, API, Provider,
quota, AI generation, synchronization, or conflict rule changes in this
Sprint. The suspended Sprint 16B manual Gate remains separate.

## Product Experience Thesis

Rebirth should feel like a **calm growth workspace**:

- more reflective than a task manager;
- more operational than an editorial wellness app;
- more humane than a data dashboard;
- more trustworthy than a chat-first AI wrapper.

The interface should help the user see three things quickly: what is true now,
what deserves attention next, and how today connects to a longer trajectory.
It should not turn growth into points, streak pressure, ranking, or decorative
analytics.

The first visual direction uses cool white surfaces, ink-like text, restrained
evergreen as the primary action color, a muted mineral secondary, a small warm
accent, and independent success, warning, info, and error roles. It deliberately
avoids gradients, ornamental blobs, excessive elevation, pill-shaped everything,
and large marketing cards inside the product.

## Experience Principles

1. **Quiet by default.** One primary action and one clear reading order are
   preferable to simultaneous calls for attention.
2. **Facts before judgment.** Scores, trends, and AI output describe evidence;
   they do not grade the user.
3. **Progressive disclosure.** Advanced filters, sync metadata, AI technical
   details, and destructive actions stay available without occupying the main
   daily path.
4. **Local-first is visible.** Saving locally, pending sync, offline access,
   and conflict recovery must use plain language and must not look like data
   loss.
5. **Sensitive means restrained.** Journal, Health, AI input, and report
   content receive strong hierarchy and privacy context, not visual spectacle.
6. **Motion explains change.** Animation may connect expansion, saving,
   navigation, and lifecycle change. It must never delay an action, conceal
   state, or ignore reduced-motion preferences.
7. **Desktop is not stretched mobile.** Windows uses constrained reading
   widths and persistent navigation; Android prioritizes reachability and
   compact vertical rhythm.
8. **Accessibility is a layout input.** 320px width, TextScaler 2.0, keyboard
   focus, semantic labels, and 48px targets are design constraints rather than
   post-release fixes.

## Audit Findings

### Existing strengths

- Material 3, GoRouter, and a feature-first presentation boundary are already
  stable.
- Typography has a disciplined Chinese fallback stack, explicit line heights,
  tabular number support, and no runtime font dependency.
- Many feature tests already exercise narrow widths and large text.
- Product actions generally use familiar Material icons and preserve local
  content through loading, errors, and conflicts.
- Core pages already constrain content instead of stretching every form across
  a Windows window.

### System-level gaps addressed in 17A

- The seeded palette lacked explicit semantic success, warning, and info roles.
- Layout constants did not describe responsive breakpoints, minimum targets,
  or width-dependent page padding.
- Home navigation had only a binary bottom-bar/rail decision and did not use
  wide Windows space to expose product identity.
- Inputs, buttons, menus, SnackBars, focus outlines, and navigation did not yet
  share a complete visual contract.
- Loading and error treatments were repeatedly implemented by individual
  features with uneven semantics and spacing.
- There was no reduced-motion contract for later interaction work.

### Page-level debt intentionally deferred

| Priority | Area | Current experience issue | Recommended follow-up |
|---|---|---|---|
| P0 | Global navigation | Six phone destinations are dense; large text trades labels for reachability | Test alternative compact navigation patterns with real users before changing information architecture |
| P0 | Forms | Today, Journal, Health, and Profile repeat long vertical field sequences | Introduce section rhythm, persistent action behavior, and lower-effort input patterns per feature |
| P0 | Plan | Hierarchy, filters, dates, and actions compete for space | Build a purpose-designed goal outline with progressive filter disclosure |
| P1 | Growth | Correct charts exist, but the page reads as separate panels rather than one longitudinal story | Design a time-led overview with evidence details on demand |
| P1 | AI Coach | Task and report flows are sound, but the Coach has limited emotional continuity | Add restrained task progression and report handoff, without becoming chat-first |
| P1 | Settings/Sync | Repeated card tiles create visual fragmentation and weak grouping | Move toward grouped full-width rows and clearer operational status hierarchy |
| P2 | Empty/error states | Copy and actions vary by module | Migrate features onto the shared state pattern as each page is redesigned |
| P2 | Dark theme | No audited dark palette exists | Treat as its own accessibility and visual QA Sprint, not an automatic inversion |

## Foundation Contract

### Color

`AppTheme` owns Material roles. `AppSemanticColors` adds success, warning, and
info foreground/container pairs. Feature code should use semantic roles rather
than hard-coded green, amber, blue, or red values. Error remains the Material
error role. Color may reinforce a state but cannot be its only signal.

### Shape and surfaces

- repeated cards use an 8px radius and no default elevation;
- dialogs may use a 14px radius because they are transient framed tools;
- buttons, inputs, menus, and icon controls use restrained 8px corners;
- page sections remain unframed; cards are reserved for individual records,
  actionable summaries, and genuinely bounded tools;
- nested decorative cards are not part of the design language.

### Spacing and layout

The spacing scale remains 4, 8, 12, 16, 20, 24, and 32px. Responsive contracts:

| Width | Foundation behavior |
|---|---|
| `< 600px` | 16px horizontal page padding and phone-first composition |
| `600-839px` | 20px page padding and compact/mobile navigation |
| `840-1199px` | compact NavigationRail plus constrained feature content |
| `>= 1200px` | expanded 224px product navigation and 32px outer page padding |

TextScaler 2.0 keeps the wide rail compact so labels do not consume the content
viewport. Interactive controls have a minimum 48px target.

### Typography

The existing role hierarchy remains authoritative. Hero-scale type is not used
inside forms, settings panels, or operational cards. Letter spacing remains
zero. Numeric summaries may use tabular figures. Feature redesigns should not
scale font size from viewport width.

### Controls and feedback

- familiar icon buttons retain tooltips and readable semantics;
- focused inputs use a visible two-pixel primary outline;
- loading announces a live semantic label;
- recoverable errors pair a concise fact with an explicit retry action;
- SnackBars float above navigation and report the result of an explicit action;
- disabled and saving states preserve the current page and prevent duplicate
  mutations.

### Motion

`AppMotion` defines 120ms quick, 200ms standard, and 300ms emphasized durations.
Future motion must call the reduced-motion-aware resolver. Infinite decorative
animation, parallax background motion, delayed navigation, and automatic
celebration are outside the product language.

## Home Shell

The six current first-level destinations remain unchanged and keep their
existing routes and branch state:

1. 今日
2. 复盘
3. 计划
4. 健康
5. 成长
6. AI 教练

At compact widths the shell uses the existing bottom navigation. At 840px it
uses a NavigationRail. At 1200px it expands the rail and presents `Rebirth` as
a first-viewport product signal. The Settings action remains globally
available in the AppBar. This is a presentation change only; it adds no route,
module, automatic action, or data access.

## Shared Page and State Primitives

- `AppScrollablePage` centralizes responsive padding, content width, and
  desktop alignment.
- `AppLoadingState` adds a stable, semantic loading indicator.
- `AppMessageState` provides a readable empty/error/status composition with an
  optional action.

Today loading/error and the Settings page are the first bounded consumers.
Other modules migrate only when their page-specific UX is deliberately
redesigned; 17A does not perform a mechanical full-repository rewrite.

## Creative Space for Later Design Work

The foundation intentionally leaves four areas open for stronger product
expression:

- **Today:** a lightweight daily ritual and a clear sense of completion without
  streaks or gamification;
- **Plan:** spatial expression of hierarchy, horizon, and movement through a
  goal rather than a generic card list;
- **Growth:** a longitudinal visual narrative that connects evidence without
  manufacturing a single score;
- **AI Coach:** attentive transitions between source selection, generation,
  report, reflection, and feedback without adopting a chat interface.

These are suitable places to combine product ideas, custom animation, and more
distinct visual identity after the user and implementation team agree on the
experience metaphor.

## Version and Boundary Record

- Flutter schemaVersion: `12`, unchanged;
- Server Alembic head: `20260812_0008`, unchanged;
- API Version: `1`, unchanged;
- Sync Protocol: `2`, unchanged;
- Server, Provider, Prompt, usage and generation ledgers: unchanged;
- no new dependency, bundled font, bitmap asset, database field, or network
  operation;
- Sprint 16B manual acceptance remains suspended and its Gate remains open.
