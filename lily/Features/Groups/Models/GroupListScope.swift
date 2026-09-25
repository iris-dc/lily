import Foundation

/// Which list the Groups tab shows: the caller's own groups, or the public ones to browse and search.
nonisolated enum GroupListScope: Hashable, Sendable {
    case mine
    case discover
}
