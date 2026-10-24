import Foundation
import Testing
@testable import lily

/// A catch-up whose page names a later poll revision than the room holds asks once for the polls held; otherwise it
/// asks nothing, and a failed refresh leaves the revision behind for the next catch-up.
@MainActor
struct ChatCatchUpPollTests {
    private let repository = FakeChatRepository()
    private let logger = SpyLogger()
    private let cache: InMemoryChatHistoryCache
    private let catchUp: ChatCatchUp

    init() {
        cache = InMemoryChatHistoryCache(logger: logger)
        catchUp = ChatCatchUp(repository: repository, cache: cache, logger: logger)
    }

    private func page(_ messages: [ChatMessage], revision: Int) -> MessagePage {
        MessagePage(items: messages, hasMore: false, channelEpoch: 1, pollRevision: revision)
    }

    private func holdRoom(revision: Int) async throws {
        repository.newestPages = [page([.pollFixture(id: "m1"), .fixture(id: "m2")], revision: revision)]
        try await catchUp.loadNewest(groupID: "g", epoch: 1)
    }

    @Test func aLaterRevisionRefreshesThePollsHeld() async throws {
        try await holdRoom(revision: 2)
        repository.newerPages = [page([.fixture(id: "m3")], revision: 5)]
        repository.polls.pollStates = [.success(PollStates(items: [PollState(messageId: "m1", poll: .fixture(myVotes: ["1"]))],
                                                           pollRevision: 5))]

        let room = try #require(try await catchUp.catchUp(groupID: "g"))

        #expect(repository.polls.refreshes == [["m1"]])
        #expect(room.pollRevision == 5 && room.messages.first?.poll?.myVotes == ["1"])
    }

    @Test func theSameRevisionAsksNothing() async throws {
        try await holdRoom(revision: 2)
        repository.newerPages = [page([.fixture(id: "m3")], revision: 2)]

        try await catchUp.catchUp(groupID: "g")

        #expect(repository.polls.refreshes.isEmpty)
    }

    @Test func aFailedRefreshLeavesTheRevisionForTheNextCatchUp() async throws {
        try await holdRoom(revision: 2)
        repository.newerPages = [page([], revision: 5), page([], revision: 5)]
        repository.polls.pollStates = [.failure(AppError.network)]

        let failed = try #require(try await catchUp.catchUp(groupID: "g"))
        #expect(failed.pollRevision == 2)

        try await catchUp.catchUp(groupID: "g")
        #expect(repository.polls.refreshes.count == 2)
        #expect(logger.hasLine(in: .chat, at: .warning, mentioning: "Poll refresh failed", "g"))
    }

    @Test func aRoomWithoutPollsTakesTheRevisionWithoutAsking() async throws {
        repository.newestPages = [page([.fixture(id: "m1")], revision: 0)]
        try await catchUp.loadNewest(groupID: "g", epoch: 1)
        repository.newerPages = [page([.fixture(id: "m2")], revision: 3)]

        let room = try #require(try await catchUp.catchUp(groupID: "g"))

        #expect(repository.polls.refreshes.isEmpty && room.pollRevision == 3)
    }
}
