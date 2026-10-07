import Foundation

/// Decodes the backend's `Group` directly: same keys, same optionality, except that a missing `kind` reads as a
/// community. Named like `SportEvent` because `Group` is a SwiftUI view and would shadow it in every view file. The
/// owner's id is never on the wire; the roster's `role` says who owns the group, and `membership.role` what the caller
/// is. A direct conversation is a `Group` too (`kind == .direct`): private, two members, named after the other person.
nonisolated struct SportGroup: Identifiable, Hashable, Codable, Sendable {
    let id: String
    private(set) var name: String
    private(set) var description: String?
    let visibility: GroupVisibility
    /// Absent means any sport.
    private(set) var type: EventType?
    let ownerName: String
    private(set) var memberCount: Int
    let maxMembers: Int
    /// Bumped by every leave, removal and ban; the chat channel is `rooms/<id>/<channelEpoch>`.
    private(set) var channelEpoch: Int
    private(set) var membersCanCreateEvents: Bool
    private(set) var membersCanInvite: Bool
    let lastMessageId: String?
    let lastMessageAt: Date?
    let createdAt: Date
    /// Soft delete marker; the group is gone for every purpose but its events' badge.
    private(set) var deletedAt: Date?
    /// Absent for non-members and for banned users.
    private(set) var membership: GroupMembership?
    /// A community, the direct conversation with `counterpart` or a tournament's room; older payloads carry no `kind`,
    /// and a kind this build does not know is kept by name.
    let kind: GroupKind
    /// The other person of a direct conversation, as the caller sees them; absent for a community.
    let counterpart: Counterpart?
    /// Where the group plays, when its owner named a place: what Discover orders a public group by and what its card
    /// shows a distance to. Absent on conversations, rooms and groups from before the field (the backend omits it).
    private(set) var location: EventLocation?

    private enum CodingKeys: String, CodingKey {
        case id, name, description, visibility, type, ownerName, memberCount, maxMembers, channelEpoch
        case membersCanCreateEvents, membersCanInvite, lastMessageId, lastMessageAt, createdAt, deletedAt, membership
        case kind, counterpart, location
    }

    init(id: String,
         name: String,
         description: String? = nil,
         visibility: GroupVisibility,
         type: EventType? = nil,
         ownerName: String,
         memberCount: Int,
         maxMembers: Int = AppConfig.Groups.maxMembers,
         channelEpoch: Int = 1,
         membersCanCreateEvents: Bool = true,
         membersCanInvite: Bool = true,
         lastMessageId: String? = nil,
         lastMessageAt: Date? = nil,
         createdAt: Date,
         deletedAt: Date? = nil,
         membership: GroupMembership? = nil,
         kind: GroupKind = .group,
         counterpart: Counterpart? = nil,
         location: EventLocation? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.visibility = visibility
        self.type = type
        self.ownerName = ownerName
        self.memberCount = memberCount
        self.maxMembers = maxMembers
        self.channelEpoch = channelEpoch
        self.membersCanCreateEvents = membersCanCreateEvents
        self.membersCanInvite = membersCanInvite
        self.lastMessageId = lastMessageId
        self.lastMessageAt = lastMessageAt
        self.createdAt = createdAt
        self.deletedAt = deletedAt
        self.membership = membership
        self.kind = kind
        self.counterpart = counterpart
        self.location = location
    }

    /// Key for key like the synthesized decoder, except that a missing `kind` is a community: the field arrived after
    /// the first groups shipped, and every fixture and contract sample without it must keep decoding.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try container.decode(String.self, forKey: .id),
                  name: try container.decode(String.self, forKey: .name),
                  description: try container.decodeIfPresent(String.self, forKey: .description),
                  visibility: try container.decode(GroupVisibility.self, forKey: .visibility),
                  type: try container.decodeIfPresent(EventType.self, forKey: .type),
                  ownerName: try container.decode(String.self, forKey: .ownerName),
                  memberCount: try container.decode(Int.self, forKey: .memberCount),
                  maxMembers: try container.decode(Int.self, forKey: .maxMembers),
                  channelEpoch: try container.decode(Int.self, forKey: .channelEpoch),
                  membersCanCreateEvents: try container.decode(Bool.self, forKey: .membersCanCreateEvents),
                  membersCanInvite: try container.decode(Bool.self, forKey: .membersCanInvite),
                  lastMessageId: try container.decodeIfPresent(String.self, forKey: .lastMessageId),
                  lastMessageAt: try container.decodeIfPresent(Date.self, forKey: .lastMessageAt),
                  createdAt: try container.decode(Date.self, forKey: .createdAt),
                  deletedAt: try container.decodeIfPresent(Date.self, forKey: .deletedAt),
                  membership: try container.decodeIfPresent(GroupMembership.self, forKey: .membership),
                  kind: try container.decodeIfPresent(GroupKind.self, forKey: .kind) ?? .group,
                  counterpart: try container.decodeIfPresent(Counterpart.self, forKey: .counterpart),
                  location: try container.decodeIfPresent(EventLocation.self, forKey: .location))
    }

    var isFull: Bool { memberCount >= maxMembers }
    /// A direct conversation between the caller and `counterpart`.
    var isDirect: Bool { kind == .direct }
    /// A tournament's room, under the tournament's id; its detail is the tournament's.
    var isTournamentRoom: Bool { kind == .tournament }
    /// A community: what "your groups" means on Home and in the event form. Neither a conversation nor a room of a kind
    /// this build does not know.
    var isCommunity: Bool { kind == .group }
    var isDeleted: Bool { deletedAt != nil }
    var isPublic: Bool { visibility == .public }
    /// Whether the caller is in, as the backend saw it; a banned marker never counts.
    var isMember: Bool { role != nil }
    var role: MemberRole? { membership.flatMap { $0.role == .banned ? nil : $0.role } }
    var hasUnread: Bool { membership?.hasUnread ?? false }
    /// The moment the group was last active, for the Mine order; a silent group counts from its creation.
    var lastActivityAt: Date { lastMessageAt ?? createdAt }

    /// Meters from `origin` to the group's place; `nil` while the user's position is unknown or the group has none.
    func distance(from origin: Coordinate?) -> Measurement<UnitLength>? {
        guard let location, let origin else { return nil }
        return Measurement(value: location.coordinate.distance(to: origin), unit: .meters)
    }

    /// The group as its badge on an event shows it.
    var ref: EventGroupRef {
        EventGroupRef(id: id, name: name, visibility: visibility, isDeleted: isDeleted)
    }

    /// The same group with the caller's membership and the member count the backend now reports.
    func updatingMembership(_ membership: GroupMembership?, memberCount: Int, channelEpoch: Int? = nil) -> SportGroup {
        var copy = self
        copy.membership = membership
        copy.memberCount = memberCount
        copy.channelEpoch = channelEpoch ?? self.channelEpoch
        return copy
    }

    /// A room-wide `group_updated` broadcast carries no `membership` (one payload reaches every member), so the
    /// caller's own stays what the stored copy had.
    func keepingMembership(of stored: SportGroup) -> SportGroup {
        updatingMembership(stored.membership, memberCount: memberCount)
    }

    /// The same group with the editable fields of a draft applied.
    func updating(with draft: GroupDraft) -> SportGroup {
        var copy = self
        copy.name = draft.trimmedName
        copy.description = draft.trimmedDescription
        copy.type = draft.type
        copy.membersCanCreateEvents = draft.membersCanCreateEvents
        copy.membersCanInvite = draft.membersCanInvite
        copy.location = draft.location
        return copy
    }

    func markingDeleted(at date: Date) -> SportGroup {
        var copy = self
        copy.deletedAt = date
        return copy
    }
}
