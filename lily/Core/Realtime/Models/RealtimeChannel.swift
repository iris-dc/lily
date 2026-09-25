import Foundation

/// A channel of the realtime API: a room at one epoch (`rooms/<groupId>/<epoch>`; every leave, removal and ban bumps
/// the epoch, so a stale subscription is refused rather than left dead), or the caller's own (`users/<sub>`).
nonisolated enum RealtimeChannel: Hashable, Sendable {
    case room(groupID: String, epoch: Int)
    case user(sub: String)

    var path: String {
        switch self {
        case .room(let groupID, let epoch): "\(AppConfig.Realtime.roomsNamespace)/\(groupID)/\(epoch)"
        case .user(let sub): "\(AppConfig.Realtime.usersNamespace)/\(sub)"
        }
    }

    var groupID: String? {
        if case .room(let groupID, _) = self { return groupID }
        return nil
    }
}
