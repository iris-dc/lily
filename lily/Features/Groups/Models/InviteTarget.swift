import Foundation

/// What the invite-people sheet invites into: a group, a tournament or an event (whose rooms share their ids, so the
/// repository routes are keyed the same way). Named in log lines by kind and id only.
nonisolated enum InviteTarget: Hashable, Sendable {
    case group(id: String)
    case tournament(id: String)
    case event(id: String)

    var id: String {
        switch self {
        case .group(let id), .tournament(let id), .event(let id): id
        }
    }

    /// "group g1", "tournament t1" or "event e1", for log lines.
    var logName: String {
        switch self {
        case .group(let id): "group \(id)"
        case .tournament(let id): "tournament \(id)"
        case .event(let id): "event \(id)"
        }
    }

    /// Where those log lines go: each kind's own category.
    var logCategory: LogCategory {
        switch self {
        case .group: .groups
        case .tournament: .tournaments
        case .event: .events
        }
    }
}
