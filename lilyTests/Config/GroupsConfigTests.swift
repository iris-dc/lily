import Foundation
import Testing
@testable import lily

struct GroupsConfigTests {
    private typealias Paths = AppConfig.API.Paths

    @Test func groupPathsNestUnderTheGroup() {
        #expect(Paths.group(id: "g1") == "/api/groups/g1")
        #expect(Paths.groupMembers(id: "g1") == "/api/groups/g1/members")
        #expect(Paths.groupMember(id: "g1", userID: "u1") == "/api/groups/g1/members/u1")
        #expect(Paths.groupBan(id: "g1", userID: "u1") == "/api/groups/g1/bans/u1")
        #expect(Paths.groupInvite(id: "g1", inviteID: "i1") == "/api/groups/g1/invites/i1")
        #expect(Paths.groupEvents(id: "g1") == "/api/groups/g1/events")
        #expect(Paths.message(id: "g1", messageID: "m1") == "/api/groups/g1/messages/m1")
        #expect(Paths.read(id: "g1") == "/api/groups/g1/read")
    }

    /// Invite codes travel in a body, never in a path the API logs.
    @Test func invitePathsCarryNoCode() {
        #expect(Paths.invitePreview == "/api/invites/preview")
        #expect(Paths.inviteRedeem == "/api/invites/redeem")
    }

    @Test func moderationPaths() {
        #expect(Paths.report(id: "r1") == "/api/reports/r1")
        #expect(Paths.block(userID: "u1") == "/api/blocks/u1")
        #expect(Paths.suspension(userID: "u1") == "/api/moderation/users/u1/suspension")
        #expect(Paths.meTerms == "/api/me/terms")
    }

    /// The mock code must be canonical, or the mock invite path could never be redeemed after normalisation.
    @Test func mockInviteCodeIsCanonical() {
        let code = AppConfig.Groups.mockInviteCode
        #expect(code.count == AppConfig.Groups.inviteCodeLength)
        #expect(code.allSatisfy { AppConfig.Groups.inviteCodeAlphabet.contains($0) })
        #expect(code.range(of: AppConfig.Groups.inviteCodePattern, options: .regularExpression) != nil)
    }

    /// The mock's invite links point where the backend's do, so a deep-link parser can be tested against them.
    @Test func inviteLinksLiveUnderTheProductionHost() {
        #expect(AppConfig.Groups.inviteLinkBaseURL == URL(string: "https://api.iskra.red/invite"))
    }

    @Test func groupCopyReadsInFullSentences() {
        #expect(AppBranding.Groups.members(1) == "1 member")
        #expect(AppBranding.Groups.members(34) == "34 members")
        #expect(AppBranding.Groups.Invite.usesLabel(0) == "Anyone with the link")
        #expect(AppBranding.Groups.Invite.usesLabel(1) == "One person")
        #expect(AppBranding.Groups.Invite.usesLabel(10) == "Up to 10")
        #expect(AppBranding.Groups.Invite.expiryLabel(days: 1) == "1 day")
        #expect(AppBranding.Groups.Invite.expiryLabel(days: 7) == "7 days")
        #expect(AppBranding.Chat.slowDown(seconds: 12) == "Slow down a moment. Try again in 12s.")
    }

    @Test func groupIdentifiersEmbedTheirKeys() {
        #expect(AccessibilityIdentifiers.groupRow("g1") == "group-row-g1")
        #expect(AccessibilityIdentifiers.message(clientID: "c1") == "message-client-c1")
        #expect(AccessibilityIdentifiers.message(id: "m1") == "message-m1")
        #expect(AccessibilityIdentifiers.memberRow("u1") == "member-row-u1")
    }
}
