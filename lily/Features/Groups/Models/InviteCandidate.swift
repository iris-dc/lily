import Foundation

/// The backend's `InviteCandidate` (inbox plan, section 2.2): someone the caller shares a group or a game with, who may
/// be invited into the target group. `via`/`viaName` name the first shared group or game that made them a candidate.
nonisolated struct InviteCandidate: Identifiable, Hashable, Codable, Sendable {
    let userId: String
    let displayName: String
    let via: InviteCandidateSource
    /// The shared group's name or the shared game's title.
    let viaName: String
    /// A pending invite into the target group exists; the row offers no second one.
    private(set) var isInvited: Bool

    init(userId: String, displayName: String, via: InviteCandidateSource, viaName: String, isInvited: Bool = false) {
        self.userId = userId
        self.displayName = displayName
        self.via = via
        self.viaName = viaName
        self.isInvited = isInvited
    }

    var id: String { userId }

    /// The line under the name: "In Kreuzberg Kickers" or "Played Sunset 5-a-side"; a source this build does not know
    /// shows the shared thing's name alone.
    var caption: String {
        switch via {
        case .group: AppBranding.Groups.Invite.viaGroup(viaName)
        case .event: AppBranding.Groups.Invite.viaEvent(viaName)
        case .unknown: viaName
        }
    }

    /// The same candidate once an invite went out.
    func markingInvited() -> InviteCandidate {
        var copy = self
        copy.isInvited = true
        return copy
    }
}

/// What the caller shares with a candidate. A source a newer backend adds (a tournament roster, a conversation) keeps
/// its name, so one such candidate no longer fails the whole invite sheet.
nonisolated enum InviteCandidateSource: WireNamedKind {
    case group
    case event
    case unknown(String)

    static let known: [InviteCandidateSource] = [.group, .event]

    private static let groupName = "group"
    private static let eventName = "event"

    var wireName: String {
        switch self {
        case .group: Self.groupName
        case .event: Self.eventName
        case .unknown(let name): name
        }
    }
}
