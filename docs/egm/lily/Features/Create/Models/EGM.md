# Create Models

Source: `lily/Features/Create/Models/`

## Overview

The decision types of the creation wizard, all `nonisolated`, `Sendable` and pure: no storage, no network, no clock
and no auth input. `CreationKind` is the kind picked on the wizard's first page or carried in by an entry point;
`CreationSeed` is what an entry point hands the wizard (a kind, and the hosting group a group screen locks);
`CreationWizardPolicy` is the flags-by-context matrix deciding which kinds are offered, whether the kind page shows
and what the normalized seed is; `CreationStep` and `CreationSteps` carry the per-kind ordered page lists, the
exhaustive issue-to-step partition and the Next-gating predicate. The group and tournament flows have no pages yet
(they land with the plan's later slices); `steps(for:)` answers an empty list for them and such a kind must not be
routed into the wizard. Guest handling is not here: `CreateIntentPolicy` (Events) alone substitutes sign-in, so this
policy only ever decides for a signed-in user.

## Interface

- `CreationKind` (`lily/Features/Create/Models/CreationKind.swift`): `CaseIterable, Hashable, Sendable`; cases
  `event`, `group`, `tournament` — declaration order is the kind page's order; `init(_ intent: CreateIntent)`
  (`.game` → `.event`, `.group` → `.group`, `.tournament` → `.tournament`).
- `CreationSeed` (`lily/Features/Create/Models/CreationWizardPolicy.swift`): `Hashable, Sendable`;
  `kind: CreationKind?` (`nil` lets the kind page ask), `lockedGroup: EventGroupRef?`;
  `init(kind: = nil, lockedGroup: = nil)`; `static let empty`.
- `CreationWizardPolicy` (`CreationWizardPolicy.swift`): caseless enum. Nested `Flags` (`groups`, `tournaments`;
  `static let current` reads `AppConfig.FeatureFlags`) and `Opening` (`kindsOffered: [CreationKind]`,
  `showsKindPage: Bool`, `seed: CreationSeed`). `static func kindsOffered(flags:) -> [CreationKind]`,
  `static func opening(for seed: CreationSeed, flags: Flags) -> Opening`.
- `CreationStep` (`lily/Features/Create/Models/CreationSteps.swift`): `Hashable, Sendable`; `case event(EventStep)`
  with nested `EventStep: CaseIterable, Hashable, Sendable` (`basics`, `place`, `players`); kinds nest so the group
  and tournament flows slot in as sibling cases with step enums of their own. `case eventMap` is the place step's
  map picker as a path element — the wizard's stack is bound to the typed `[CreationStep]` path, which disables a
  link carrying a foreign value — and is never in `steps(for:)`.
- `CreationSteps` (`CreationSteps.swift`, partition and gating in `CreationSteps+Event.swift`):
  `static func steps(for kind: CreationKind) -> [CreationStep]`;
  `static func eventStep(owning issue: EventDraft.Issue) -> CreationStep.EventStep`;
  `static func allowsNext(from step: CreationStep.EventStep, issues: [EventDraft.Issue]) -> Bool`.

## Invariants

- `kindsOffered(flags:)`: `event` always; `group` iff `flags.groups`; `tournament` iff `flags.tournaments`; order is
  fixed (`event`, `group`, `tournament`); never empty.
- `opening(for:flags:)` normalizes the seed: a seeded kind the flags do not offer is dropped; a seed without a kind
  takes the only offered kind when exactly one is offered; `lockedGroup` passes through untouched. `showsKindPage`
  iff the normalized seed carries no kind and more than one kind is offered, so a flow without a kind page always
  knows its kind and a shortcut's seeded kind always skips the page.
- The matrix's cells (the plan's table): both flags on → kind page over all three kinds; groups only → event and
  group; tournaments only → event and tournament; both off (Release) → the event flow directly, no kind page. A
  seeded kind opens its flow directly under any flags that offer it; a locked group never changes the page decision.
- Issue partition (`eventStep(owning:)`, exhaustive — a new `EventDraft.Issue` case fails compilation until placed):
  `basics` owns `titleMissing`, `titleTooLong`, `startsAtTooSoon`; `place` owns `placeMissing`,
  `locationNameTooLong`; `players` owns `capacityOutOfRange`, `capacityBelowParticipants`, `descriptionTooLong`,
  `lookingForTooLong`, `priceUnreadable`, `priceOutOfRange`.
- `allowsNext(from:issues:)` is true exactly when the step owns none of `issues` (the step's issue set and the live
  issues do not intersect). The partition is total, so every step allowing Next is equivalent to `issues.isEmpty` —
  the whole-draft rule the final page's create button keeps (`EventDraft.issues(now:rules:).isEmpty`).
- `steps(for:)`: `.event` → `[.event(.basics), .event(.place), .event(.players)]` (`EventStep.allCases` order);
  `.group` and `.tournament` → `[]` while their pages are not in the tree; `eventMap` is never in a step list.
- `EventDraft.Issue` is `CaseIterable` (added for the partition's exhaustiveness test, 2026-11-10); `allCases` keeps
  the enum's form order (see [`../../Events/Models/EGM.md`](../../Events/Models/EGM.md)).

## Side Effects

- None: pure values and functions. `Flags.current` reads the compile-time `AppConfig.FeatureFlags` constants
  (`CreationWizardPolicy.swift`); nothing here touches the clock, locale, storage or network.

## Verification

- Run: `./scripts/ci.sh unit` from the repository root (`lilyTests/Create/CreationWizardPolicyTests.swift` — every
  cell of the flags-by-context matrix, the normalization rules and the `CreateIntent` mapping;
  `lilyTests/Create/CreationStepsTests.swift` — every `EventDraft.Issue` case owned by exactly the planned step, the
  gating predicate, and the final-gate equivalence with the whole-draft rule).
