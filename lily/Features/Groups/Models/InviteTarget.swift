import Foundation

/// What the invite-people sheet invites into: a group, or a tournament (whose room shares its id, so the repository
/// routes are keyed the same way). Named in log lines by kind and id only.
nonisolated enum InviteTarget: Hashable, Sendable {
    case group(id: String)
    case tournament(id: String)

    var id: String {
        switch self {
        case .group(let id), .tournament(let id): id
        }
    }

    /// "group g1" or "tournament t1", for log lines.
    var logName: String {
        switch self {
        case .group(let id): "group \(id)"
        case .tournament(let id): "tournament \(id)"
        }
    }
}
