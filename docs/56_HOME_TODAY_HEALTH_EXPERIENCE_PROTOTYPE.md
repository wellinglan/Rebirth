# Home / Today / Health Experience Prototype

> Status: Sprint 17A.1 implementation contract
> Baseline: `e0de17aa34f24040856d9b92869b295878b66225`
> Product state: developer-only, disposable prototype

## Purpose

Sprint 17A.1 turns the Sprint 17A design principles into one testable Flutter
prototype. It explores a calmer Home composition, demand-revealed presets,
incremental inputs, and an exact-value water visualization before any production
navigation or form is replaced.

The prototype is available only when `enableDevLogin` is true:

```text
Settings -> Developer Options -> Home / Today / Health Prototype
```

Production does not register the route. Direct navigation to the nested route is
denied by the same developer-route boundary.

## Product Boundary

- All mutable values live in the prototype page's memory.
- Simulated save shows a notice and performs no persistence.
- No Repository, Drift, AppDatabase, controller, API client, AI Provider, or
  SyncCoordinator is imported by the prototype presentation layer.
- Opening, editing, resetting, or leaving the prototype never saves or syncs.
- Existing HomeShell destinations, Today, Health, database schema, API, and Sync
  Protocol are unchanged.
- The two environment images are original generated bitmap assets bundled as
  optimized WebP files. The app performs no image download at runtime.

## Home Prototype

The Home view combines a local DateTimeService clock, compact current-week
calendar, deterministic local quote, three-priority summary, gentle health
summary, and six functional module entries. Day and night use separate offline
assets. Quotes are selected deterministically by local natural date and are
explicitly labelled as local, not AI-generated.

The environment image is a full-width visual band with readable overlay text.
It does not imply that a production Home route or seventh HomeShell destination
now exists.

## Today Prototype

Duration presets are hidden behind one `选择预设` action. Compact screens use a
bottom sheet; wide screens use a menu. Research and learning also use the shared
stepper with 15, 30, and 60 minute choices. Values remain `int? minutes`, and the
display splits them into hours and minutes.

## Health Prototype

`WaterCupIndicator` renders an exact millilitre label plus a relative water
level. Its default visual capacity is 2000 ml only to scale the drawing; it is
not a medical recommendation and never labels a value as good, bad, complete,
or deficient. Values above capacity remain exact in text while the cup stays
visually full.

Exercise and sleep reuse the duration stepper as a limited experience probe.
The additional body-signal bar is explicitly a visual hierarchy placeholder,
not a health conclusion.

## Increment Control

The reusable component is `QuickIncrementControl`:

```dart
QuickIncrementControl(
  value: waterIntakeMl,
  stepOptions: const [100, 250, 500],
  selectedStep: 250,
  unit: 'ml',
  minimumValue: 0,
  onChanged: onWaterChanged,
  onStepChanged: onWaterStepChanged,
  allowNull: true,
)
```

Water defaults to 250 ml and allows 100, 250, or 500 ml. Duration prototypes
allow 15, 30, or 60 minutes. The component supports increase, decrease, clear,
and an on-demand step selector. It does not show all choices as persistent
chips.

Value rules:

- `null + step` starts at the selected positive step;
- explicit `0 + step` also starts at that step;
- decrement clamps to the configured minimum and never becomes negative;
- decrementing `null` keeps `null`;
- clearing returns to `null`, while `0` remains an explicit recorded value;
- changing the step never changes the current value;
- an optional maximum clamps additions, while no maximum permits exact values
  beyond the visual indicator's capacity;
- consecutive events update component memory in order and do not trigger save
  or sync.

Buttons use Material focus behavior for Tab, Enter, and Space, have at least the
shared 48 px target, and expose current value, action, step, and unit through
Semantics. Controls wrap at compact widths.

## Motion and Responsive Behavior

Water level uses `AppMotion.emphasized` with an ease-out transition. Flutter's
`MediaQuery.disableAnimations` changes the duration to zero. There is no loop,
shader, 3D scene, or background animation.

Automation covers widths 320, 360, 412, 720, and 1200 px plus TextScaler 2.0.
The experience remains vertically scrollable. The three-view segmented selector
becomes a labelled dropdown on compact or large-text layouts instead of adding
horizontal page scrolling or compressing its labels.

## Deliberately Deferred

- replacing the production `/home` redirect or HomeShell navigation;
- writing prototype values to Today or Health;
- redesigning all production forms;
- AI-generated greetings or network images;
- production visual targets, medical goals, gamification, or achievements;
- persisting prototype state across restart.

The next decision must use manual Windows and Android evidence from
`manual_tests/61_home_today_health_experience_prototype.md`.
