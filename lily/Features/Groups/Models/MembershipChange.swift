import Foundation

/// The `membership_changed` event on the caller's own channel: what happened to their row in a group. A ban arrives
/// as `removed`, like a plain removal.
nonisolated struct MembershipChange: Hashable, Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        case joined, left, removed
        case roleChanged = "role_changed"
    }

    let groupId: String
    let change: Kind
    let role: MemberRole?
    let channelEpoch: Int

    /// The caller no longer belongs to the group, whichever way it happened.
    var endsMembership: Bool { change == .left || change == .removed }
}
