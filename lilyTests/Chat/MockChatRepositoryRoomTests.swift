import Foundation
import Testing
@testable import lily

/// The per-room rules of the mock: a line written in a run sorts after every fixture row of its room and after every
/// earlier line of the run, and a clear's floor hides them all, whatever the room's id code, and reads the room; a
/// delete is idempotent and open to admins, and a replay by another sender is refused. In a sibling file because
/// the main suite's body is near the limit.
extension MockChatRepositoryTests {
    /// Every room the caller is in: Kickers, Runners, Padel, the conversation with Marta, the Kickers Cup's room and
    /// the table-tennis room. `nonisolated`: `@Test(arguments:)` reads it off the main actor.
    nonisolated private static let joinedRoomIDs: [String] = MockGroupFixtures.make(now: .now).filter(\.isMember).map(\.id)

    /// The sent line is the room's newest, the fixtures are all that lies before it and it alone lies after them, in a
    /// room whose id code sorts before the old shared one as in one that sorts after it.
    @Test(arguments: joinedRoomIDs)
    func aSentMessageSortsAfterEveryFixtureRowInEveryRoom(room: String) async throws {
        let repository = makeRepository()
        let fixtures = try await repository.newest(groupID: room).items
        let newestFixtureID = try #require(fixtures.last?.id)

        let sent = try await repository.send(groupID: room, draft("hi", clientID: "c-1"))

        let page = try await repository.newest(groupID: room).items
        #expect(page.map(\.id) == page.map(\.id).sorted())
        #expect(page.last == sent.message)
        #expect(page.count == fixtures.count + 1)
        let before = try await repository.older(groupID: room, before: sent.message.id).items
        #expect(before == fixtures)
        let after = try await repository.newer(groupID: room, after: newestFixtureID).items
        #expect(after == [sent.message])
    }

    /// In every joined room, the table-tennis one (whose id code sorts after the old shared one) included: two sends
    /// keep their order, a clear hides them with the fixtures, and a send after the clear is all that is left to see.
    @Test(arguments: joinedRoomIDs)
    func consecutiveSendsKeepTheirOrder(room: String) async throws {
        let repository = makeRepository()

        let first = try await repository.send(groupID: room, draft("one", clientID: "c-1"))
        let second = try await repository.send(groupID: room, draft("two", clientID: "c-2"))
        let page = try await repository.newest(groupID: room).items
        #expect(page.map(\.id) == page.map(\.id).sorted())
        #expect(page.suffix(2).map(\.text) == ["one", "two"])
        #expect(second.message.id > first.message.id)

        let cleared = try await repository.clearHistory(groupID: room)
        let visible = try await repository.newest(groupID: room).items
        let newestFixture = MockChatFixtures.newestMessageID(for: room)
        let belowNewestFixture = try await repository.older(groupID: room, before: newestFixture).items
        let readMarker = MockChatFixtures.lastReadMessageID(for: room)
        let aboveReadMarker = try await repository.newer(groupID: room, after: readMarker).items
        #expect(visible.isEmpty && belowNewestFixture.isEmpty && aboveReadMarker.isEmpty)

        let third = try await repository.send(groupID: room, draft("three", clientID: "c-3"))
        let afterClear = try await repository.newest(groupID: room).items
        let aboveFloor = try await repository.newer(groupID: room, after: cleared.historyFloor).items
        let belowThird = try await repository.older(groupID: room, before: third.message.id).items
        #expect(afterClear.map(\.text) == ["three"] && aboveFloor.map(\.text) == ["three"])
        #expect(belowThird.isEmpty, "the floor hides the fixtures and the two earlier sends")
    }

