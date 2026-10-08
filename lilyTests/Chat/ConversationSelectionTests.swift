import Testing
@testable import lily

/// What the Chats split view may keep in its detail column: the inbox always, a room only while Mine lists it.
struct ConversationSelectionTests {
    private let groups = [SportGroup.fixture(id: "kickers"), SportGroup.fixture(id: "runners")]

    @Test func theInboxIsAlwaysAvailable() {
        #expect(ConversationSelection.inbox.isAvailable(in: groups))
        #expect(ConversationSelection.inbox.isAvailable(in: []))
    }

    @Test func aRoomIsAvailableWhileMineListsIt() {
        #expect(ConversationSelection.room(id: "kickers").isAvailable(in: groups))
    }

    /// A room the caller left, a deleted group or a cleared conversation: the selection must go with it.
    @Test func aRoomThatLeftMineIsNot() {
        #expect(!ConversationSelection.room(id: "kickers").isAvailable(in: [SportGroup.fixture(id: "runners")]))
        #expect(!ConversationSelection.room(id: "kickers").isAvailable(in: []))
    }
}
