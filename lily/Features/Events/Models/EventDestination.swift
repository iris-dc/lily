import Foundation

/// An event named by id and title alone, for openers that hold no `SportEvent` (an event room's info button and row);
/// `EventLoaderView` fetches the event behind it. The tournament's `TournamentDestination` pattern. `context` is
/// `.fromChat` when the event's room is one Back away, where "Open chat" would only push the same chat again.
nonisolated struct EventDestination: Hashable, Sendable {
    let id: String
    let name: String
    let context: GroupDetailContext

    init(id: String, name: String, context: GroupDetailContext = .standalone) {
        self.id = id
        self.name = name
        self.context = context
    }
}
