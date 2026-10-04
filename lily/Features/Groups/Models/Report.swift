import Foundation

nonisolated enum ReportReason: String, CaseIterable, Codable, Sendable {
    case spam, harassment, inappropriate, other

    var displayName: String {
        switch self {
        case .spam: AppBranding.Moderation.reasonSpam
        case .harassment: AppBranding.Moderation.reasonHarassment
        case .inappropriate: AppBranding.Moderation.reasonInappropriate
        case .other: AppBranding.Moderation.reasonOther
        }
    }
}

/// What a report is about. A message's, a group's or a tournament's report carries the room so the backend can check
/// the reporter may see the target; a tournament's room is the tournament's own id.
nonisolated struct ReportTarget: Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case message, group, user, tournament
    }

    let kind: Kind
    let id: String
    let groupID: String?

    static func message(id: String, groupID: String) -> ReportTarget {
        ReportTarget(kind: .message, id: id, groupID: groupID)
    }

    static func group(id: String) -> ReportTarget {
        ReportTarget(kind: .group, id: id, groupID: id)
    }

    static func tournament(id: String) -> ReportTarget {
        ReportTarget(kind: .tournament, id: id, groupID: id)
    }

    static func user(id: String) -> ReportTarget {
        ReportTarget(kind: .user, id: id, groupID: nil)
    }
}

/// Body of `POST /api/reports`. A blank comment is omitted.
nonisolated struct ReportPayload: Encodable, Equatable, Sendable {
    let targetType: ReportTarget.Kind
    let targetId: String
    let groupId: String?
    let reason: ReportReason
    let comment: String?

    init(target: ReportTarget, reason: ReportReason, comment: String? = nil) {
        targetType = target.kind
        targetId = target.id
        groupId = target.groupID
        self.reason = reason
        let trimmed = comment?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.comment = trimmed.isEmpty ? nil : trimmed
    }
}

/// Answer of `POST /api/reports`: the filed report's handle. A repeat on the same target answers the same one.
nonisolated struct ReportReceipt: Hashable, Codable, Sendable {
    let id: String
    let createdAt: Date
}

/// Answer of the block routes: the caller's whole block list after the change.
nonisolated struct BlockedUsers: Hashable, Codable, Sendable {
    let blockedUserIds: [String]
}
