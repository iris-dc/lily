import Foundation

/// What an entry point hands the creation wizard: a kind from the "+" menu or a keyboard shortcut, a kind plus the
/// hosting group from a group screen's create buttons. Auth never rides here: `CreateIntentPolicy` alone
/// substitutes sign-in for a guest, so the wizard is only ever asked to open for a signed-in user.
nonisolated struct CreationSeed: Hashable, Sendable {
    /// The kind the entry point fixed; a seed without one normalizes to the event flow (the menu always names a kind).
    var kind: CreationKind?
    /// The group a game or tournament is created inside, locked on the hosting row; the policy passes it through.
    var lockedGroup: EventGroupRef?

    init(kind: CreationKind? = nil, lockedGroup: EventGroupRef? = nil) {
        self.kind = kind
        self.lockedGroup = lockedGroup
    }

    static let empty = CreationSeed()
}

/// The rules behind the wizard's opening: which kinds the feature flags offer (the "+" menu's items), and the seed
/// the flow starts from. A pure function of flags, entry context and the caller's groups as read at opening, so
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
        /// The kinds the flags leave, in the "+" menu's order; never empty, events always ship.
        let kindsOffered: [CreationKind]
        /// The seed, normalized: a kind the flags do not offer is dropped, and a seed without one takes the first
        /// offered kind (the event), so the wizard always knows its kind and opens on that kind's first step — the
        /// menu owns the choice (the kind page left with the owner's third design round, 2026-11-11).
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
        if normalized.kind == nil { normalized.kind = offered.first }
        return Opening(kindsOffered: offered,
                       seed: normalized,
                       flags: flags,
                       hasEligibleGroups: hasEligibleGroups)
    }
}
