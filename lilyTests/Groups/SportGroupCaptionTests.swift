import Testing
@testable import lily

struct SportGroupCaptionTests {
    @Test func namesMembersAndType() {
        let group = SportGroup.fixture(type: .football, memberCount: 34)
        #expect(group.caption() == "34 members · Football")
    }

    @Test func skipsAMissingTypeAndAppendsTheSuffix() {
        let group = SportGroup.fixture(type: nil, memberCount: 1)
        #expect(group.caption(suffix: "Joined") == "1 member · Joined")
    }

    /// A conversation's two members and missing type say nothing worth a row; the caption names what it is.
    @Test func aConversationReadsDirectMessage() {
        let conversation = SportGroup.conversationFixture()
        #expect(conversation.caption() == "Direct message")
        #expect(conversation.caption(suffix: "Active today") == "Direct message · Active today")
    }
}
