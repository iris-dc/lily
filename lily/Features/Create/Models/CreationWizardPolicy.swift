import Foundation

/// What an entry point hands the creation wizard: nothing from Explore's "+", a kind from a keyboard shortcut, a kind
/// plus the hosting group from a group screen's create buttons. Auth never rides here: `CreateIntentPolicy` alone
/// substitutes sign-in for a guest, so the wizard is only ever asked to open for a signed-in user.
nonisolated struct CreationSeed: Hashable, Sendable {
    /// The kind the entry point fixed; `nil` lets the kind page ask.
    var kind: CreationKind?
    /// The group a game or tournament is created inside, locked on the hosting row; the policy passes it through.
    var lockedGroup: EventGroupRef?

    init(kind: CreationKind? = nil, lockedGroup: EventGroupRef? = nil) {
        self.kind = kind
        self.lockedGroup = lockedGroup
    }

    static let empty = CreationSeed()
}

/// The rules behind the wizard's opening: which kinds the feature flags offer, whether the kind page shows, and the
/// seed the flow starts from. A pure function of flags, entry context and the caller's groups as read at opening, so
/// the degrade matrix is tested as a function, not as view logic; sign-in state never enters it (`CreateIntentPolicy`
/// owns everything auth-aware).
nonisolated enum CreationWizardPolicy {
    /// The flags the matrix switches on, a value so every cell is testable; `current` reads the build's flags.
    struct Flags: Hashable, Sendable {
        let groups: Bool
        let tournaments: Bool

        static let current = Flags(groups: AppConfig.FeatureFlags.groups,
                                   tournaments: AppConfig.FeatureFlags.tournaments)
    }

    /// What the wizard opens on for a seed under a set of flags.
    struct Opening: Hashable, Sendable {
        /// The kinds the flags leave, in the kind page's order; never empty, events always ship.
        let kindsOffered: [CreationKind]
        /// The kind page is worth showing only for a real choice the seed has not already made.
        let showsKindPage: Bool
        /// The seed, normalized: a kind the flags do not offer is dropped, and the only offered kind is filled in
        /// when the seed carries none, so a flow without a kind page always knows its kind.
        let seed: CreationSeed
        /// The flags the opening was decided under, carried so the step lists derive from the same context — the
        /// event flow's hosting-group page follows the groups flag (`CreationSteps.eventSteps(opening:)`).
        let flags: Flags
        /// Whether the caller had a group to host in when the wizard opened, read once from the groups store by the
        /// composition root: the hosting-group page is skipped when locked, groups off, or none, and the walk never
        /// moves under the async groups reload.
        let hasEligibleGroups: Bool
    }

    static func kindsOffered(flags: Flags) -> [CreationKind] {
        CreationKind.allCases.filter { kind in
            switch kind {
            case .event: true
            case .group: flags.groups
            case .tournament: flags.tournaments
            }
        }
    }

    static func opening(for seed: CreationSeed, flags: Flags, hasEligibleGroups: Bool) -> Opening {
        let offered = kindsOffered(flags: flags)
        var normalized = seed
        if let kind = normalized.kind, !offered.contains(kind) { normalized.kind = nil }
        if normalized.kind == nil, offered.count == 1 { normalized.kind = offered.first }
        return Opening(kindsOffered: offered,
                       showsKindPage: normalized.kind == nil && offered.count > 1,
                       seed: normalized,
                       flags: flags,
                       hasEligibleGroups: hasEligibleGroups)
    }
}
