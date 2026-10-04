import Foundation

/// What a `Group` on the wire is: a community, or the direct conversation between two people, which the backend keeps
/// as a group of two so history, read markers, unread and the realtime rooms need nothing of their own. Older payloads
/// carry no `kind`; `SportGroup` reads those as `group`. A kind this build does not know keeps its name: the room is
/// still listed on Chats and offers chat and the roster only, no group actions, since its rules are the backend's and
/// not this build's to guess.
nonisolated enum GroupKind: WireNamedKind {
    case group
    case direct
    case unknown(String)

    private static let groupName = "group"
    private static let directName = "direct"

    init(wireName: String) {
        switch wireName {
        case Self.groupName: self = .group
        case Self.directName: self = .direct
        default: self = .unknown(wireName)
        }
    }

    var wireName: String {
        switch self {
        case .group: Self.groupName
        case .direct: Self.directName
        case .unknown(let name): name
        }
    }

    var isUnknown: Bool {
        if case .unknown = self { return true }
        return false
    }
}
