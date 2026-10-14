import Foundation

/// The sheets Explore presents: the three create forms for a signed-in user, and sign-in for a guest who asked to
/// create. The screen holds one of these as its presented sheet; a keyboard shortcut's `CreateIntent` maps onto it.
nonisolated enum ExploreSheet: String, Identifiable, Sendable {
    case createGame
    case createGroup
    case createTournament
    case signIn

    var id: String { rawValue }

    /// The sheet a keyboard shortcut's intent asks for.
    init(_ intent: CreateIntent) {
        switch intent {
        case .game: self = .createGame
        case .group: self = .createGroup
        case .tournament: self = .createTournament
        }
    }
}
