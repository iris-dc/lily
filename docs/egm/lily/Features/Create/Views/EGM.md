# Create Views

Source: `lily/Features/Create/Views/` (the step pages: [./Event/EGM.md](./Event/EGM.md),
[./Group/EGM.md](./Group/EGM.md), [./Tournament/EGM.md](./Tournament/EGM.md))

## Overview

The creation wizard's chrome: `CreationWizardView` owns the `NavigationStack` whose root is the seeded kind's first
step (the kind page left with the owner's third design round, 2026-11-11 — the "+" menu names the kind), with every
Next pushing the next step; `WizardStepScaffold` is the chrome every step shares (title, the animated progress mark
with the plural-safe counter as its accessibility label, one caption under every step title, the entrance motion,
Cancel, the transparent bottom bar with the one primary button, the scroll reader and the final-gate hint), with
`WizardCancelItem`, `WizardIssueHint`, `WizardProgressBar`, `WizardChoiceCard`, the searchable `WizardTypePicker`
grid and the `wizardEntrance()` modifier as its shared pieces.
Per-step copy and identifiers live in one map, `WizardStepCopy.swift` (computed switches on `CreationStep`, exempt
from the complexity rule). The shell is generic over the three kind view-model types, mirroring
[`../State/EGM.md`](../State/EGM.md); the scaffold and the step pages read the wizard through
`CreationWizardControlling` ([`../Interfaces/EGM.md`](../Interfaces/EGM.md)) and bind their own kind's view model
through its draft-editing protocol alone. The wizard view is presentation-agnostic — the presenting screen (Explore,
and the group detail since slice 3) chooses full-screen cover or form sheet and injects the model through
`AppDependencies.makeCreationWizardModel`.

## Interface

- `CreationWizardView<EventModel: EventDraftEditing, GroupModel: GroupDraftEditing, TournamentModel: TournamentDraftEditing>`
  (`lily/Features/Create/Views/CreationWizardView.swift:CreationWizardView`):
  `init(model: CreationWizardModel<...>, errorCenter: ErrorCenter)` (call sites hold the `AppCreationWizardModel`
  typealias); owns the model in `@State`, wraps the stack in the flow's one `ContentScreen` (the 2026-11-11
  performance pass: one live aurora and grain for the whole flow) and binds the stack's path to `model.path`; its
  `navigationDestination(for: CreationStep.self)` renders the step pages and the place steps' map pickers
  (`.eventMap`/`.groupMap`/`.tournamentMap`: `LocationPickerView` writing through the kind draft's
  `PlacePickingDraft.pickSpot`, hosted with `drawsBackground: false` under the step pages' clear navigation
  container background, so the shell's one aurora shows through the map push too — the 2026-11-11 round-3 review's
  double-aurora catch).
- `WizardStepScaffold<Content>` (`lily/Features/Create/Views/WizardStepScaffold.swift:WizardStepScaffold`):
  `wizard: any CreationWizardControlling`, `step`, optional `scrollTarget: AnyHashable?`, `onCancel`,
  `@ViewBuilder content`. Renders the step title (`.navigationTitle`, large; `step.wizardTitle`) with
  `WizardProgressBar` under it, one short `.subheadline` `.secondary` caption under every step title
  (`step.wizardCaption`; the third design round, 2026-11-11), the caption and fields easing in together through
  `wizardEntrance()`, the content scrolling transparently inside the readable column over the shell's aurora
  (`.containerBackground(Color.clear, for: .navigation)` clears the navigation hosting's opaque page background,
  which would otherwise hide it), and a transparent
  bottom safe-area-inset bar carrying the one primary button, its capsule directly over the content and the aurora
  (the same round's supersession of the opaque-bar pin).
- `WizardStepCopy.swift` (`nonisolated extension CreationStep`): `wizardTitle`, `wizardCaption?`,
  `wizardSubmitTitle` (each kind's existing submit copy) and `wizardSubmitIdentifier` (`create-submit`,
  `create-group-submit`, `tournament-submit` — the wizard and the edit sheets agree); the map cases answer their
  place step's title for exhaustiveness alone.
- `WizardProgressBar` (`lily/Features/Create/Views/WizardProgressBar.swift:WizardProgressBar`): `number` (from one),
  `count`; a `wizardProgressBarHeight` capsule track (`lilyInk` at `wizardProgressTrack`) whose accent fill grows to
  `number/count` of the width on appear, starting from the previous step's share so entering a step is seen filling
  the difference; animated (`.smooth`, `Duration.normal`) only while `\.motion` allows movement, settled otherwise;
  the plural-safe `AppBranding.Create.step(_:of:)` stays as its accessibility label.
- `WizardChoiceCard` (`lily/Features/Create/Views/WizardChoiceCard.swift:WizardChoiceCard`): the single-choice glass
  card of the wizard's auto-advancing pages — the label, and the accent `chosen` check on the current choice (accent
  on the mark, never the words); whole-card tap target, `.isSelected` trait on the selection.
