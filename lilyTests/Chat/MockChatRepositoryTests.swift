import Foundation
import Testing
@testable import lily

@MainActor
struct MockChatRepositoryTests {
    private let identity = FakeIdentityProvider(currentUserID: "mock-apple")
    private let logger = SpyLogger()
    private let sleep = HeldSleep()
    private let transport: MockRealtimeTransport
    private let groups: MockGroupRepository
    private let kickers = MockGroupFixtures.kickersID

    init() {
        transport = MockRealtimeTransport(logger: logger)
        groups = MockGroupRepository(identity: identity, logger: logger)
    }

    private func makeRepository(autoReplies: Bool = false) -> MockChatRepository {
        MockChatRepository(groups: groups,
                           transport: transport,
                           identity: identity,
                           logger: logger,
                           autoReplies: autoReplies,
                           now: { Date(timeIntervalSince1970: 1_800_000_000) },
                           sleep: { [sleep] in try await sleep.sleep(for: $0) })
    }

    @Test func joinedRoomsHaveTheirFixtureRowsInOrder() async throws {
        let page = try await makeRepository().newest(groupID: kickers)

        #expect(page.items.count == AppConfig.Chat.mockMessagesPerRoom + 1 && !page.hasMore && page.channelEpoch == 1)
        #expect(page.items.map(\.id) == page.items.map(\.id).sorted())
        #expect(page.items.last?.id == MockChatFixtures.newestMessageID(for: kickers))
        #expect(page.items.contains { $0.kind == .eventCreated && $0.eventId == "mock-event-0" })
        #expect(page.items.contains { $0.senderUserId == "mock-apple" && $0.senderName == "You" })
        #expect(page.items.contains { $0.id == MockChatFixtures.lastReadMessageID(for: kickers) })
    }

    /// The group fixtures point at rows that exist here, so the unread dot and the resume protocol see real ids.
    @Test func groupFixturesNameTheChatFixturesIds() {
        let kickersGroup = MockGroupFixtures.make(now: .now).first { $0.id == kickers }
        #expect(kickersGroup?.lastMessageId == MockChatFixtures.newestMessageID(for: kickers))
        #expect(kickersGroup?.membership?.lastReadMessageId == MockChatFixtures.lastReadMessageID(for: kickers))
        #expect(kickersGroup?.hasUnread == true)
        #expect(MockChatFixtures.messageID(groupID: kickers, index: 12) > MockChatFixtures.messageID(groupID: kickers, index: 9))
    }

    /// The conversation with Marta has lines of its own: hers and the caller's in turn, no system row, her last three
    /// unread, ending two hours before the launch; the group fixture points at them.
    @Test func theConversationWithMartaHasItsOwnLines() async throws {
        let conversation = MockGroupFixtures.martaConversationID
        let marta = MockGroupFixtures.conversationCounterpart.userId

        let page = try await makeRepository().newest(groupID: conversation)

        #expect(page.items.count == 6 && !page.hasMore && page.channelEpoch == 1)
        #expect(Set(page.items.map(\.senderUserId)) == [marta, "mock-apple"])
        #expect(page.items.first?.text == "Hey! Are you coming on Sunday?")
        #expect(page.items.allSatisfy { !$0.isSystem } && page.items.suffix(3).allSatisfy { $0.senderUserId == marta })
        #expect(page.items.last?.id == MockChatFixtures.newestMessageID(for: conversation))
        #expect(page.items[2].id == MockChatFixtures.lastReadMessageID(for: conversation), "the last read line is the caller's")
        let end = Date(timeIntervalSince1970: 1_800_000_000 - MockChatFixtures.conversationLastMessageAge)
        #expect(page.items.last?.sentAt == end && page.items.map(\.sentAt) == page.items.map(\.sentAt).sorted())
    }

    @Test func pagingFollowsTheIds() async throws {
        let repository = makeRepository()
        let all = try await repository.newest(groupID: kickers).items

        let older = try await repository.older(groupID: kickers, before: all[3].id)
        let newer = try await repository.newer(groupID: kickers, after: all[10].id)

        #expect(older.items.map(\.id) == all[..<3].map(\.id) && !older.hasMore)
        #expect(newer.items.map(\.id) == all[11...].map(\.id) && !newer.hasMore)
    }

