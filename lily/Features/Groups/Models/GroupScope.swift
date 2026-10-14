import Foundation

/// Which slice of groups a list shows: the caller's own, or the public ones anyone can browse and search.
nonisolated enum GroupScope: Hashable, Sendable {
    case mine
    /// `query` is a name prefix (name order); without one, or with a blank one, the page is a browse: nearest first
    /// around a position, newest first otherwise.
    case discover(query: String?, type: EventType?)

    /// The `scope` query value; the backend calls Discover's slice `public`.
    var wireName: String {
        switch self {
        case .mine: "mine"
        case .discover: "public"
        }
    }

    /// The name prefix a Discover search sends, as the backend reads it: trimmed, and `nil` for a missing or blank
    /// query, which is a browse. Mine searches nothing.
    var searchPrefix: String? {
        guard case .discover(let query?, _) = self else { return nil }
        return query.nonBlankTrimmed
    }
}
