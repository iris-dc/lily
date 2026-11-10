# Create Views

Source: `lily/Features/Create/Views/` (the event step pages: [./Event/EGM.md](./Event/EGM.md))

## Overview

The creation wizard's chrome: `CreationWizardView` owns the `NavigationStack` whose root is the kind page when the
policy shows one and the kind's first step otherwise, with every Next pushing the next step; `CreationKindPage` is
the glass kind choice; `WizardStepScaffold` is the chrome every step shares (title, the animated progress mark with
the plural-safe counter as its accessibility label, the optional step caption, the entrance motion, Cancel, the
bottom bar with the one primary button, the scroll reader and the final-gate hint), with `WizardCancelItem`,
`WizardIssueHint`, `WizardProgressBar`, `WizardChoiceCard` and the `wizardEntrance()` modifier as its shared pieces. All are generic over the event view-model type, mirroring
[`../State/EGM.md`](../State/EGM.md); the pages bind to the view model through `EventDraftEditing` only. The wizard
view is presentation-agnostic — the presenting screen (Explore, since slice 2's bridge) chooses full-screen
cover or form sheet and injects the model through `AppDependencies.makeCreationWizardModel`.

## Interface

- `CreationWizardView<EventModel: EventDraftEditing>`
  (`lily/Features/Create/Views/CreationWizardView.swift:CreationWizardView`):
  `init(model: CreationWizardModel<EventModel>, errorCenter: ErrorCenter)`; owns the model in `@State` and binds the
  stack's path to `model.path`; its `navigationDestination(for: CreationStep.self)` renders the step pages and the
  place step's map picker (`.eventMap`: `LocationPickerView` writing through `EventDraft.pickSpot`).
- `CreationKindPage<Model>` (`lily/Features/Create/Views/CreationKindPage.swift:CreationKindPage`): one
  `GlassNavigationRow` per `opening.kindsOffered` under the `AppBranding.Create.kindTitle` navigation title; titles
  reuse the per-kind "New ..." copy; symbols `addEvent`/`groups`/`tournament`; identifiers `create-kind-event`,
  `create-kind-group`, `create-kind-tournament`; a pick calls `model.enter(_:)`, which auto-advances by pushing the
  kind's first step.
- `WizardStepScaffold<Model, Content>` (`lily/Features/Create/Views/WizardStepScaffold.swift:WizardStepScaffold`):
  `wizard`, `step`, optional `scrollTarget: AnyHashable?`, `onCancel`, `@ViewBuilder content`. Renders the step title
  (`.navigationTitle`, large) with `WizardProgressBar` under it (the step indicator since the second design round,
  2026-11-10), one short `.subheadline` `.secondary` caption on the steps whose purpose needs extra knowledge
  (`AppBranding.Create.event*Caption`: hosting group, place, players, details; name, type and when carry none), the
  caption and fields easing in together through `wizardEntrance()`, the content scrolling over `ContentScreen`
  inside the readable column, and a bottom safe-area-inset bar on `.bar` background over a `Color.lilySurface`
  underlay carrying the one primary button.
- `WizardProgressBar` (`lily/Features/Create/Views/WizardProgressBar.swift:WizardProgressBar`): `number` (from one),
  `count`; a `wizardProgressBarHeight` capsule track (`lilyInk` at `wizardProgressTrack`) whose accent fill grows to
  `number/count` of the width on appear, starting from the previous step's share so entering a step is seen filling
  the difference; animated (`.smooth`, `Duration.normal`) only while `\.motion` allows movement, settled otherwise;
  the plural-safe `AppBranding.Create.step(_:of:)` stays as its accessibility label.
- `WizardChoiceCard` (`lily/Features/Create/Views/WizardChoiceCard.swift:WizardChoiceCard`): the single-choice glass
  card of the wizard's auto-advancing pages — the label, and the accent `chosen` check on the current choice (accent
  on the mark, never the words); whole-card tap target, `.isSelected` trait on the selection.
