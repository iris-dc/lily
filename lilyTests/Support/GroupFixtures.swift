import Foundation
@testable import lily

extension SportGroup {
    /// A public group the caller is not in; every optional detail absent unless given, so tests state only what they test.
    static func fixture(id: String = "g",
                        name: String = "Group",
                        visibility: GroupVisibility = .public,
                        type: EventType? = nil,
                        memberCount: Int = 5,
                        maxMembers: Int = AppConfig.Groups.maxMembers,
                        channelEpoch: Int = 1,
                        membersCanCreateEvents: Bool = true,
                        membersCanInvite: Bool = true,
                        lastMessageId: String? = nil,
                        lastMessageAt: Date? = nil,
                        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
                        deletedAt: Date? = nil,
                        role: MemberRole? = nil,
                        hasUnread: Bool = false) -> SportGroup {
        SportGroup(id: id,
                   name: name,
                   visibility: visibility,
                   type: type,
                   ownerName: "Owner",
                   memberCount: memberCount,
                   maxMembers: maxMembers,
                   channelEpoch: channelEpoch,
                   membersCanCreateEvents: membersCanCreateEvents,
                   membersCanInvite: membersCanInvite,
                   lastMessageId: lastMessageId,
                   lastMessageAt: lastMessageAt,
                   createdAt: createdAt,
                   deletedAt: deletedAt,
                   membership: role.map { GroupMembership(role: $0, joinedAt: createdAt, hasUnread: hasUnread) })
    }
}

extension GroupDraft {
    /// A draft that passes validation, with a lower-case UUID like a real draft's.
    static func fixture(clientId: String = "3f2504e0-4f89-11d3-9a0c-0305e82c3302") -> GroupDraft {
        var draft = GroupDraft(clientId: clientId)
        draft.name = "Kreuzberg Kickers"
        return draft
    }
}

extension GroupMember {
    static func fixture(userId: String = "u-2", role: MemberRole = .member) -> GroupMember {
        GroupMember(userId: userId,
                    displayName: "Member \(userId)",
                    role: role,
                    joinedAt: Date(timeIntervalSince1970: 1_700_000_000))
    }
}

extension Invite {
    static func fixture(inviteId: String = "01J8INVITE00000000000000A", code: String? = "KRZB7K3MQX9P") -> Invite {
        Invite(inviteId: inviteId,
               code: code,
               url: code.map { AppConfig.Groups.inviteLinkBaseURL.appending(path: $0) },
               groupId: "g",
               createdBy: TestFixtures.user.id,
               createdAt: Date(timeIntervalSince1970: 1_700_000_000),
               expiresAt: Date(timeIntervalSince1970: 1_700_604_800),
               maxUses: 0,
               uses: 0,
               revokedAt: nil)
    }
}

extension Account {
    static func fixture(termsVersion: Int = 1, acceptedTermsVersion: Int? = 1, isOperator: Bool = false) -> Account {
        Account(userId: TestFixtures.user.id,
                isOperator: isOperator,
                termsVersion: termsVersion,
                acceptedTermsVersion: acceptedTermsVersion)
    }
}

