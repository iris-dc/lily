import Foundation

/// One event off a channel, decoded from its `type`. Unknown types decode as `.unknown` so a newer backend never
/// breaks the stream; a message carries the full `Message`, an inbox event the full `InboxItem` and a match event the
/// full `Match`, so no round trip follows a delivery.
nonisolated enum RealtimeEnvelope: Hashable, Sendable, Decodable {
    case message(ChatMessage)
    case messageDeleted(groupID: String, id: String)
    case memberJoined(groupID: String, member: GroupMember, memberCount: Int, channelEpoch: Int)
    case memberLeft(groupID: String, userID: String, channelEpoch: Int, memberCount: Int)
    case groupUpdated(SportGroup)
    case groupDeleted(groupID: String)
    case membershipChanged(MembershipChange)
    /// On `users/<sub>`: an invite for the caller, or a reminder for one of their games or matches.
    case inboxItem(InboxItem)
    /// On a tournament's room: the tournament moved (an entry, the start, a result, the end) or one match did.
    case tournamentChanged(TournamentChange)
    case matchUpdated(TournamentMatch)
    case unknown(type: String)

    enum Kind: String, Sendable {
        case message
        case messageDeleted = "message_deleted"
        case memberJoined = "member_joined"
        case memberLeft = "member_left"
        case groupUpdated = "group_updated"
        case groupDeleted = "group_deleted"
        case membershipChanged = "membership_changed"
        case inboxItem = "inbox_item"
        case tournamentChanged = "tournament_changed"
        case matchUpdated = "match_updated"
    }

    private enum CodingKeys: String, CodingKey {
        case type, message, groupId, messageId, member, memberCount, channelEpoch, userId, group, item, match
    }

    private typealias Container = KeyedDecodingContainer<CodingKeys>

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        guard let kind = Kind(rawValue: type) else {
            self = .unknown(type: type)
            return
        }
        self = try Self.chatEvent(kind, container)
            ?? Self.groupEvent(kind, container, decoder)
            ?? Self.tournamentEvent(kind, container, decoder)
            ?? .unknown(type: type)
    }

    private static func chatEvent(_ kind: Kind, _ container: Container) throws -> RealtimeEnvelope? {
        switch kind {
        case .message:
            .message(try container.decode(ChatMessage.self, forKey: .message))
        case .messageDeleted:
            .messageDeleted(groupID: try container.decode(String.self, forKey: .groupId),
                            id: try container.decode(String.self, forKey: .messageId))
        case .inboxItem:
            .inboxItem(try container.decode(InboxItem.self, forKey: .item))
        default:
            nil
        }
    }

    private static func groupEvent(_ kind: Kind, _ container: Container, _ decoder: any Decoder) throws -> RealtimeEnvelope? {
        switch kind {
        case .memberJoined:
            .memberJoined(groupID: try container.decode(String.self, forKey: .groupId),
                          member: try container.decode(GroupMember.self, forKey: .member),
                          memberCount: try container.decode(Int.self, forKey: .memberCount),
                          channelEpoch: try container.decode(Int.self, forKey: .channelEpoch))
        case .memberLeft:
            .memberLeft(groupID: try container.decode(String.self, forKey: .groupId),
                        userID: try container.decode(String.self, forKey: .userId),
                        channelEpoch: try container.decode(Int.self, forKey: .channelEpoch),
                        memberCount: try container.decode(Int.self, forKey: .memberCount))
        case .groupUpdated:
            .groupUpdated(try container.decode(SportGroup.self, forKey: .group))
        case .groupDeleted:
            .groupDeleted(groupID: try container.decode(String.self, forKey: .groupId))
        case .membershipChanged:
            .membershipChanged(try MembershipChange(from: decoder))
        default:
            nil
        }
    }

    /// The change's fields sit beside `type` (so it decodes from the envelope itself); the match comes whole under `match`.
    private static func tournamentEvent(_ kind: Kind,
                                        _ container: Container,
                                        _ decoder: any Decoder) throws -> RealtimeEnvelope? {
        switch kind {
        case .tournamentChanged:
            .tournamentChanged(try TournamentChange(from: decoder))
        case .matchUpdated:
            .matchUpdated(try container.decode(TournamentMatch.self, forKey: .match))
        default:
            nil
        }
    }

    /// The room the event is about (a tournament's room is the tournament's id); `nil` for an inbox event (the caller's
    /// own channel) and for an unknown type.
    var groupID: String? {
        switch self {
        case .message(let message): message.groupId
        case .messageDeleted(let groupID, _), .memberJoined(let groupID, _, _, _), .memberLeft(let groupID, _, _, _),
             .groupDeleted(let groupID):
            groupID
        case .groupUpdated(let group): group.id
        case .membershipChanged(let change): change.groupId
        case .tournamentChanged(let change): change.tournamentId
        case .matchUpdated(let match): match.tournamentId
        case .inboxItem, .unknown: nil
        }
    }

    /// The epoch the event names, when it names one; any epoch that differs from the subscribed one means resubscribe.
    var channelEpoch: Int? {
        switch self {
        case .memberJoined(_, _, _, let epoch), .memberLeft(_, _, let epoch, _): epoch
        case .groupUpdated(let group): group.channelEpoch
        case .membershipChanged(let change): change.channelEpoch
        case .tournamentChanged(let change): change.channelEpoch
        case .message, .messageDeleted, .groupDeleted, .inboxItem, .matchUpdated, .unknown: nil
        }
    }
}
