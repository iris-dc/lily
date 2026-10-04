import Foundation
import Testing
@testable import lily

/// The wire shapes of plan section 3, decoded with the app's conventions, and the helpers the screens read.
struct GroupModelsTests {
    @Test func groupDecodesEveryContractField() throws {
        let group = try ContractSamples.decode(SportGroup.self, from: ContractSamples.group)

        #expect(group.id == "7b1c2d3e-4f50-4a6b-8c9d-0e1f2a3b4c5d")
        #expect(group.name == "Kreuzberg Kickers" && group.description == "Casual 5-a-side, every week")
        #expect(group.visibility == .public && group.type == .football && group.ownerName == "Marta")
        #expect(group.memberCount == 34 && group.maxMembers == 500 && group.channelEpoch == 3)
        #expect(group.membersCanCreateEvents && !group.membersCanInvite)
        #expect(group.lastMessageId == "01J8ZK7Q9X2M4N6P8R0T2V4W6Y")
        #expect(group.lastMessageAt == APIJSONCoding.parseInstant("2026-09-24T18:00:00Z"))
        #expect(group.deletedAt == nil && !group.isDeleted)
        let membership = try #require(group.membership)
        #expect(membership.role == .admin && membership.hasUnread && membership.lastReadMessageId == "01J8ZK7Q9X2M4N6P8R0T2V4W6X")
        #expect(group.role == .admin && group.isMember && group.hasUnread)
        #expect(group.kind == .group && group.counterpart == nil && !group.isDirect)
    }

    /// Optionals the backend leaves out decode as absent; a full private group reads as full and as no membership.
    @Test func minimalGroupDecodesWithAbsentOptionals() throws {
        let group = try ContractSamples.decode(SportGroup.self, from: ContractSamples.minimalGroup)

        #expect(group.description == nil && group.type == nil && group.lastMessageId == nil && group.lastMessageAt == nil)
        #expect(group.membership == nil && !group.isMember && group.role == nil && !group.hasUnread)
        #expect(group.isFull && !group.isPublic)
        #expect(group.lastActivityAt == group.createdAt, "a silent group counts from its creation")
        #expect(group.kind == .group && group.counterpart == nil, "a payload without kind is a community")
    }

    /// A direct conversation is a `Group` with `kind` and the other person; both survive a round trip and every copy.
    @Test func aConversationDecodesItsKindAndCounterpartAndRoundTrips() throws {
        let conversation = try ContractSamples.decode(SportGroup.self, from: ContractSamples.conversation)
        #expect(conversation.kind == .direct && conversation.isDirect && conversation.name == "Marta")
        #expect(conversation.counterpart == Counterpart(userId: "seed-marta", displayName: "Marta"))
        #expect(conversation.counterpart?.profile() == UserProfileDestination(userId: "seed-marta", displayName: "Marta"))
        #expect(conversation.counterpart?.profile(context: .fromChat).context == .fromChat)
        #expect(conversation.updatingMembership(nil, memberCount: 2).isDirect)
        #expect(conversation.keepingMembership(of: conversation).counterpart == conversation.counterpart)

        let encoder = APIJSONCoding.makeEncoder()
        let json = try #require(String(bytes: try encoder.encode(conversation), encoding: .utf8))
        #expect(json.contains(#""kind":"direct""#) && json.contains(#""counterpart":{"#))
        #expect(try ContractSamples.decode(SportGroup.self, from: json) == conversation)
        let community = try #require(String(bytes: try encoder.encode(SportGroup.fixture()), encoding: .utf8))
        #expect(community.contains(#""kind":"group""#) && !community.contains("counterpart"), "no counterpart on a community")
    }

