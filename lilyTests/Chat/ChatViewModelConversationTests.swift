import Testing
@testable import lily

/// A direct conversation in the chat: the title alone names the two people, and the other person's profile counts as
/// reached from here.
@MainActor
struct ChatViewModelConversationTests {
    private let harness = RealtimeHarness()

    @Test func aConversationHasNoMemberCountSubtitle() {
        #expect(harness.makeChatViewModel(for: .conversationFixture()).subtitle == nil)
        #expect(harness.makeChatViewModel(for: .fixture(memberCount: 34, role: .member)).subtitle == "34 members")
    }

    /// The other person's bubbles lead to their profile as reached from this chat, which then offers no "Message" back
    /// into the room; a sender's profile in a group, or anyone else's in a conversation, is standalone.
    @Test func theCounterpartsProfileCountsAsReachedFromTheChat() {
        let conversation = harness.makeChatViewModel(for: .conversationFixture())
        let group = harness.makeChatViewModel(for: .fixture(role: .member))
        let fromMarta = row(from: .fixture(id: "m1", senderUserID: "u-2", senderName: "Marta"))
        let fromDev = row(from: .fixture(id: "m2", senderUserID: "u-3", senderName: "Dev"))

        let expected = UserProfileDestination(userId: "u-2", displayName: "Marta", context: .fromChat)
        #expect(conversation.profile(of: fromMarta) == expected)
        #expect(group.profile(of: fromMarta) == UserProfileDestination(userId: "u-2", displayName: "Marta"))
        #expect(conversation.profile(of: fromDev) == UserProfileDestination(userId: "u-3", displayName: "Dev"))
    }

    private func row(from message: ChatMessage) -> MessageRow {
        MessageRow(message: message, isOwn: false, senderName: message.senderName, isFirstInRun: true, isLastInRun: true)
    }
}
