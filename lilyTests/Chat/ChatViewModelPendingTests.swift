import Foundation
import Testing
@testable import lily

/// The optimistic bubbles: whichever of the answer, the live echo or a catch-up brings the stored message, the bubble's
/// files seed the cache before the bubble goes; a discarded bubble takes its files with it; Retry finds a bubble by its
/// client id and sends the bubble's own draft.
@MainActor
struct ChatViewModelPendingTests {
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

    /// One picture, prepared and uploaded, so the send can leave with it.
    private func attachPicture(to viewModel: ChatViewModel) async {
        viewModel.attachments.add(imageData: Data(repeating: 1, count: 300))
        await settle(until: { viewModel.canSend })
    }

    /// The stored form of the send under `clientID`: the words with the picture under the id the uploader gave it.
    private func stored(_ clientID: String) -> ChatMessage {
        ChatMessage.fixture(id: "m2",
                            senderUserID: TestFixtures.user.id,
                            text: "hello",
                            clientMessageID: clientID,
                            attachments: [.fixture(id: "att-1")])
    }

    /// A lost answer whose catch-up finds the message: the bubble's files seed the cache before the bubble goes, so the
    /// picture never downloads.
    @Test func aLandedCatchUpSeedsTheCacheBeforeTheBubbleGoes() async {
        let (harness, viewModel) = await makeOpenChat()
        await attachPicture(to: viewModel)
        let clientID = viewModel.draft.clientMessageID
        harness.chat.sendErrors = [AppError.network]
        harness.chat.newerPages = [.fixture([stored(clientID)])]

        await viewModel.send()

        #expect(viewModel.pending.isEmpty && harness.errorCenter.current == nil)
        #expect(harness.attachmentCache.copied.map(\.id) == ["att-1", "att-1"])
        #expect(harness.attachmentCache.copied.map(\.variant) == [.full, .thumbnail])
        #expect(harness.logger.messages(in: .chat, at: .info).contains { $0.hasPrefix("Send landed for \(clientID)") })
    }

    @Test func theLiveEchoSeedsTheCacheForAnOwnAttachment() async {
        let (harness, viewModel) = await makeOpenChat()
        await attachPicture(to: viewModel)
        let clientID = viewModel.draft.clientMessageID
        harness.chat.holdsRequests = true

        let send = Task { await viewModel.send() }
        await settle(until: { viewModel.pending.count == 1 && harness.chat.sentDrafts.count == 1 })
        harness.transport.post(.message(stored(clientID)), to: .room(groupID: "g", epoch: 1))
        await settle(until: { viewModel.pending.isEmpty })
        #expect(harness.attachmentCache.copied.map(\.id) == ["att-1", "att-1"])

        harness.chat.releaseRequests()
        await send.value

        #expect(harness.attachmentCache.copied.count == 2, "the answer finds no bubble and seeds nothing twice")
    }

    @Test func aDiscardedPendingMessageDeletesItsFiles() async throws {
        let (harness, viewModel) = await makeOpenChat()
        await attachPicture(to: viewModel)
        let files = try #require(viewModel.attachments.drafts.first).localFiles
        harness.chat.sendErrors = [AppError.contentRejected]

        await viewModel.send()
        #expect(viewModel.pending.map(\.hasFailed) == [true])
        #expect(files.allSatisfy { FileManager.default.fileExists(atPath: $0.path()) }, "a failed bubble keeps them for Retry")

        viewModel.discard(try #require(viewModel.pending.first))

        #expect(viewModel.pending.isEmpty)
        #expect(files.allSatisfy { !FileManager.default.fileExists(atPath: $0.path()) })
    }

    /// The view hands Retry the bubble it drew, which still quotes the original after `REPLY_TARGET_NOT_FOUND` stripped
    /// the stored bubble's quote; the stale copy still names the bubble by its client id, and the stored bubble's plain
    /// draft is what goes out, not the copy's.
    @Test func retryHandedAStaleCopySendsTheStoredBubblesDraft() async throws {
        let (harness, viewModel) = await makeOpenChat()
        viewModel.draft.replyTo = ReplyQuote(quoting: first, senderName: "Marta")
        let drawn = PendingMessage(draft: viewModel.draft, sentAt: Date())
        harness.chat.sendErrors = [AppError.replyTargetNotFound]
        await viewModel.send()
        let stored = try #require(viewModel.pending.first)
        #expect(stored.hasFailed && stored.replyTo == nil, "the model dropped the quote")
        #expect(drawn.replyTo != nil && drawn.clientMessageID == stored.clientMessageID, "the view's copy still has it")

        await viewModel.retry(drawn)

        let clientIDs = harness.chat.sentDrafts.map(\.clientMessageID)
        #expect(clientIDs == [drawn.clientMessageID, drawn.clientMessageID], "a stale copy still names the bubble")
        #expect(harness.chat.sentDrafts.map { $0.replyTo == nil } == [false, true], "the stored bubble's draft went")
        #expect(viewModel.pending.isEmpty)
    }
}
