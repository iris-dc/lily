# Create Models

Source: `lily/Features/Create/Models/`

## Overview

The decision types of the creation wizard, all `nonisolated`, `Sendable` and pure: no storage, no network, no clock
and no auth input. `CreationKind` is the kind picked on the wizard's first page or carried in by an entry point;
`CreationSeed` is what an entry point hands the wizard (a kind, and the hosting group a group screen locks);
`CreationWizardPolicy` is the flags-by-context matrix deciding which kinds are offered, whether the kind page shows
and what the normalized seed is — its `Opening` carries the flags on and the caller's eligible-groups fact, so the
step lists derive from the same context;
`CreationStep` and `CreationSteps` carry the per-kind ordered page lists (one idea per page since the owner's second
design round, 2026-11-10; the event flow's hosting-group page is conditional on the opening), the exhaustive
issue-to-step partition and the Next-gating predicate. The group and tournament flows have no pages yet (they land
with the plan's later slices); `steps(for:opening:)` answers an empty list for them and such a kind must not be
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
  `showsKindPage: Bool`, `seed: CreationSeed`, `flags: Flags` — the flags the opening was decided under, carried so
  `CreationSteps` derives the walk from the same context — and `hasEligibleGroups: Bool`, whether the caller had a
  group to host in when the wizard opened, read once from the groups store by the composition root).
  `static func kindsOffered(flags:) -> [CreationKind]`,
  `static func opening(for seed: CreationSeed, flags: Flags, hasEligibleGroups: Bool) -> Opening`.
- `CreationStep` (`lily/Features/Create/Models/CreationSteps.swift`): `Hashable, Sendable`; `case event(EventStep)`
  with nested `EventStep: CaseIterable, Hashable, Sendable` (`name`, `type`, `when`, `group`, `place`, `players`,
  `details` — one idea each); kinds nest so the group and tournament flows slot in as sibling cases with step enums
  of their own. `case eventMap` is the place step's map picker as a path element — the wizard's stack is bound to
  the typed `[CreationStep]` path, which disables a link carrying a foreign value — and is never in
  `steps(for:opening:)`.
- `CreationSteps` (`CreationSteps.swift`, the event walk, partition and gating in `CreationSteps+Event.swift`):
  `static func steps(for kind: CreationKind, opening: CreationWizardPolicy.Opening) -> [CreationStep]`;
  `static func eventSteps(opening:) -> [CreationStep.EventStep]`;
  `static func eventStep(owning issue: EventDraft.Issue) -> CreationStep.EventStep`;
  `static func allowsNext(from step: CreationStep.EventStep, issues: [EventDraft.Issue]) -> Bool`.

## Invariants

- `kindsOffered(flags:)`: `event` always; `group` iff `flags.groups`; `tournament` iff `flags.tournaments`; order is
  fixed (`event`, `group`, `tournament`); never empty.
- `opening(for:flags:hasEligibleGroups:)` normalizes the seed: a seeded kind the flags do not offer is dropped; a
  seed without a kind takes the only offered kind when exactly one is offered; `lockedGroup`, `flags` and
  `hasEligibleGroups` pass through untouched.
  `showsKindPage` iff the normalized seed carries no kind and more than one kind is offered, so a flow without a
  kind page always knows its kind and a shortcut's seeded kind always skips the page.
- The matrix's cells (the plan's table): both flags on → kind page over all three kinds; groups only → event and
  group; tournaments only → event and tournament; both off (Release) → the event flow directly, no kind page. A
  seeded kind opens its flow directly under any flags that offer it; a locked group never changes the page decision.
- `eventSteps(opening:)` walks `EventStep.allCases` in order — name, type, when, group, place, players, details —
  with `group` present exactly when `opening.flags.groups` is on, `opening.seed.lockedGroup` is `nil` and
  `opening.hasEligibleGroups` (the plan's "skipped when locked, groups off, or none"): the step list is a function
  of the opening alone, deterministic per attempt, so the async eligible-groups reload can never change the walk
  (the owner's second design round, 2026-11-10).
- Issue partition (`eventStep(owning:)`, exhaustive — a new `EventDraft.Issue` case fails compilation until placed):
  `name` owns `titleMissing`, `titleTooLong`; `when` owns `startsAtTooSoon`; `place` owns `placeMissing`,
  `locationNameTooLong`; `players` owns `capacityOutOfRange`, `capacityBelowParticipants`; `details` owns
  `descriptionTooLong`, `lookingForTooLong`, `priceUnreadable`, `priceOutOfRange`. The `type` and `group` pages own
  none by design — a single choice and an optional one have nothing to refuse — and the exhaustive switch can never
  answer them.
- `allowsNext(from:issues:)` is true exactly when the step owns none of `issues` (the step's issue set and the live
  issues do not intersect). The partition is total, so every step allowing Next is equivalent to `issues.isEmpty` —
  the whole-draft rule the final page's create button keeps (`EventDraft.issues(now:rules:).isEmpty`).
- `steps(for:opening:)`: `.event` → `eventSteps(opening:)` mapped into `CreationStep.event`; `.group` and
  `.tournament` → `[]` while their pages are not in the tree; `eventMap` is never in a step list.
- `EventDraft.Issue` is `CaseIterable` (added for the partition's exhaustiveness test, 2026-11-10); `allCases` keeps
  the enum's form order (see [`../../Events/Models/EGM.md`](../../Events/Models/EGM.md)).

## Side Effects

- None: pure values and functions. `Flags.current` reads the compile-time `AppConfig.FeatureFlags` constants
  (`CreationWizardPolicy.swift`); nothing here touches the clock, locale, storage or network.

## Verification

- Run: `./scripts/ci.sh unit` from the repository root (`lilyTests/Create/CreationWizardPolicyTests.swift` — every
  cell of the flags-by-context matrix, the normalization rules and the `CreateIntent` mapping;
  `lilyTests/Create/CreationStepsTests.swift` — the one-idea walk, the hosting-group page present and absent across
  flags, locked seeds and the eligible-groups fact, every `EventDraft.Issue` case owned by exactly the planned step,
  the choice pages owning none, the gating predicate, and the final-gate equivalence with the whole-draft rule).
