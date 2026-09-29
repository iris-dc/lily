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
        #expect(Paths.groupInvites(id: "g1") == "/api/groups/g1/invites")
        #expect(Paths.groupInvitees(id: "g1") == "/api/groups/g1/invitees")
        #expect(Paths.groupEvents(id: "g1") == "/api/groups/g1/events")
        #expect(Paths.message(id: "g1", messageID: "m1") == "/api/groups/g1/messages/m1")
        #expect(Paths.read(id: "g1") == "/api/groups/g1/read")
    }

    /// The inbox is the caller's own resource, so it lives under `/api/me`.
    @Test func inboxPathsLiveUnderMe() {
        #expect(Paths.inbox == "/api/me/inbox")
        #expect(Paths.inboxRead == "/api/me/inbox/read")
        #expect(Paths.inboxAccept(id: "i1") == "/api/me/inbox/i1/accept")
        #expect(Paths.inboxDecline(id: "i1") == "/api/me/inbox/i1/decline")
    }

    @Test func moderationPaths() {
        #expect(Paths.report(id: "r1") == "/api/reports/r1")
        #expect(Paths.block(userID: "u1") == "/api/blocks/u1")
        #expect(Paths.suspension(userID: "u1") == "/api/moderation/users/u1/suspension")
        #expect(Paths.meTerms == "/api/me/terms")
    }

    @Test func groupCopyReadsInFullSentences() {
        #expect(AppBranding.Groups.members(1) == "1 member")
        #expect(AppBranding.Groups.members(34) == "34 members")
        #expect(AppBranding.Groups.privateFooter == "Only people who are invited can join")
        #expect(AppBranding.Chat.slowDown(seconds: 12) == "Slow down a moment. Try again in 12s.")
    }

    @Test func chatsAndInboxCopyReadInFullSentences() {
        #expect(AppBranding.chatsTitle == "Chats")
        #expect(AppBranding.Chats.unreadChats(1) == "1 unread chat")
        #expect(AppBranding.Chats.unreadChats(3) == "3 unread chats")
        #expect(AppBranding.Inbox.title == AppBranding.name)
        let invited = AppBranding.Inbox.invitedYou(inviter: "Noor", group: "Climbing Buddies")
        #expect(invited == "Noor invited you to Climbing Buddies")
        #expect(AppBranding.Inbox.reminderTitle == "Game reminder")
    }

    @Test func inviteCopyNamesWhatIsShared() {
        #expect(AppBranding.Groups.Invite.viaGroup("Kreuzberg Kickers") == "In Kreuzberg Kickers")
        #expect(AppBranding.Groups.Invite.viaEvent("Sunset 5-a-side") == "Played Sunset 5-a-side")
        #expect(AppBranding.Groups.Invite.emptyTitle == "Nobody to invite yet")
        #expect(AppBranding.Groups.Invite.send == "Invite" && AppBranding.Groups.Invite.sent == "Invited")
    }

    @Test func groupIdentifiersEmbedTheirKeys() {
        #expect(AccessibilityIdentifiers.groupRow("g1") == "group-row-g1")
        #expect(AccessibilityIdentifiers.message(clientID: "c1") == "message-client-c1")
        #expect(AccessibilityIdentifiers.message(id: "m1") == "message-m1")
        #expect(AccessibilityIdentifiers.memberRow("u1") == "member-row-u1")
        #expect(AccessibilityIdentifiers.inviteSearch == "invite-search")
        #expect(AccessibilityIdentifiers.inviteCandidate("u1") == "invite-candidate-u1")
        #expect(AccessibilityIdentifiers.inviteSend("u1") == "invite-send-u1")
    }

    @Test func inboxIdentifiersEmbedTheirKeys() {
        #expect(AccessibilityIdentifiers.inboxRow == "inbox-row")
        #expect(AccessibilityIdentifiers.inboxLoadEarlier == "inbox-load-earlier")
        #expect(AccessibilityIdentifiers.inboxItem("i1") == "inbox-item-i1")
        #expect(AccessibilityIdentifiers.inboxAccept("i1") == "inbox-accept-i1")
        #expect(AccessibilityIdentifiers.inboxDecline("i1") == "inbox-decline-i1")
    }

    /// The inbox pages at the backend's maximum and reuses what it loaded like the other lists; the mocks keep the
    /// backend's invite expiry (`invites.pending-days`) and reminder lead (`reminders.lead`).
    @Test func inboxLimitsMirrorTheBackend() {
        #expect(AppConfig.Inbox.pageSize == 50)
        #expect(AppConfig.Inbox.listStaleAfter == AppConfig.Groups.listStaleAfter)
        #expect(AppConfig.Inbox.retryAfterFailure == AppConfig.Groups.retryAfterFailure)
        #expect(AppConfig.Inbox.mockInviteExpiry == 7 * 86_400 && AppConfig.Inbox.mockReminderLead == 3_600)
    }
}
