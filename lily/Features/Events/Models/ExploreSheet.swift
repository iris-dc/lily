import Foundation

/// The sheets Explore presents: the creation wizard for a new game, the group and tournament forms (their flows walk
/// the wizard in slice 3 of the creation-wizard plan), and sign-in for a guest who asked to create. The screen holds
/// one of these as its presented sheet; a keyboard shortcut's `CreateIntent` maps onto it.
nonisolated enum ExploreSheet: Identifiable, Hashable, Sendable {
    /// The creation wizard, carrying what the entry point seeds it with (the "+" menu's event item fixes the kind).
    case wizard(CreationSeed)
    case createGroup
    case createTournament
    case signIn

    /// Explicit now that a case carries a payload: one wizard presentation at a time, whatever its seed.
    var id: String {
        switch self {
        case .wizard: "wizard"
        case .createGroup: "createGroup"
        case .createTournament: "createTournament"
        case .signIn: "signIn"
        }
    }

    /// The sheet a keyboard shortcut's intent asks for; the game walks the wizard, the rest their forms until slice 3.
    init(_ intent: CreateIntent) {
        switch intent {
        case .game: self = .wizard(CreationSeed(kind: .event))
        case .group: self = .createGroup
        case .tournament: self = .createTournament
        }
    }
}