    @Test func outsidersGetNoRoom() async {
        let repository = makeRepository()
        await #expect(throws: AppError.notAMember) { try await repository.newest(groupID: MockGroupFixtures.basketballID) }
        await #expect(throws: AppError.groupNotFound) { try await repository.newest(groupID: MockGroupFixtures.climbingID) }
    }

    @Test func sendStoresAndEchoesOverTheBusAndReplaysTheSameClientId() async throws {
        let repository = makeRepository()
        var draft = MessageDraft(clientMessageID: "c-1")
        draft.text = "hi"
        var received: [RealtimeEnvelope] = []
        let stream = transport.subscribe(to: .room(groupID: kickers, epoch: 1))
        let reader = Task { for try await envelope in stream { received.append(envelope) } }

        let sent = try await repository.send(groupID: kickers, draft)
        let replay = try await repository.send(groupID: kickers, draft)

        #expect(sent.message.text == "hi" && sent.message.senderUserId == "mock-apple" && replay.message == sent.message)
        #expect(sent.message.id > MockChatFixtures.newestMessageID(for: kickers))
        await settle(until: { sleep.held == [AppConfig.Chat.mockEchoDelay] })
        sleep.release()
        await settle(until: { received == [.message(sent.message)] })
        reader.cancel()
        #expect(try await repository.newest(groupID: kickers).items.last == sent.message)
    }

    @Test func theFailingPrefixMakesASendFailLikeALostConnection() async throws {
        let repository = makeRepository()
        var draft = MessageDraft()
        draft.text = AppConfig.Chat.mockFailingPrefix + " this one"

        await #expect(throws: AppError.network) { try await repository.send(groupID: kickers, draft) }
        let page = try await repository.newest(groupID: kickers)
        #expect(!page.items.contains { $0.clientMessageId == draft.clientMessageID },
                "never stored, so a catch-up cannot find it")
    }

    /// The demo flag deepens every room so paging and long scrolls can be tried by hand.
    @Test func autoRepliesDeepenTheRoomsPastOnePage() async throws {
        let repository = makeRepository(autoReplies: true)

        let newest = try await repository.newest(groupID: kickers)
        #expect(newest.items.count == AppConfig.Chat.historyPageSize && newest.hasMore)
        let older = try await repository.older(groupID: kickers, before: newest.items[0].id)
        #expect(older.items.count == AppConfig.Chat.historyPageSize && older.hasMore)
        #expect(older.items.last!.id < newest.items[0].id)
        #expect(!makeRepository().autoReplies, "the default room keeps its fixture size")
    }

    @Test func autoRepliesMakeMartaAnswerAfterTheDelay() async throws {
        let repository = makeRepository(autoReplies: true)
        var draft = MessageDraft()
        draft.text = "anyone?"

        _ = try await repository.send(groupID: kickers, draft)
        await settle(until: { sleep.held.contains(AppConfig.Chat.mockAutoReplyDelay) })
        sleep.release { $0 == AppConfig.Chat.mockAutoReplyDelay }
        await settle(until: { sleep.requested.count == 3 })

        let newest = try await repository.newest(groupID: kickers).items.last
        #expect(newest?.senderName == "Marta" && newest?.text == MockChatFixtures.replies[0])
    }

    @Test func deleteTombstonesAndReadMarkerIsMonotonic() async throws {
        let repository = makeRepository()
        let own = try #require(try await repository.newest(groupID: kickers).items.first { $0.senderUserId == "mock-apple" })
        let others = try await repository.newest(groupID: kickers).items.first { $0.senderUserId != "mock-apple" && !$0.isSystem }
        let othersID = try #require(others?.id)

        #expect(try await repository.delete(groupID: kickers, messageID: own.id).isDeleted)
        await #expect(throws: AppError.insufficientRole) { try await repository.delete(groupID: kickers, messageID: othersID) }
        await #expect(throws: AppError.messageNotFound) { try await repository.delete(groupID: kickers, messageID: "nope") }

        #expect(try await repository.markRead(groupID: kickers, messageID: "b").lastReadMessageId == "b")
        #expect(try await repository.markRead(groupID: kickers, messageID: "a").lastReadMessageId == "b")
    }
}
