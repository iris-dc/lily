import Foundation

/// Which groups list a screen shows: the caller's own groups, or the public ones to browse and search.
nonisolated enum GroupListScope: Hashable, Sendable {
    case mine
    case discover
}
