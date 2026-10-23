import Foundation
import Testing
@testable import lily

/// The room cache tells the activity recorder of a room's new last message, whoever stored it, and of nothing else.
@MainActor
struct ChatHistoryCacheActivityTests {
    @Test func aNewLastMessageIsNotedOnce() {
        let activity = SpyRoomActivity()
        let cache = InMemoryChatHistoryCache(activity: activity, logger: SpyLogger())
        let first = ChatMessage.fixture(id: "m1")
        let second = ChatMessage.fixture(id: "m2")

        cache.store(.fixture(messages: [first]), for: "g")
        cache.store(.fixture(messages: [first]), for: "g")
        cache.store(.fixture(messages: [first, second]), for: "g")
        cache.update(groupID: "g") { $0.markDeleted(id: "m1") }
        cache.store(.fixture(), for: "g")

        #expect(activity.noted.map { "\($0.groupID)/\($0.messageID)" } == ["g/m1", "g/m2"])
    }
}

@MainActor
private final class SpyRoomActivity: RoomActivityRecorder {
    private(set) var noted: [(groupID: String, messageID: String)] = []

    func noteMessage(_ message: ChatMessage, in groupID: String) {
        noted.append((groupID, message.id))
    }
}
