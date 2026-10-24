import Foundation
import Testing
@testable import lily

/// The room's pins follow the latest page, and the counts of the polls it holds come from pages, refreshes and votes
/// under the revision rule `ChatCatchUp` relies on.
@MainActor
struct ChatRoomStatePollTests {
    private func page(_ messages: [ChatMessage], revision: Int = 0, pins: [PinnedMessage] = []) -> MessagePage {
        MessagePage(items: messages, hasMore: false, channelEpoch: 1, pollRevision: revision, pins: pins)
    }

    @Test func aRoomsFirstPageHoldsItsPollsAtThePagesRevision() {
        var room = ChatRoomState(groupID: "g", channelEpoch: 1)

        room.applyNewest(page([.pollFixture(id: "m1")], revision: 7, pins: [.fixture()]))

        #expect(room.pollRevision == 7 && room.pins == [.fixture()])
    }

    /// A room held before may hold polls from before the page: only a refresh brings it to the page's revision.
    @Test func aHeldRoomKeepsItsRevisionAndTakesTheCountsOfThePollsThePageRepeats() {
        var room = ChatRoomState(groupID: "g", channelEpoch: 1)
        room.applyNewest(page([.pollFixture(id: "m1"), .pollFixture(id: "m2")], revision: 1))

        room.applyNewer(page([.pollFixture(id: "m2", poll: .fixture(votes: [5, 1], totalVoters: 6))], revision: 4))

        #expect(room.pollRevision == 1)
        #expect(room.messages.map { $0.poll?.totalVoters } == [4, 6])
    }

    @Test func aRefreshReplacesThePollsItNamesAndHoldsItsRevision() {
        var room = ChatRoomState.fixture(messages: [.pollFixture(id: "m1"), .fixture(id: "m2")])

        room.applyPolls([PollState(messageId: "m1", poll: .fixture(myVotes: ["1"]))], revision: 9)

        #expect(room.messages.first?.poll?.myVotes == ["1"] && room.pollRevision == 9)
        #expect(room.pollIDs(limit: 50) == ["m1"])
    }

    /// The vote's answer moves the revision only when it is the next one: votes by others since leave a refresh to do.
    @Test func aVotesAnswerMovesTheRevisionOnlyWhenItIsTheNextOne() {
        var room = ChatRoomState(groupID: "g", channelEpoch: 1)
        room.applyNewest(page([.pollFixture(id: "m1")], revision: 3))

        room.applyPoll(messageID: "m1", poll: .fixture(myVotes: ["0"]), revision: 4)
        #expect(room.pollRevision == 4)

        room.applyPoll(messageID: "m1", poll: .fixture(myVotes: ["1"]), revision: 7)
        #expect(room.pollRevision == 4 && room.messages.first?.poll?.myVotes == ["1"])
    }

    @Test func aDeletedPollTakesNoCountsAndIsNotRefreshed() {
        var room = ChatRoomState.fixture(messages: [.pollFixture(id: "m1"), .pollFixture(id: "m2")])
        room.markDeleted(id: "m1")

        room.applyPolls([PollState(messageId: "m1", poll: .fixture(myVotes: ["0"]))], revision: 2)

        #expect(room.messages.first?.poll == nil && room.pollIDs(limit: 50) == ["m2"])
    }

    @Test func theNewestPollsAreAskedForFirst() {
        let room = ChatRoomState.fixture(messages: (1...4).map { .pollFixture(id: "m\($0)") })

        #expect(room.pollIDs(limit: 2) == ["m4", "m3"])
    }
}
