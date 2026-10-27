import Testing
@testable import lily

/// Which items a long press on a bubble offers, so the transcript attaches a menu only when something can be tapped.
struct MessageMenuItemsTests {
    private static let tombstone = ChatMessage.fixture(id: "m1", text: nil, isDeleted: true)

    @Test func anOwnDeletedMessageOffersNoMenu() {
        let items = MessageMenuItems.items(for: Self.tombstone, isOwn: true, canReply: false, canDelete: false)

        #expect(items.enabled.isEmpty)
        #expect(!items.hasEnabledItems)
    }

    @Test func anotherMembersTombstoneOffersNoMenu() {
        let items = MessageMenuItems.items(for: Self.tombstone, isOwn: false, canReply: false, canDelete: false)

        #expect(items.enabled.isEmpty)
        #expect(!items.hasEnabledItems)
        #expect(!items.offers(.report) && !items.offers(.block))
    }

    @Test func aLiveOwnMessageOffersReplyCopyAndDelete() {
        let items = MessageMenuItems.items(for: .fixture(id: "m1"), isOwn: true, canReply: true, canDelete: true)

        #expect(items.enabled == [.reply, .copy, .delete])
        #expect(items.hasEnabledItems && items.offers(.delete))
        #expect(!items.offers(.report) && !items.offers(.block))
    }

    @Test func aLiveMessageOfAnotherMemberOffersReplyCopyReportAndBlock() {
        let items = MessageMenuItems.items(for: .fixture(id: "m1"), isOwn: false, canReply: true, canDelete: false)

        #expect(items.enabled == [.reply, .copy, .report, .block])
        #expect(items.hasEnabledItems && !items.offers(.delete))
    }

    @Test func aPictureOnlyMessageHasNothingToCopy() {
        let picture = ChatMessage.fixture(id: "m1", text: nil, attachments: [lily.Attachment.fixture()])

        let items = MessageMenuItems.items(for: picture, isOwn: true, canReply: true, canDelete: true)

        #expect(items.enabled == [.reply, .delete] && !items.offers(.copy))
    }

    @Test func anAdminMayDeleteAnotherMembersMessage() {
        let items = MessageMenuItems.items(for: .fixture(id: "m1"), isOwn: false, canReply: true, canDelete: true)

        #expect(items.enabled == [.reply, .copy, .delete, .report, .block])
    }

    @Test func aPinnableVotedPollOffersPinAndRetractVoteBetweenCopyAndDelete() {
        let poll = ChatMessage.pollFixture(id: "m1")

        let items = MessageMenuItems.items(for: poll,
                                           isOwn: true,
                                           canReply: true,
                                           canDelete: true,
                                           pinning: .pin,
                                           canRetractVote: true)

        #expect(items.enabled == [.reply, .pin, .retractVote, .delete], "a poll has no text to copy")
    }

    @Test func aPinnedMessageOffersUnpinInsteadOfPin() {
        let items = MessageMenuItems.items(for: .fixture(id: "m1"),
                                           isOwn: false,
                                           canReply: true,
                                           canDelete: false,
                                           pinning: .unpin)

        #expect(items.enabled == [.reply, .copy, .unpin, .report, .block])
        #expect(items.offers(.unpin) && !items.offers(.pin) && !items.offers(.retractVote))
    }
}
