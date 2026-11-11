import Foundation

/// One entry on the wizard's navigation path: a step page the Next button pushes, or the map picker a place step
/// pushes. Steps nest per kind so each kind's pages slot in as a sibling case with its own step enum.
nonisolated enum CreationStep: Hashable, Sendable {
    case event(EventStep)
    case group(GroupStep)
    case tournament(TournamentStep)
    /// The map picker a kind's place step pushes: path elements because the wizard's stack is bound to the typed
    /// `[CreationStep]` path, which disables a link carrying any other value, and a stack rebuilt from the path on a
    /// re-host keeps the picker. One case per kind, so the shell knows whose draft takes the spot. Never in
    /// `steps(for:opening:)`, so the step walk, the progress mark and `pop(to:)` ignore them.
    case eventMap
    case groupMap
    case tournamentMap

    /// The event flow's pages, one idea each; `allCases` is the order walked,
    /// with `group` present only when the attempt may choose one (`CreationSteps.eventSteps(opening:)`).
    enum EventStep: CaseIterable, Hashable, Sendable {
        case name
        case type
        case when
        case group
        case place
        case players
        case details
    }

    /// The group flow's pages, one idea each. Visibility deliberately precedes Place (a recorded supersession,
    /// 2026-11-11): the public-group place requirement is known before the Place page, whose issues stay conditional
    /// on the choice.
    enum GroupStep: CaseIterable, Hashable, Sendable {
        case name
        case description
        case type
        case visibility
        case place
        case permissions
    }

    /// The tournament flow's pages, one idea each; `group` is on the walk only when the attempt may choose a hosting
    /// group, exactly like the event flow's (`CreationSteps.tournamentSteps(opening:)`).
    enum TournamentStep: CaseIterable, Hashable, Sendable {
        case name
        case type
        case format
        case schedule
        case group
        case place
        case entries
        case whoMayJoin
        case details
    }
}

/// The wizard's step lists and gating rules: which pages a kind walks for an opening, which page owns each validation
/// issue, and when Next may move forward. The per-kind issue partitions live in extension files
/// (`CreationSteps+Event.swift`, `CreationSteps+Group.swift`, `CreationSteps+Tournament.swift`).
nonisolated enum CreationSteps {
    /// The ordered pages of a kind's flow under the opening (flags, seed, eligible groups), deterministic per attempt.
    static func steps(for kind: CreationKind, opening: CreationWizardPolicy.Opening) -> [CreationStep] {
        switch kind {
        case .event: eventSteps(opening: opening).map(CreationStep.event)
        case .group: groupSteps().map(CreationStep.group)
        case .tournament: tournamentSteps(opening: opening).map(CreationStep.tournament)
        }
    }

    /// Whether this attempt may choose a hosting group — the groups flag is on, the seed locked nothing and the
    /// caller had a group to host in — all read once at the opening, so the step list is deterministic per attempt
    /// and the walk cannot change under a late groups reload. Shared by the event and tournament walks.
    static func offersGroupChoice(_ opening: CreationWizardPolicy.Opening) -> Bool {
        opening.flags.groups && opening.seed.lockedGroup == nil && opening.hasEligibleGroups
    }
}