- `wizardEntrance()` (`lily/Features/Create/Views/WizardEntrance.swift`): the step content's entrance — a fade with
  a `wizardEntranceOffset` slide-up over `Duration.fast`, the slide dropped under reduced motion, state reset on
  disappear so a pop-return eases in again.
- `WizardCancelItem` (same file): the shared Cancel toolbar item, `AppBranding.Forms.cancel` under the existing
  `create-cancel` identifier, disabled while submitting. `WizardIssueHint` (same file): a step's first live issue in
  the shared `ValidationHint` look, nothing when clean.

## Invariants

- One-way kind, by mechanism: the kind page stays the stack root, and the kind's first step — pushed, or itself the
  root — hides the system back button, which also disables the pop gesture
  (`CreationWizardView.stepPage(for:)`), so back stops at the first step and the kind page is never revisited.
  While a submit is in flight the back button hides on every step — the locked-while-busy contract's third lock,
  beside the disabled Cancel and the refused interactive dismissal.
- The step container rule: the scaffold marks its screen `.accessibilityElement(children: .contain)` *before*
  stamping `create-step`, so children keep their own identifiers; every pre-existing `create-*` field identifier is
  unchanged and the final step keeps `create-submit` on its submit button, Next carries `create-next`.
- Gating: Next is disabled exactly while `wizard.allowsNext(from: step)` is false and the final step's button keeps
  the whole-draft rule through `DraftSubmitButton(isEnabled: wizard.canSubmit)` with the shared spinner-and-disabled
  semantics (`DraftSubmitButton` with `.flexible`/`.large`, the full-width call-to-action look). When the final gate
  is blocked by an earlier step's stale issue, the hint names that step and tapping it pops back
  (`WizardStepScaffold.blockedHint(step:issue:)` over `wizard.pop(to:)`).
- Abandon: Cancel asks through a `confirmationDialog` (`AppBranding.Create.discardTitle`/`discard`/`keepEditing`;
  `keepEditing` is a plain-role button, since the centered iOS 26 dialog adds no automatic Cancel and swallows a
  `.cancel`-role action — the design-judge round's render proved it, 2026-11-10)
  only when `model.isDirty`, closing silently otherwise; interactive dismissal is refused while a submit is in
  flight *or* the draft is dirty, so a dirty draft is never swiped away silently and a write's outcome is never
  unknown (`CreationWizardView.body`); Cancel is disabled while submitting.
- Lifecycle: `.task(id: model.kind)` runs `model.prepare()` when a kind is entered; `.onChange(of: model.draft)`
  reports edits to `model.noteDraftChanged()`; the view dismisses itself when `model.isDone` turns true. The flow's
  close is booked by the presenter after the real dismissal (`model.noteClosed()` in Events'
  `clearWizardAfterDismiss`), never on disappear, which a width-class re-host also fires. The error popup is
  mounted here (`.errorPopup`), the one mount of this presentation.
- The scaffold's scroll reader brings `scrollTarget` (the page's focused field) into view, animated only when
  `\.motion` allows movement; the bottom bar sits on an opaque `.bar` background over a `Color.lilySurface` underlay
  (the aurora's brightest patch otherwise bleeds through the material; design-judge round, 2026-11-10) so the
  keyboard never overlaps bare content.
- Every added motion reads `\.motion`, never raw reduce-motion: the progress fill and the entrance slide are
  movement and settle instantly under reduced motion (the entrance fade stays — a fade in place is allowed either
  way); the auto-advancing pages (kind, type) push with the stack's own transition.

## Side Effects

- None beyond presentation: the views call the model's actions and mount the shared popup; no storage, network or
  logging of their own (the model logs).

## Verification

- Run: `./scripts/ci.sh build` (zero `/lily/` warnings) and `./scripts/ci.sh unit` (the model behind every control:
  `lilyTests/Create/CreationWizardModelTests.swift`). The wizard is reached through Explore's "+" event item and
  the ⌘N intent (slice 2's bridge); the rendered walk and screenshot pass run against that wiring, per the plan's
  verification section, and the smoke walk (`LilySmokeTests.testCreatingAGameShowsItOnHome`) pins the map push and
  back-preserves-state on a simulator.
