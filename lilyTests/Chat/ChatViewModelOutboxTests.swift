import Foundation
import Testing
@testable import lily

/// The shared outbox: an unsent or failed bubble outlives the screen (every open builds a new view model), Retry acts
/// on a failed bubble once, a clear from the Chats row and a sign-out take the bubbles and their files with them.
@MainActor
struct ChatViewModelOutboxTests {
    private let group = SportGroup.fixture(id: "g", channelEpoch: 1, role: .member)
    private let first = ChatMessage.fixture(id: "m1")

    private func makeOpenChat() async -> (RealtimeHarness, ChatViewModel) {
        let harness = RealtimeHarness()
        harness.groups.result = .success([group])
        harness.cache.store(.fixture(messages: [first]), for: "g")
        await harness.connect()
        let viewModel = harness.makeChatViewModel(for: group)
        await viewModel.appear()
        viewModel.draft.text = "hello"
        return (harness, viewModel)
    }

    private func startHeldSend(_ viewModel: ChatViewModel,
                               in harness: RealtimeHarness) async throws -> (send: Task<Void, Never>, clientID: String) {
        harness.chat.holdsRequests = true
        let send = Task { await viewModel.send() }
        await settle(until: { harness.chat.sentDrafts.count == 1 })
        return (send, try #require(viewModel.pending.first).clientMessageID)
    }

    /// A refusal that lands after Back is a failed bubble with Retry on the next open, not a mark on a screen nobody
    /// shows; the retry sends the same client id and the stored message replaces the bubble.
    @Test func aFailedSendSurvivesLeavingTheRoom() async throws {
        let (harness, viewModel) = await makeOpenChat()
        let (send, clientID) = try await startHeldSend(viewModel, in: harness)
        await viewModel.cancel()
        harness.chat.sendErrors = [AppError.contentRejected]
        harness.chat.releaseRequests()
        await send.value
        #expect(harness.errorCenter.current?.error == .contentRejected)

        let reopened = harness.makeChatViewModel(for: group)
        await reopened.appear()
        #expect(reopened.pending.map(\.clientMessageID) == [clientID] && reopened.pending.map(\.hasFailed) == [true])
        #expect(reopened.rows.last?.id == clientID)

        await reopened.retry(try #require(reopened.pending.first))

        #expect(reopened.pending.isEmpty && harness.outbox.messages(in: "g").isEmpty)
        #expect(reopened.room.messages.map(\.id) == ["m1", "sent-1"])
        #expect(harness.chat.sentDrafts.map(\.clientMessageID) == [clientID, clientID])
    }

    /// A send still on its way when the room is reopened shows as sending there and settles on that screen.
    @Test func aSendingBubbleIsStillShownOnTheNextOpen() async throws {
        let (harness, viewModel) = await makeOpenChat()
        let (send, clientID) = try await startHeldSend(viewModel, in: harness)
        await viewModel.cancel()

        let reopened = harness.makeChatViewModel(for: group)
        let reappear = Task { await reopened.appear() }
        await settle(until: { harness.chat.newerRequests.count == 2 }) // the reopen's catch-up is parked like the send
        #expect(reopened.pending.map(\.state) == [.sending] && reopened.rows.last?.id == clientID)

        harness.chat.releaseRequests()
        await send.value
        await reappear.value

        #expect(reopened.pending.isEmpty)
        #expect(reopened.room.messages.map(\.id) == ["m1", "sent-1"])
        #expect(reopened.room.messages.last?.clientMessageId == clientID)
    }

    /// A second tap landing before the first re-rendered finds the bubble sending and sends nothing more.
    @Test func aSecondRetryWhileTheFirstIsInFlightSendsNothingMore() async throws {
        let (harness, viewModel) = await makeOpenChat()
        harness.chat.sendErrors = [AppError.messageSendFailed]
        await viewModel.send()
        let bubble = try #require(viewModel.pending.first)
        #expect(bubble.hasFailed)
        harness.chat.holdsRequests = true

        let firstRetry = Task { await viewModel.retry(bubble) }
        await settle(until: { harness.chat.sentDrafts.count == 2 })
        #expect(viewModel.pending.map(\.state) == [.sending])
        let secondRetry = Task { await viewModel.retry(bubble) }
        await harness.yield()
        #expect(harness.chat.sentDrafts.count == 2, "the second tap sends nothing more")

        harness.chat.releaseRequests()
        await firstRetry.value
        await secondRetry.value
        #expect(viewModel.pending.isEmpty && viewModel.room.messages.map(\.id) == ["m1", "sent-1"])
    }

    @Test func retryOfABubbleNotFailedIsANoOp() async {
        let (harness, viewModel) = await makeOpenChat()
        let sending = PendingMessage(draft: MessageDraft(), sentAt: harness.clock.now)
        viewModel.pending.append(sending)

        await viewModel.retry(sending)

        #expect(harness.chat.sentDrafts.isEmpty)
        #expect(viewModel.pending.map(\.state) == [.sending])
    }

    /// The Chats row's clear reaches the room's bubbles without a view model: the failed picture and its files go,
    /// another room's bubble stays.
    @Test func clearingTheRoomFromOutsideDropsItsUnsentBubbles() async throws {
        let (harness, viewModel) = await makeOpenChat()
        viewModel.attachments.add(imageData: Data(repeating: 1, count: 300))
        await settle(until: { viewModel.canSend })
        let files = try #require(viewModel.attachments.drafts.first).localFiles
        harness.chat.sendErrors = [AppError.contentRejected]
        await viewModel.send()
        #expect(viewModel.pending.map(\.hasFailed) == [true])
        #expect(files.allSatisfy { FileManager.default.fileExists(atPath: $0.path()) })
        let other = PendingMessage(draft: MessageDraft(), sentAt: harness.clock.now)
        harness.outbox.replace([other], in: "other")
        await viewModel.cancel()

        #expect(await harness.clearer.clear(group) != nil)

        #expect(harness.outbox.messages(in: "g").isEmpty)
        #expect(files.allSatisfy { !FileManager.default.fileExists(atPath: $0.path()) }, "the files went with the bubble")
        #expect(harness.outbox.messages(in: "other").map(\.id) == [other.id], "another room's bubble stays")
    }

    /// One account's unsent pictures must not stay on the device for the next.
    @Test func signingOutDiscardsEveryRoomsBubbles() throws {
        let outbox = ChatOutbox()
        let file = FileManager.default.temporaryDirectory.appending(path: "outbox-\(UUID().uuidString).jpg")
        try Data([1]).write(to: file)
        var pictured = MessageDraft()
        pictured.attachments = [.fixture(fileURL: file)]
        outbox.replace([PendingMessage(draft: pictured, sentAt: Date())], in: "a")
        outbox.replace([PendingMessage(draft: MessageDraft(), sentAt: Date())], in: "b")

        outbox.sessionDidEnd()

        #expect(outbox.messages(in: "a").isEmpty && outbox.messages(in: "b").isEmpty)
        #expect(!FileManager.default.fileExists(atPath: file.path()), "the picture left the device with the bubble")
    }
}
