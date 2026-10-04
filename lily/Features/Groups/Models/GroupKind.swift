import Foundation

/// What a `Group` on the wire is: a community, the direct conversation between two people, or a tournament's room,
/// which the backend keeps as groups too so history, read markers, unread and the realtime rooms need nothing of their
/// own. Older payloads carry no `kind`; `SportGroup` reads those as `group`. A kind this build does not know keeps its
/// name: the room is still listed on Chats and offers chat and the roster only, no group actions, since its rules are
/// the backend's and not this build's to guess.
nonisolated enum GroupKind: WireNamedKind {
    case group
    case direct
    /// A tournament's room: named after it, entered and left through its entries, under the tournament's id.
    case tournament
    case unknown(String)

    private static let groupName = "group"
    private static let directName = "direct"
    private static let tournamentName = "tournament"

    init(wireName: String) {
        switch wireName {
        case Self.groupName: self = .group
        case Self.directName: self = .direct
        case Self.tournamentName: self = .tournament
        default: self = .unknown(wireName)
        }
    }

    var wireName: String {
        switch self {
        case .group: Self.groupName
        case .direct: Self.directName
        case .tournament: Self.tournamentName
        case .unknown(let name): name
        }
    }

    var isUnknown: Bool {
        if case .unknown = self { return true }
        return false
    }
}
