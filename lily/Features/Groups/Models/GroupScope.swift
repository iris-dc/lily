import Foundation

/// Which slice of groups a list shows: the caller's own, or the public ones anyone can browse and search.
nonisolated enum GroupScope: Hashable, Sendable {
    case mine
    /// `query` is a name prefix (name order); without one the newest groups come first.
    case discover(query: String?, type: EventType?)
}
