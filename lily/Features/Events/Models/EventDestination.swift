import Foundation

/// An event named by id and title alone, for openers that hold no `SportEvent` (an event room's info button and row);
/// `EventLoaderView` fetches the event behind it. The tournament's `TournamentDestination` pattern.
nonisolated struct EventDestination: Hashable, Sendable {
    let id: String
    let name: String
}
