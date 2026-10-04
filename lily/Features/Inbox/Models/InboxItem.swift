import Foundation

/// Decodes the backend's `InboxItem` directly: same keys, same optionality. Ids are server ULIDs, so their string
/// order is their time order and the newest item is the last. Exactly one payload is present, the one `kind` names;
/// a kind this build does not know decodes with none and is hidden.
nonisolated struct InboxItem: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let kind: InboxItemKind
    let createdAt: Date
    let invite: InvitePayload?
    let reminder: ReminderPayload?
    let tournamentInvite: TournamentInvitePayload?
    let matchReminder: MatchReminderPayload?

    init(id: String,
         kind: InboxItemKind,
         createdAt: Date,
         invite: InvitePayload? = nil,
         reminder: ReminderPayload? = nil,
         tournamentInvite: TournamentInvitePayload? = nil,
         matchReminder: MatchReminderPayload? = nil) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.invite = invite
        self.reminder = reminder
        self.tournamentInvite = tournamentInvite
        self.matchReminder = matchReminder
    }

    /// Whether this build can draw the item: a known kind with its payload.
    var isVisible: Bool {
        switch kind {
        case .groupInvite: invite != nil
        case .eventReminder: reminder != nil
        case .tournamentInvite: tournamentInvite != nil
        case .matchReminder: matchReminder != nil
        case .unknown: false
        }
    }

    /// The invite this item carries, whichever kind, for the answer it is waiting for; `nil` for a reminder.
    var inviteAnswer: (any InviteAnswer)? {
        invite ?? tournamentInvite
    }

    /// The same invite after the caller answered it; anything else is returned as it is.
    func responding(_ status: InviteStatus, at date: Date) -> InboxItem {
        guard invite != nil || tournamentInvite != nil else { return self }
        return InboxItem(id: id,
                         kind: kind,
                         createdAt: createdAt,
                         invite: invite?.responding(status, at: date),
                         reminder: reminder,
                         tournamentInvite: tournamentInvite?.responding(status, at: date),
                         matchReminder: matchReminder)
    }
}

/// `group_invite`, `event_reminder`, `tournament_invite` or `match_reminder`; anything else keeps its name, so a page
/// or a stream from a newer backend still decodes.
nonisolated enum InboxItemKind: WireNamedKind {
    case groupInvite
    case eventReminder
    case tournamentInvite
    case matchReminder
    case unknown(String)

    private static let groupInviteName = "group_invite"
    private static let eventReminderName = "event_reminder"
    private static let tournamentInviteName = "tournament_invite"
    private static let matchReminderName = "match_reminder"

    init(wireName: String) {
        switch wireName {
        case Self.groupInviteName: self = .groupInvite
        case Self.eventReminderName: self = .eventReminder
        case Self.tournamentInviteName: self = .tournamentInvite
        case Self.matchReminderName: self = .matchReminder
        default: self = .unknown(wireName)
        }
    }

    var wireName: String {
        switch self {
        case .groupInvite: Self.groupInviteName
        case .eventReminder: Self.eventReminderName
        case .tournamentInvite: Self.tournamentInviteName
        case .matchReminder: Self.matchReminderName
        case .unknown(let name): name
        }
    }
}

nonisolated enum InviteStatus: String, Codable, Sendable {
    case pending, accepted, declined
}

/// The `invite` payload of a `group_invite` item: who asked the caller into which group, and where the answer stands.
nonisolated struct InvitePayload: Hashable, Codable, Sendable, InviteAnswer {
    let groupId: String
    let groupName: String
    let groupVisibility: GroupVisibility
    let inviterUserId: String
    let inviterName: String
    let status: InviteStatus
    let expiresAt: Date
    /// Present once the caller accepted or declined.
    let respondedAt: Date?

    init(groupId: String,
         groupName: String,
         groupVisibility: GroupVisibility,
         inviterUserId: String,
         inviterName: String,
         status: InviteStatus = .pending,
         expiresAt: Date,
         respondedAt: Date? = nil) {
        self.groupId = groupId
        self.groupName = groupName
        self.groupVisibility = groupVisibility
        self.inviterUserId = inviterUserId
        self.inviterName = inviterName
        self.status = status
        self.expiresAt = expiresAt
        self.respondedAt = respondedAt
    }

    func responding(_ status: InviteStatus, at date: Date) -> InvitePayload {
        InvitePayload(groupId: groupId,
                      groupName: groupName,
                      groupVisibility: groupVisibility,
                      inviterUserId: inviterUserId,
                      inviterName: inviterName,
                      status: status,
                      expiresAt: expiresAt,
                      respondedAt: date)
    }
}

/// The `reminder` payload of an `event_reminder` item: a snapshot of the game an hour before it starts.
nonisolated struct ReminderPayload: Hashable, Codable, Sendable {
    let eventId: String
    let title: String
    let locationName: String
    let startsAt: Date
    /// Only for a game hosted in a group.
    let groupName: String?

    init(eventId: String, title: String, locationName: String, startsAt: Date, groupName: String? = nil) {
        self.eventId = eventId
        self.title = title
        self.locationName = locationName
        self.startsAt = startsAt
        self.groupName = groupName
    }
}