    /// The two fixture rooms that start unread. A clear parks the caller's marker at the floor, above every row the
    /// room held, so the group mock reads the room as read and the next Mine load shows no dot for it (Kickers listed
    /// and read, the conversation hidden), and a later mark below the floor never reopens it. The marker alone is not
    /// what reads the room: a mark at the fixture's own marker, before the clear, leaves it unread.
    @Test(arguments: [MockGroupFixtures.kickersID, MockGroupFixtures.martaConversationID])
    func clearingReadsTheRoomAsRead(room: String) async throws {
        let repository = makeRepository()
        let fixtureMarker = MockChatFixtures.lastReadMessageID(for: room)
        let untouched = try await groups.group(id: room)
        #expect(untouched.hasUnread, "the fixture room starts unread")
        _ = try await repository.markRead(groupID: room, messageID: fixtureMarker)
        let marked = try await groups.group(id: room)
        #expect(marked.hasUnread, "the marker alone is not what reads the room")

        let cleared = try await repository.clearHistory(groupID: room)

        let group = try await groups.group(id: room)
        #expect(!group.hasUnread)
        #expect(group.membership?.lastReadMessageId == cleared.historyFloor)
        let mine = try await groups.groups(in: .mine, cursor: nil, near: nil).items
        #expect(!mine.contains { $0.id == room && $0.hasUnread }, "nothing in Mine counts the room towards the badge")
        let belowFloor = MockChatFixtures.newestMessageID(for: room)
        let marker = try await repository.markRead(groupID: room, messageID: belowFloor)
        #expect(marker.lastReadMessageId == cleared.historyFloor, "a mark below the floor never reopens the room")
    }

    /// A delete answers the tombstone and a repeated delete the same tombstone without a second publish, so the bus
    /// hears one `messageDeleted` and the row stays as a tombstone; an admin may delete another sender's line, which
    /// the member's refusal in the main suite complements.
    @Test func deleteIsIdempotentAndAdminsMayDelete() async throws {
        let repository = makeRepository()
        try await deletingTwiceTombstonesOnceAndPublishesOnce(in: repository)
        try await anAdminDeletesAnotherSendersLine(in: repository)
    }

    private func deletingTwiceTombstonesOnceAndPublishesOnce(in repository: MockChatRepository) async throws {
        let page = try await repository.newest(groupID: kickers).items
        let own = try #require(page.first { $0.senderUserId == "mock-apple" })
        var received: [RealtimeEnvelope] = []
        let stream = transport.subscribe(to: .room(groupID: kickers, epoch: 1))
        let reader = Task { for try await envelope in stream { received.append(envelope) } }

        let first = try await repository.delete(groupID: kickers, messageID: own.id)
        let second = try await repository.delete(groupID: kickers, messageID: own.id)

        #expect(first.isDeleted)
        #expect(second == first)
        await settle(until: { sleep.held == [AppConfig.Chat.mockEchoDelay] })
        sleep.release()
        await settle(until: { received == [.messageDeleted(groupID: kickers, id: own.id)] })
        reader.cancel()
        #expect(sleep.requested == [AppConfig.Chat.mockEchoDelay], "the replay publishes nothing")
        let after = try await repository.newest(groupID: kickers).items
        #expect(after.first { $0.id == own.id }?.isDeleted == true)
        #expect(after.count == page.count, "a tombstone stays a row")
    }

    /// In Runners, where the caller is an admin, so no identity switch is needed.
    private func anAdminDeletesAnotherSendersLine(in repository: MockChatRepository) async throws {
        let runners = MockGroupFixtures.runnersID
        let page = try await repository.newest(groupID: runners).items
        let others = try #require(page.first { $0.senderUserId != "mock-apple" && !$0.isSystem })

        let deleted = try await repository.delete(groupID: runners, messageID: others.id)

        #expect(deleted.isDeleted && deleted.id == others.id)
        let after = try await repository.newest(groupID: runners).items
        #expect(after.first { $0.id == others.id }?.isDeleted == true)
    }

    /// The same client id from another sender is refused as the backend refuses it, and the room is left as it was:
    /// no new row, the stored row keeps its sender. A fresh id from her is stored under her id (positive control).
    @Test func aReplayByAnotherSenderIsRefused() async throws {
        let repository = makeRepository()
        let mine = draft("mine", clientID: "c-9")
        _ = try await repository.send(groupID: kickers, mine)
        let count = try await repository.newest(groupID: kickers).items.count
        let marta = MockGroupFixtures.memberID(for: "Marta")
        identity.currentUserID = marta

        await #expect(throws: AppError.messageSendFailed) { try await repository.send(groupID: kickers, mine) }

        let page = try await repository.newest(groupID: kickers).items
        #expect(page.count == count)
        #expect(page.first { $0.clientMessageId == "c-9" }?.senderUserId == "mock-apple", "the row keeps its sender")
        let hers = try await repository.send(groupID: kickers, draft("hers", clientID: "c-10"))
        let stored = try await repository.newest(groupID: kickers).items.last
        #expect(hers.message.senderUserId == marta && stored == hers.message)
    }

    private func draft(_ text: String, clientID: String) -> MessageDraft {
        var message = MessageDraft(clientMessageID: clientID)
        message.text = text
        return message
    }
}