    /// A kind a newer backend sends is kept by name: the group decodes with everything else intact, is neither a
    /// conversation nor a community, and goes back out with the same kind.
    @Test func aGroupOfAnUnknownKindDecodesByNameAndRoundTrips() throws {
        try #require(ContractSamples.group.contains(#""kind":"group""#))
        let sample = ContractSamples.group.replacingOccurrences(of: #""kind":"group""#, with: #""kind":"league""#)

        let room = try ContractSamples.decode(SportGroup.self, from: sample)

        #expect(room.kind == .unknown("league") && room.kind.isUnknown && room.kind.wireName == "league")
        #expect(!room.isDirect && !room.isCommunity && room.counterpart == nil && room.name == "Kreuzberg Kickers")
        #expect(room.role == .admin && room.isMember, "the membership reads as for any group")
        let json = try #require(String(bytes: try APIJSONCoding.makeEncoder().encode(room), encoding: .utf8))
        #expect(json.contains(#""kind":"league""#))
        #expect(try ContractSamples.decode(SportGroup.self, from: json) == room)
        #expect(SportGroup.fixture().isCommunity && !SportGroup.conversationFixture().isCommunity)
    }

    @Test func knownGroupKindsRoundTripThroughTheirWireNames() {
        #expect(GroupKind(wireName: "group") == .group && GroupKind(wireName: "direct") == .direct)
        #expect(GroupKind.group.wireName == "group" && GroupKind.direct.wireName == "direct")
        #expect(!GroupKind.group.isUnknown && !GroupKind.direct.isUnknown)
    }

    /// A banned marker must never read as a membership, whatever the backend sends.
    @Test func bannedMembershipIsNoMembership() {
        let group = SportGroup.fixture(role: .banned)
        #expect(group.role == nil && !group.isMember)
        #expect(GroupAccess(group: group, userID: "u-1") == .canJoin)
    }

    @Test func pagesDecodeWithAndWithoutACursor() throws {
        let first = try ContractSamples.decode(Page<SportGroup>.self, from: ContractSamples.groupPage)
        let last = try ContractSamples.decode(Page<SportGroup>.self, from: ContractSamples.lastGroupPage)
        let roster = try ContractSamples.decode(Page<GroupMember>.self, from: ContractSamples.memberList)

        #expect(first.items.count == 1 && first.nextCursor == "eyJuYW1lTG93ZXIiOiJrIn0")
        #expect(last.items.count == 1 && last.nextCursor == nil)
        let marta = GroupMember(userId: "seed-marta",
                                displayName: "Marta",
                                role: .owner,
                                joinedAt: APIJSONCoding.parseInstant("2026-06-01T10:00:00Z")!)
        #expect(roster.items == [marta])
    }

    @Test func accountDecodesAndJudgesTheTerms() throws {
        let owing = try ContractSamples.decode(Account.self, from: ContractSamples.me)
        #expect(owing.isOperator && owing.termsVersion == 2 && owing.acceptedTermsVersion == 1 && !owing.termsAccepted)
        #expect(owing.realtimeEndpoint?.host() == "abc.appsync-api.eu-central-1.amazonaws.com")

        let fresh = try ContractSamples.decode(Account.self, from: ContractSamples.minimalMe)
        #expect(!fresh.isOperator && fresh.acceptedTermsVersion == nil && fresh.realtimeEndpoint == nil && !fresh.termsAccepted)

        let acceptance = try ContractSamples.decode(TermsAcceptance.self, from: ContractSamples.termsAcceptance)
        #expect(owing.acceptingTerms(acceptance).termsAccepted)
    }

    @Test func moderationAnswersDecode() throws {
        let receipt = try ContractSamples.decode(ReportReceipt.self, from: ContractSamples.reportReceipt)
        #expect(receipt.id == "3f1a9c2b7d8e4f6a0b1c2d3e4f5a6b7c")
        let blocked = try ContractSamples.decode(BlockedUsers.self, from: ContractSamples.blockedUsers)
        #expect(blocked.blockedUserIds == ["u-7", "u-9"])
        #expect(try ContractSamples.decode(UnbanReceipt.self, from: ContractSamples.unbanReceipt).unbanned)
    }

    /// The envelope's `type` key is the transport's; the change itself decodes from the rest.
    @Test func membershipChangeDecodesItsKindAndRole() throws {
        let change = try ContractSamples.decode(MembershipChange.self, from: ContractSamples.membershipChange)
        #expect(change.groupId == "g1" && change.change == .roleChanged && change.role == .admin && change.channelEpoch == 4)
        #expect(!change.endsMembership)
        #expect(MembershipChange(groupId: "g", change: .removed, role: nil, channelEpoch: 2).endsMembership)
    }

    @Test func groupHelpersDeriveFromTheWireFields() {
        let group = SportGroup.fixture(id: "g", name: "N", visibility: .public, memberCount: 3, role: .member)
        #expect(group.ref == EventGroupRef(id: "g", name: "N", visibility: .public, isDeleted: false))
        #expect(group.ref.isLinkable && !SportGroup.fixture(visibility: .private).ref.isLinkable)
        #expect(!group.markingDeleted(at: .now).ref.isLinkable)
        #expect(RoomSubscription(group: SportGroup.fixture(id: "g", channelEpoch: 7)) == RoomSubscription(groupID: "g", epoch: 7))

        let left = group.updatingMembership(nil, memberCount: 2, channelEpoch: 2)
        #expect(!left.isMember && left.memberCount == 2 && left.channelEpoch == 2)
        #expect(group.updatingMembership(group.membership, memberCount: 4).channelEpoch == 1, "the epoch is kept unless given")
    }

    @Test func roleAndVisibilityNamesComeFromBranding() {
        #expect(MemberRole.owner.isAdmin && MemberRole.admin.isAdmin && !MemberRole.member.isAdmin && !MemberRole.banned.isAdmin)
        #expect(MemberRole.owner.displayName == AppBranding.Groups.ownerRole)
        #expect(GroupVisibility.private.displayName == AppBranding.Groups.privateVisibility)
        #expect(GroupVisibility.public.symbolName == DesignTokens.Symbols.publicGroup)
        #expect(ReportReason.harassment.displayName == AppBranding.Moderation.reasonHarassment)
    }
}
