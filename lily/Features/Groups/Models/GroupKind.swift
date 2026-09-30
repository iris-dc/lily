import Foundation

/// What a `Group` on the wire is: a community, or the direct conversation between two people, which the backend keeps
/// as a group of two so history, read markers, unread and the realtime rooms need nothing of their own. Older payloads
/// carry no `kind`; `SportGroup` reads those as `group`.
nonisolated enum GroupKind: String, Codable, Sendable {
    case group, direct
}
