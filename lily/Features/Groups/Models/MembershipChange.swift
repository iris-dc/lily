import Foundation

/// The `membership_changed` event on the caller's own channel: what happened to their row in a group. A ban arrives
/// as `removed`, like a plain removal. A kind this build does not know keeps its name and ends nothing: Mine is
/// refetched and the room stays, the backend never reads the kind back.
nonisolated struct MembershipChange: Hashable, Codable, Sendable {
    nonisolated enum Kind: WireNamedKind {
        case joined, left, removed, roleChanged
        case unknown(String)

        static let known: [Kind] = [.joined, .left, .removed, .roleChanged]

        private static let joinedName = "joined"
        private static let leftName = "left"
        private static let removedName = "removed"
        private static let roleChangedName = "role_changed"

        var wireName: String {
            switch self {
            case .joined: Self.joinedName
            case .left: Self.leftName
            case .removed: Self.removedName
            case .roleChanged: Self.roleChangedName
            case .unknown(let name): name
            }
        }
    }

    let groupId: String
    let change: Kind
    let role: MemberRole?
    let channelEpoch: Int

    /// The caller no longer belongs to the group, whichever way it happened.
    var endsMembership: Bool { change == .left || change == .removed }
}
