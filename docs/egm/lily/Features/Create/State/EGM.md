# Create State

Source: `lily/Features/Create/State/`

## Overview

The wizard shell's observable state, one type: `CreationWizardModel` owns the opening the policy decided, the kind
entered once per attempt, the lazily created view model of that kind, the navigation path of entered steps, the
user-edit flag behind the discard confirmation and the submit lock the chrome reads. It is generic over the event
view-model type (`EventModel: EventDraftEditing`), so the shell and its pages stay statically typed and only the
composition root (`lily/App/AppDependencies+Create.swift`) names a concrete type; `CreationWizardFactories` carries
the injected factory closures (the event one alone until slice 3 adds the group and tournament flows). The draft's
judging stays with the kind's view model; this type only routes its issues through `CreationSteps` and logs the
flow's key events.

## Interface

- `CreationWizardFactories<EventModel: EventDraftEditing>`
  (`lily/Features/Create/State/CreationWizardModel.swift:CreationWizardFactories`):
  `event: (EventGroupRef?) -> EventModel` — the seed's locked hosting group passes through to the factory.
- `CreationWizardModel<EventModel: EventDraftEditing>` (same file): `@Observable final class`;
  `init(opening: CreationWizardPolicy.Opening, factories: CreationWizardFactories<EventModel>, logger: any Logging)`.
  State: `opening`, `private(set) kind: CreationKind?`, `private(set) eventModel: EventModel?`,
  `path: [CreationStep]` (the entries pushed beyond the stack's root: steps, and the place step's map picker),
  `private(set) isDirty: Bool`.
  Derived: `steps: [CreationStep]`, `draft: EventDraft?`, `isSubmitting`, `canSubmit`, `isDone`.
  Actions: `enter(_ kind:)`, `prepare() async`, `noteDraftChanged()`, `allowsNext(from:) -> Bool`,
  `firstBlockingIssue(on:) -> EventDraft.Issue?`, `blockedEarlierStep(before:) -> CreationStep?`,
  `advance(from:)`, `pop(to:)`, `submit() async`, `noteClosed()`.

## Invariants

- The kind pick is one-way: `enter(_:)` drops a second call whatever kind it names; a kind whose pages have not
  landed (`CreationSteps.steps(for:)` empty — group and tournament until slice 3) is refused *before* the kind is
  fixed, with a `.ui` warning, so the wizard is never stuck on a kind it cannot walk.
- A seeded kind enters at `init`; entering from the kind page appends the kind's first step to `path` (the kind page
  stays the root), while a flow whose opening skips the kind page keeps the first step as the root and never in
  `path`. `pop(to:)` restores exactly that shape (`CreationWizardModel.pop(to:)`).
- `enter` makes the kind's view model through the injected factory, exactly once, passing
  `opening.seed.lockedGroup`; `prepare()` forwards to the created model's `prepare()` once per attempt.
- Dirty is the user's edit, latched by `noteDraftChanged()` and never unlatched: the draft is compared against the
  pristine draft the factory made, with `prepare()`'s own write excluded by shape — a coordinate the user neither
  picked on the map (`spotPickedOnMap`) nor took from a suggestion (`suggestedName`) is read as if unchanged — so an
  edit during prepare's await counts and the proposal alone never does (`CreationWizardModel.isUserEdit(_:since:)`).
- Gating routes through `CreationSteps`: `allowsNext(from:)` is the step-owns-no-live-issue rule,
  `firstBlockingIssue(on:)` the first owned issue in field order, `blockedEarlierStep(before:)` the earliest earlier
  step still blocked (what the final page's hint names). `advance(from:)` refuses a blocked step (belt behind the
  disabled button) and logs the blocking issue at debug, and runs only from the entry on top of the path — a
  double-tapped Next pushes once, a tap gone stale across a pop neither pushes nor skips a step.
- `submit()` drops a call while one is in flight and otherwise delegates to the view model, where the idempotent
  create flow lives; `isDone` is the view model's. `noteClosed()` logs abandoned at most once and never after a
  create succeeded; the presenter calls it on the flow's real dismissal (Events' `clearWizardAfterDismiss`), never
  on a width-class re-host.
- Logging is `.ui`, ids and kinds only, never user text: "Creation wizard begun for <kind>" (info, on enter),
  "Creation wizard submitted <kind>" (info), "Creation wizard abandoned (kind: <kind|none>)" (info),
  "Creation wizard refused Next: <issue>" (debug), "Creation wizard has no pages for <kind> yet" (warning).

## Side Effects

- None of its own beyond the injected logger: no storage, network or clock. The factory call builds the kind's view
  model (whose own side effects are its contract), and `prepare()`/`submit()` run that model's.

## Verification

- Run: `./scripts/ci.sh unit` (`lilyTests/Create/CreationWizardModelTests.swift` — the one-way kind and the refused
  kind, lazy factory invocation and the locked-group pass-through, prepare once per entry, the dirty rule including
  an edit during a held prepare and the proposal-is-not-an-edit rule, the gating walk with the refused-Next debug
  line, the top-of-the-path advance guard, `pop(to:)` in both root shapes, the stale-earlier-issue final gate, the submit lock over a held repository,
  dismissal signal on done, and the abandoned-once rule — log lines pinned by count plus fragment).
