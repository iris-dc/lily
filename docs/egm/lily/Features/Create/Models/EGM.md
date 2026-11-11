# Create Models

Source: `lily/Features/Create/Models/`

## Overview

The decision types of the creation wizard, all `nonisolated`, `Sendable` and pure: no storage, no network, no clock
and no auth input. `CreationKind` is the kind picked on the wizard's first page or carried in by an entry point;
`CreationSeed` is what an entry point hands the wizard (a kind, and the hosting group a group screen locks);
`CreationWizardPolicy` is the flags-by-context matrix deciding which kinds are offered, whether the kind page shows
and what the normalized seed is — its `Opening` carries the flags and the caller's eligible-groups fact, so the
step lists derive from the same context. `CreationStep` and `CreationSteps` carry the per-kind ordered page lists
(one idea per page since the owner's second design round, 2026-11-10; the group and tournament flows since slice 3,
2026-11-11), the exhaustive issue-to-step partitions and the Next-gating predicates; `CreationIssue` wraps one
kind's issue for the seams that serve every kind (the hint copy, the refused-Next log line). Guest handling is not
here: `CreateIntentPolicy` (Events) alone substitutes sign-in, so this policy only ever decides for a signed-in user.

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
  `CreationSteps` derives the walks from the same context — and `hasEligibleGroups: Bool`, whether the caller had a
  group to host in when the wizard opened, read once from the groups store by the composition root).
  `static func kindsOffered(flags:) -> [CreationKind]`,
  `static func opening(for seed: CreationSeed, flags: Flags, hasEligibleGroups: Bool) -> Opening`.
- `CreationStep` (`lily/Features/Create/Models/CreationSteps.swift`): `Hashable, Sendable`; `case event(EventStep)`,
  `case group(GroupStep)`, `case tournament(TournamentStep)` with nested `CaseIterable, Hashable, Sendable` step
  enums — `EventStep` (`name`, `type`, `when`, `group`, `place`, `players`, `details`), `GroupStep` (`name`,
  `description`, `type`, `visibility`, `place`, `permissions` — Visibility deliberately precedes Place, a recorded
  supersession, 2026-11-11) and `TournamentStep` (`name`, `type`, `format`, `schedule`, `group`, `place`, `entries`,
  `whoMayJoin`, `details`). `case eventMap`/`groupMap`/`tournamentMap` are the place steps' map picker as path
  elements — the wizard's stack is bound to the typed `[CreationStep]` path, which disables a link carrying a
  foreign value; one case per kind, so the shell knows whose draft takes the spot — and are never in
  `steps(for:opening:)`.
- `CreationSteps` (`CreationSteps.swift`; the per-kind walks, partitions and gating in `CreationSteps+Event.swift`,
  `+Group.swift`, `+Tournament.swift`):
  `static func steps(for kind: CreationKind, opening: CreationWizardPolicy.Opening) -> [CreationStep]`;
  `static func offersGroupChoice(_ opening:) -> Bool` (shared by the event and tournament walks);
  `static func eventSteps(opening:)`, `groupSteps()`, `tournamentSteps(opening:)`;
  `static func eventStep(owning: EventDraft.Issue)`, `groupStep(owning: GroupDraft.Issue)`,
  `tournamentStep(owning: TournamentDraft.Issue)`; and per kind
  `static func allowsNext(from:issues:) -> Bool`.
- `CreationIssue` (`lily/Features/Create/Models/CreationIssue.swift`): `Hashable, Sendable`;
  `case event(EventDraft.Issue)`, `group(GroupDraft.Issue)`, `tournament(TournamentDraft.Issue)`; `logName: String`
  (the wrapped case's kind-prefixed name for the refused-Next debug line, "group.nameTooShort" since
  2026-11-11 — issue ids only, never user text).

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
- `offersGroupChoice(_:)` is true exactly when `opening.flags.groups`, `opening.seed.lockedGroup == nil` and
  `opening.hasEligibleGroups` (the plan's "skipped when locked, groups off, or none"): the step lists are functions
  of the opening alone, deterministic per attempt, so the async eligible-groups reload can never change a walk.
- Walks: `eventSteps(opening:)` is `EventStep.allCases` with `group` present iff `offersGroupChoice`;
  `groupSteps()` is `GroupStep.allCases` (no conditional page; Visibility before Place, so the public-place rule is
  known before the Place page, whose issues stay conditional on the choice); `tournamentSteps(opening:)` is
  `TournamentStep.allCases` with `group` present iff `offersGroupChoice`.
- Issue partitions (exhaustive switches — a new issue case fails compilation until placed). Event: `name` owns
  `titleMissing`, `titleTooLong`; `when` owns `startsAtTooSoon`; `place` owns `placeMissing`, `locationNameTooLong`;
  `players` owns `capacityOutOfRange`, `capacityBelowParticipants`; `details` owns `descriptionTooLong`,
  `lookingForTooLong`, `priceUnreadable`, `priceOutOfRange`; `type` and `group` own none. Group: `name` owns
  `nameTooShort`, `nameTooLong`; `description` owns `descriptionTooLong`; `place` owns `locationNameMissing`,
  `locationNameTooLong`, `coordinateMissing` (conditional on the visibility choice exactly as `GroupDraft.issues`
  computes them); `type`, `visibility` and `permissions` own none. Tournament: `name` owns `nameTooShort`,
  `nameTooLong`; `schedule` owns `startsAtTooSoon`, `registrationClosesAfterStart`; `place` owns
  `locationNameMissing`, `locationNameTooLong`, `coordinateMissing`; `entries` owns `teamSizeOutOfRange`,
  `maxEntriesOutOfRange`, `maxEntriesBelowEntries`; `details` owns `descriptionTooLong`; `type`, `format`, `group`
  and `whoMayJoin` own none — the choice pages have nothing to refuse.
- `allowsNext(from:issues:)` (per kind) is true exactly when the step owns none of `issues`. Each partition is
  total, so every step allowing Next is equivalent to the kind's `issues.isEmpty` — the whole-draft rule the final
  page's create button keeps.
- The map cases are never in a step list, so the step walk, the progress mark and `pop(to:)` ignore them.
- `EventDraft.Issue`, `GroupDraft.Issue` and `TournamentDraft.Issue` are `CaseIterable` (the partition exhaustiveness
  tests iterate them); `allCases` keeps each enum's form order.

## Side Effects

- None: pure values and functions. `Flags.current` reads the compile-time `AppConfig.FeatureFlags` constants
  (`CreationWizardPolicy.swift`); nothing here touches the clock, locale, storage or network.

## Verification

- Run: `./scripts/ci.sh unit` from the repository root (`lilyTests/Create/CreationWizardPolicyTests.swift` — every
  cell of the flags-by-context matrix, the normalization rules and the `CreateIntent` mapping;
  `lilyTests/Create/CreationStepsTests.swift`, `CreationStepsGroupTests.swift`,
  `CreationStepsTournamentTests.swift` — the one-idea walks, the hosting-group pages present and absent across
  flags, locked seeds and the eligible-groups fact, every issue case owned by exactly the planned step, the choice
  pages owning none, the gating predicates, the group place gate following the visibility choice, and the
  final-gate equivalence with the whole-draft rule).