/// The groups, invites, moderation and account JSON exactly as the contract shows it.
extension ContractSamples {
    /// The contract event with the group the backend stamps on a game hosted in a public group.
    static let groupedEvent = """
    {"id":"evt_03","title":"Sunset 5-a-side","type":"football","startsAt":"2026-09-13T17:00:00Z",\
    "location":{"name":"Riverside Pitch 2","coordinate":{"latitude":52.529,"longitude":13.387}},\
    "capacity":10,"participantCount":6,"hostUserId":"seed-marta","hostName":"Marta","isJoined":false,\
    "group":{"id":"7b1c2d3e-4f50-4a6b-8c9d-0e1f2a3b4c5d","name":"Kreuzberg Kickers","visibility":"public","isDeleted":false}}
    """
    static let group = """
    {"id":"7b1c2d3e-4f50-4a6b-8c9d-0e1f2a3b4c5d","name":"Kreuzberg Kickers","description":"Casual 5-a-side, every week",\
    "visibility":"public","type":"football","ownerName":"Marta","memberCount":34,"maxMembers":500,"channelEpoch":3,\
    "membersCanCreateEvents":true,"membersCanInvite":false,"lastMessageId":"01J8ZK7Q9X2M4N6P8R0T2V4W6Y",\
    "lastMessageAt":"2026-09-24T18:00:00Z","createdAt":"2026-06-01T10:00:00Z",\
    "membership":{"role":"admin","joinedAt":"2026-06-02T10:00:00Z",\
    "lastReadMessageId":"01J8ZK7Q9X2M4N6P8R0T2V4W6X","hasUnread":true}}
    """
    static let minimalGroup = """
    {"id":"g2","name":"Spree Volley","visibility":"private","ownerName":"Luca","memberCount":12,"maxMembers":12,\
    "channelEpoch":1,"membersCanCreateEvents":true,"membersCanInvite":true,"createdAt":"2026-09-01T10:00:00Z"}
    """
    static let groupPage = #"{"items":[\#(group)],"nextCursor":"eyJuYW1lTG93ZXIiOiJrIn0"}"#
    static let lastGroupPage = #"{"items":[\#(minimalGroup)],"nextCursor":null}"#
    static let member = #"{"userId":"seed-marta","displayName":"Marta","role":"owner","joinedAt":"2026-06-01T10:00:00Z"}"#
    static let memberList = #"{"items":[\#(member)]}"#
    static let invite = """
    {"inviteId":"01J8ZK7Q9X2M4N6P8R0T2V4W6Z","code":"KRZB7K3MQX9P","url":"https://api.iskra.red/invite/KRZB7K3MQX9P",\
    "groupId":"7b1c2d3e-4f50-4a6b-8c9d-0e1f2a3b4c5d","createdBy":"u-1","createdAt":"2026-09-24T18:00:00Z",\
    "expiresAt":"2026-10-01T18:00:00Z","maxUses":10,"uses":2}
    """
    static let invitePreview = """
    {"group":{"id":"g3","name":"Climbing Buddies","description":"Bouldering after work","visibility":"private",\
    "type":"climbing","memberCount":9},"expiresAt":"2026-10-01T18:00:00Z","isMember":false}
    """
    static let me = """
    {"userId":"u-1","isOperator":true,"termsVersion":2,"acceptedTermsVersion":1,\
    "realtimeEndpoint":"https://abc.appsync-api.eu-central-1.amazonaws.com/event"}
    """
    static let minimalMe = #"{"userId":"u-1","isOperator":false,"termsVersion":1}"#
    static let termsAcceptance = #"{"acceptedTermsVersion":2,"acceptedTermsAt":"2026-09-25T09:00:00Z"}"#
    static let reportReceipt = #"{"id":"3f1a9c2b7d8e4f6a0b1c2d3e4f5a6b7c","createdAt":"2026-09-25T09:00:00Z"}"#
    static let blockedUsers = #"{"blockedUserIds":["u-7","u-9"]}"#
    static let unbanReceipt = #"{"unbanned":true}"#
    static let membershipChange = """
    {"type":"membership_changed","groupId":"g1","change":"role_changed","role":"admin","channelEpoch":4}
    """

    static func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        try APIJSONCoding.makeDecoder().decode(type, from: Data(json.utf8))
    }
}

extension InvitePreview {
    /// The preview of an invite into a private climbing group, as the mock and the contract sample show it.
    static func fixture(groupID: String = "g3", isMember: Bool = false) -> InvitePreview {
        InvitePreview(group: GroupSummary(id: groupID,
                                          name: "Climbing Buddies",
                                          description: "Bouldering after work",
                                          visibility: .private,
                                          type: .climbing,
                                          memberCount: 9),
                      expiresAt: Date(timeIntervalSince1970: 1_700_604_800),
                      isMember: isMember)
    }
}
