import Foundation

/// One event off a channel, decoded from its `type`. Unknown types decode as `.unknown` so a newer backend never
/// breaks the stream; a message carries the full `Message` so no round trip follows a delivery.
nonisolated enum RealtimeEnvelope: Hashable, Sendable, Decodable {
    case message(ChatMessage)
    case messageDeleted(groupID: String, id: String)
    case memberJoined(groupID: String, member: GroupMember, memberCount: Int, channelEpoch: Int)
    case memberLeft(groupID: String, userID: String, channelEpoch: Int, memberCount: Int)
    case groupUpdated(SportGroup)
    case groupDeleted(groupID: String)
    case membershipChanged(MembershipChange)
    case unknown(type: String)

    enum Kind: String, Sendable {
        case message
        case messageDeleted = "message_deleted"
        case memberJoined = "member_joined"
        case memberLeft = "member_left"
        case groupUpdated = "group_updated"
        case groupDeleted = "group_deleted"
        case membershipChanged = "membership_changed"
    }

    private enum CodingKeys: String, CodingKey {
        case type, message, groupId, messageId, member, memberCount, channelEpoch, userId, group
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch Kind(rawValue: type) {
        case .message:
            self = .message(try container.decode(ChatMessage.self, forKey: .message))
        case .messageDeleted:
            self = .messageDeleted(groupID: try container.decode(String.self, forKey: .groupId),
                                   id: try container.decode(String.self, forKey: .messageId))
        case .memberJoined:
            self = .memberJoined(groupID: try container.decode(String.self, forKey: .groupId),
                                 member: try container.decode(GroupMember.self, forKey: .member),
                                 memberCount: try container.decode(Int.self, forKey: .memberCount),
                                 channelEpoch: try container.decode(Int.self, forKey: .channelEpoch))
        case .memberLeft:
            self = .memberLeft(groupID: try container.decode(String.self, forKey: .groupId),
                               userID: try container.decode(String.self, forKey: .userId),
                               channelEpoch: try container.decode(Int.self, forKey: .channelEpoch),
                               memberCount: try container.decode(Int.self, forKey: .memberCount))
        case .groupUpdated:
            self = .groupUpdated(try container.decode(SportGroup.self, forKey: .group))
        case .groupDeleted:
            self = .groupDeleted(groupID: try container.decode(String.self, forKey: .groupId))
        case .membershipChanged:
            self = .membershipChanged(try MembershipChange(from: decoder))
        case .none:
            self = .unknown(type: type)
        }
    }

    /// The group the event is about; `nil` for an unknown type.
    var groupID: String? {
        switch self {
        case .message(let message): message.groupId
        case .messageDeleted(let groupID, _), .memberJoined(let groupID, _, _, _), .memberLeft(let groupID, _, _, _),
             .groupDeleted(let groupID):
            groupID
        case .groupUpdated(let group): group.id
        case .membershipChanged(let change): change.groupId
        case .unknown: nil
        }
    }

    /// The epoch the event names, when it names one; any epoch that differs from the subscribed one means resubscribe.
    var channelEpoch: Int? {
        switch self {
        case .memberJoined(_, _, _, let epoch), .memberLeft(_, _, let epoch, _): epoch
        case .groupUpdated(let group): group.channelEpoch
        case .membershipChanged(let change): change.channelEpoch
        case .message, .messageDeleted, .groupDeleted, .unknown: nil
        }
    }
}
