# Create State

Source: `lily/Features/Create/State/`

## Overview

The wizard shell's observable state, one type: `CreationWizardModel` owns the opening the policy decided, the kind
fixed at init by the normalized seed, the view model of that kind (made at init), the navigation path of entered steps, the
user-edit flag behind the discard confirmation and the submit lock the chrome reads. It is generic over the three
kind view-model types (`EventModel: EventDraftEditing`, `GroupModel: GroupDraftEditing`,
`TournamentModel: TournamentDraftEditing`), so the shell stays statically typed and only the composition root
(`lily/App/AppDependencies+Create.swift`, whose `AppCreationWizardModel` typealias call sites hold) names concrete
types; the pages read it through `CreationWizardControlling`
([`../Interfaces/EGM.md`](../Interfaces/EGM.md)), which `CreationWizardModel+Gating.swift` conforms to.
`CreationWizardFactories` carries the injected factory closures, one per kind. The draft's judging stays with the
kind's view model; this type only routes its issues through `CreationSteps` and logs the flow's key events.

## Interface

- `CreationWizardFactories<EventModel, GroupModel, TournamentModel>`
  (`lily/Features/Create/State/CreationWizardModel.swift:CreationWizardFactories`):
  `event: (EventGroupRef?) -> EventModel`, `group: () -> GroupModel`,
  `tournament: (EventGroupRef?) -> TournamentModel` — the seed's locked hosting group passes through to the kinds
  that host in one.
- `CreationDraft` (same file): `nonisolated enum, Equatable, Sendable`; `none`, `event(EventDraft)`,
  `group(GroupDraft)`, `tournament(TournamentDraft)` — the draft on screen as one value, so the shell watches every
  flow's edits through one `onChange` and the dirty rule has one yardstick shape.
- `CreationWizardModel<EventModel, GroupModel, TournamentModel>` (same file; the gating seams in
  `CreationWizardModel+Gating.swift`): `@Observable final class`;
  `init(opening: CreationWizardPolicy.Opening, factories: CreationWizardFactories<...>, logger: any Logging)`.
  State: `opening`, `kind: CreationKind` (a `let`, fixed at init, 2026-11-11), `private(set) eventModel/groupModel/tournamentModel`
  (the entered kind's alone is non-nil), `path: [CreationStep]` (the entries pushed beyond the stack's root),
  `private(set) isDirty: Bool`.
  Derived: `steps: [CreationStep]` (through `CreationSteps.steps(for:opening:)`, so each walk — including whether
  the hosting-group pages exist — is fixed by the opening's flags, seed and eligible-groups fact, deterministic per
  attempt), `draft: CreationDraft`, `active: (any DraftSubmitting)?` (the entered kind's view model behind the
  shared request-state seam), `isSubmitting`, `canSubmit`, `isDone`.
  Actions: `prepare() async`, `noteDraftChanged()`, `allowsNext(from:) -> Bool`,
  `firstBlockingIssue(on:) -> CreationIssue?`, `blockingMessage(on:) -> String?`,
  `blockedEarlierStep(before:) -> CreationStep?`, `advance(from:)`, `pop(to:)`, `submit() async`, `noteClosed()`.

## Invariants

- The kind pick is one-way by construction (2026-11-11, the round-3 review: `enter(_:)` folded into `init`, `kind`
  is a `let`), and only the entered kind's
  view model is ever made (exactly once, through the injected factory, passing `opening.seed.lockedGroup` to the
  event and tournament factories); `prepare()` forwards to the created model's `prepare()` once per attempt — a
  run whose task was cancelled mid-await re-arms (`hasPrepared` resets), so the next ask runs the kinds'
  idempotent prepares again (2026-11-11).
- The opening's seed always carries a kind (the policy normalizes a missing one to the event), fixed at `init`
  (the never-taken `.event` fallback is the optional seed's tax);
  the kind's first step is the stack root and never in `path`, and `pop(to:)` restores exactly that shape
  (`CreationWizardModel.pop(to:)`). (The kind-page root shape left with the third design round, 2026-11-11.)
- Dirty is the user's edit, latched by `noteDraftChanged()` and never unlatched: the draft is compared against the
  pristine draft the factory made, with `prepare()`'s own write excluded by shape — a coordinate the user neither
  picked on the map (`spotPickedOnMap`) nor took from a suggestion (`suggestedName`) is read as if unchanged — so an
  edit during prepare's await counts and the proposal alone never does. One generic rule serves every kind over the
  shared place bookkeeping (`CreationWizardModel.isUserEdit(_:since:)` over `PlacePickingDraft & Equatable`,
  [`../../Events/Models/EGM.md`](../../Events/Models/EGM.md)).
- Gating routes through `CreationSteps` per kind: `allowsNext(from:)` is the step-owns-no-live-issue rule,
  `firstBlockingIssue(on:)` the first owned issue in field order wrapped as `CreationIssue`,
  `blockingMessage(on:)` its copy through the kind's branding (`AppBranding.Events.Create.message(for:)`,
  `Groups.Create.message(for:)`, `Tournaments.Create.message(for:format:)` with the live draft's format),
  `blockedEarlierStep(before:)` the earliest earlier step still blocked (what the final page's hint names).
  `advance(from:)` refuses a blocked step (belt behind the disabled button), logs the blocking issue's `logName` at
  debug, and runs only from the entry on top of the path — a double-tapped Next pushes once, a tap gone stale
  across a pop neither pushes nor skips a step. The map cases gate nothing (`allowsNext` false, no issue).
- `submit()` drops a call while one is in flight and otherwise delegates to the active view model, where the
  idempotent create flow lives; `isDone` is the view model's. `noteClosed()` logs abandoned at most once and never
  after a create succeeded; the presenter calls it on the flow's real dismissal (Explore's and the group detail's
  `clearWizardAfterDismiss`), never on a width-class re-host.
- Logging is `.ui`, ids and kinds only, never user text: "Creation wizard begun for <kind>" (info, at init),
  "Creation wizard submitted <kind>" (info), "Creation wizard abandoned (kind: <kind>)" (info),
  "Creation wizard refused Next: <issue>" (debug).

## Side Effects

- None of its own beyond the injected logger: no storage, network or clock. The factory call builds the kind's view
  model (whose own side effects are its contract), and `prepare()`/`submit()` run that model's.

## Verification

- Run: `./scripts/ci.sh unit` (`lilyTests/Create/CreationWizardModelTests.swift` — the init-fixed kind, the
  opening-decided event walk, lazy factory invocation and the locked-group pass-through, prepare once per entry, the
  dirty rule including an edit during a held prepare, the gating walk with the refused-Next debug line, the
  top-of-the-path advance guard, `pop(to:)` in both root shapes, the stale-earlier-issue final gate, the submit lock
  over a held repository, dismissal signal on done, and the abandoned-once rule;
  `lilyTests/Create/CreationWizardModelKindsTests.swift` — the group walk and gating, the tournament walk under the
  opening, the group dirty rule and submit — both over `lilyTests/Support/CreationWizardHarness.swift`; log lines
  pinned by count plus fragment).