- `WizardTypePicker` (`lily/Features/Create/Views/WizardTypePicker.swift:WizardTypePicker`): the type steps' picker
  (the third design round, 2026-11-11) — a glass search capsule (`create-type-search`, filtering by localized name,
  case- and diacritic-insensitively in the app's locale (`AppLocale`), as you type) over a `wizardTypeColumns`-column `LazyVGrid` of compact glass type cards
  (its private `WizardTypeCard`: `Radius.md` glass at least `wizardTypeCardHeight` tall, symbol and name with the
  accent `chosen` check on the current choice), optionally led by an "Any" entry (`anyTitle`, the group's nullable
  choice; the query filters it like any card); a query no name
  contains shows a one-line `.secondary` empty state (`AppBranding.Create.typeSearchNoMatch`, 2026-11-11) instead
  of a bare grid; tapping calls `pick` and the pages auto-advance.
- `wizardEntrance()` (`lily/Features/Create/Views/WizardEntrance.swift`): the step content's entrance — a fade with
  a `wizardEntranceOffset` slide-up over `Duration.fast`, the slide dropped under reduced motion, state reset on
  disappear so a pop-return eases in again.
- `WizardCancelItem` (`WizardStepScaffold.swift`): the shared Cancel toolbar item, `AppBranding.Forms.cancel` under
  the existing `create-cancel` identifier, disabled while submitting. `WizardIssueHint` (same file): takes
  `message: String?` (`wizard.blockingMessage(on:)`) and renders it in the shared `ValidationHint` look, nothing
  when clean.

## Invariants

- One-way kind, trivially: the kind's first step is the stack root (2026-11-11), so back stops there and no kind
  choice exists inside the wizard to revisit — a mispick is corrected by cancelling and reopening from the menu.
  While a submit is in flight the back button hides on every step (`CreationWizardView.hidesBack`), which also
  disables the pop gesture — the locked-while-busy contract's third lock,
  beside the disabled Cancel and the refused interactive dismissal.
- The step container rule: the scaffold marks its screen `.accessibilityElement(children: .contain)` *before*
  stamping `create-step`, so children keep their own identifiers; every pre-existing create field identifier is
  unchanged across all three kinds, the final step keeps its kind's submit identifier, Next carries `create-next`.
- Gating: Next is disabled exactly while `wizard.allowsNext(from: step)` is false and the final step's button keeps
  the whole-draft rule through `DraftSubmitButton(isEnabled: wizard.canSubmit)` with the shared spinner-and-disabled
  semantics. When the final gate is blocked by an earlier step's stale issue, the hint names that step
  (`wizard.blockingMessage(on:)` plus `blocked.wizardTitle`) and tapping it pops back
  (`WizardStepScaffold.blockedHint(step:message:)` over `wizard.pop(to:)`).
- Abandon: Cancel asks through a `confirmationDialog` (`AppBranding.Create.discardTitle`/`discard`/`keepEditing`;
  `keepEditing` is a plain-role button, since the centered iOS 26 dialog adds no automatic Cancel and swallows a
  `.cancel`-role action — the design-judge round's render proved it, 2026-11-10; the dialog mounts under an outer
  `.tint(Color.lilyInk)`, because it paints its plain action from the inherited tint and the accent read as red as
  Discard — the fourth round, 2026-11-11, `round4/discard-dialog.png`)
  only when `model.isDirty`, closing silently otherwise; interactive dismissal is refused while a submit is in
  flight *or* the draft is dirty, so a dirty draft is never swiped away silently and a write's outcome is never
  unknown (`CreationWizardView.body`); Cancel is disabled while submitting.
- Lifecycle: `.task(id: model.kind)` runs `model.prepare()` when a kind is entered; `.onChange(of: model.draft)`
  (one `CreationDraft` value for every kind) reports edits to `model.noteDraftChanged()`; the view dismisses itself
  when `model.isDone` turns true. The flow's close is booked by the presenter after the real dismissal
  (`model.noteClosed()` in Explore's and the group detail's `clearWizardAfterDismiss`), never on disappear, which a
  width-class re-host also fires. The error popup is mounted here (`.errorPopup`), the one mount of this presentation.
- The scaffold's scroll reader brings `scrollTarget` (the page's focused field) into view, animated only when
  `\.motion` allows movement; the bottom bar is transparent — the primary capsule sits directly over the content
  and the aurora (the owner's third design round, 2026-11-11, superseding the 2026-11-10 opaque-bar pin, which the
  owner read as a dark grey slab).
- One live aurora per flow (the 2026-11-11 performance pass, after the owner's lag report): the shell's
  `ContentScreen` is the only aurora in the wizard, a step page draws no background of its own, and a push
  composites one live aurora instead of two full aurora-and-grain layers — the pushed map picker included
  (`LocationPickerView(drawsBackground: false)` plus the cleared navigation container background; the round-3
  review caught the map push still drawing its own `ContentScreen`, fixed 2026-11-11); the per-push film numbers
  are in `docs/notes/design-and-ui.md`.
- Every added motion reads `\.motion`, never raw reduce-motion: the progress fill and the entrance slide are
  movement and settle instantly under reduced motion (the entrance fade stays — a fade in place is allowed either
  way); the auto-advancing pages (type, format, visibility) push with the stack's own transition.

## Side Effects

- None beyond presentation: the views call the model's actions and mount the shared popup; no storage, network or
  logging of their own (the model logs).

## Verification

- Run: `./scripts/ci.sh build` (zero `/lily/` warnings) and `./scripts/ci.sh unit` (the model behind every control:
  `lilyTests/Create/`). The wizard is reached through the "+" menu's items, the parked create intents and the group
  screen's create buttons; the walks are pinned on a simulator by `LilySmokeTests`, `LilyGroupsTests`,
  `LilyEventEditTests`, `LilyProfileTests`, `LilyDiscoverTests`, `LilyTournamentTests` and `LilyIPadTests`
  (the seven UI classes of the third round's gate).
