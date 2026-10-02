import Foundation
import Testing
@testable import lily

/// Sending: the optimistic bubble, the echo, unknown outcomes, retries and the rate-limit cooldown.
@MainActor
struct ChatViewModelSendTests {
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

    @Test func sendShowsTheBubbleThenTheStoredMessageAndDedupesTheEcho() async {
        let (harness, viewModel) = await makeOpenChat()
        let clientID = viewModel.draft.clientMessageID

        await viewModel.send()

        #expect(viewModel.pending.isEmpty && viewModel.draft.text.isEmpty)
        #expect(viewModel.room.messages.map(\.id) == ["m1", "sent-1"])
        #expect(viewModel.room.messages.last?.clientMessageId == clientID)
        #expect(harness.chat.readMarks.map(\.messageID) == ["m1"], "own message: marker waits for the interval")
        #expect(harness.logger.messages(in: .chat, at: .info).contains("Message sent sent-1 in group g"))

        harness.transport.post(.message(viewModel.room.messages[1]), to: .room(groupID: "g", epoch: 1))
        await harness.yield()
        #expect(viewModel.room.messages.count == 2)
    }

    @Test func anEchoBeforeTheAnswerReplacesTheBubble() async {
        let (harness, viewModel) = await makeOpenChat()
        let clientID = viewModel.draft.clientMessageID
        harness.chat.holdsRequests = true

        let send = Task { await viewModel.send() }
        await settle(until: { viewModel.pending.count == 1 && harness.chat.sentDrafts.count == 1 })
        #expect(viewModel.rows.last?.id == clientID)

        let echoed = ChatMessage.fixture(id: "m2", senderUserID: TestFixtures.user.id, text: "hello", clientMessageID: clientID)
        harness.transport.post(.message(echoed), to: .room(groupID: "g", epoch: 1))
        await settle(until: { viewModel.pending.isEmpty })
        harness.chat.releaseRequests()
        await send.value

        #expect(viewModel.room.messages.map(\.id) == ["m1", "m2", "sent-1"] || viewModel.room.messages.map(\.id) == ["m1", "m2"])
    }

    /// The backend commits before it answers: a lost answer is settled by the catch-up finding the client id.
    @Test func anUnknownOutcomeIsResolvedByTheCatchUp() async {
        let (harness, viewModel) = await makeOpenChat()
        let clientID = viewModel.draft.clientMessageID
        harness.chat.sendErrors = [AppError.network]
        let landed = ChatMessage.fixture(id: "m2", senderUserID: TestFixtures.user.id, text: "hello", clientMessageID: clientID)
        harness.chat.newerPages = [.fixture([landed])]

        await viewModel.send()

        #expect(viewModel.pending.isEmpty && harness.errorCenter.current == nil)
        #expect(harness.chat.newerRequests.map(\.after) == ["m1", "m1"])
        let warning = "Send outcome unknown for \(clientID) in group g; catching up"
        #expect(harness.logger.messages(in: .chat, at: .warning).contains(warning))
        #expect(harness.logger.messages(in: .chat, at: .info).contains { $0.hasPrefix("Send landed for \(clientID)") })
    }

    @Test func aFailedSendOffersRetryWithTheSameClientId() async {
        let (harness, viewModel) = await makeOpenChat()
        harness.chat.sendErrors = [AppError.messageSendFailed]

        await viewModel.send()
        #expect(viewModel.pending.map(\.hasFailed) == [true])
        #expect(harness.errorCenter.current?.error == .messageSendFailed)
        #expect(harness.logger.messages(in: .chat, at: .error).contains("Send failed in group g: messageSendFailed"))

        await viewModel.retry(viewModel.pending[0])

        #expect(harness.chat.sentDrafts.map(\.clientMessageID).count == 2)
        #expect(harness.chat.sentDrafts[0].clientMessageID == harness.chat.sentDrafts[1].clientMessageID)
        #expect(viewModel.pending.isEmpty && viewModel.room.messages.count == 2)
    }

    /// The sender's own overlapping writes race on the backend; one repeat with the same client id settles it.
    @Test func aLostRaceIsRepeatedOnceWithTheSameClientId() async {
        let (harness, viewModel) = await makeOpenChat()
        harness.chat.sendErrors = [AppError.tryAgain]

        await viewModel.send()

        let clientIDs = harness.chat.sentDrafts.map(\.clientMessageID)
        #expect(clientIDs.count == 2 && Set(clientIDs).count == 1, "one repeat, the same client id")
        #expect(viewModel.pending.isEmpty && viewModel.room.messages.count == 2 && harness.errorCenter.current == nil)
        #expect(harness.logger.messages(in: .chat, at: .info).contains("Send lost a race in group g; retrying once"))
    }

    @Test func aSecondLostRaceFailsLikeAnyRefusal() async {
        let (harness, viewModel) = await makeOpenChat()
        harness.chat.sendErrors = [AppError.tryAgain, AppError.tryAgain]

        await viewModel.send()

        #expect(harness.chat.sentDrafts.count == 2 && viewModel.pending.map(\.hasFailed) == [true])
        #expect(harness.errorCenter.current?.error == .tryAgain)
    }

    /// A send refused for outdated terms shows the popup and raises the terms sheet, as on the groups screens.
    @Test func aTermsRequiredOnSendRaisesTheTermsSheet() async {
        let (harness, viewModel) = await makeOpenChat()
        harness.chat.sendErrors = [AppError.termsRequired]

        await viewModel.send()

        #expect(viewModel.pending.map(\.hasFailed) == [true])
        #expect(harness.errorCenter.current?.error == .termsRequired && harness.termsRequiredCount == 1)
    }

    @Test func discardDropsAFailedBubble() async {
        let (harness, viewModel) = await makeOpenChat()
        harness.chat.sendErrors = [AppError.contentRejected]
        await viewModel.send()
        #expect(harness.errorCenter.current?.error == .contentRejected)

        viewModel.discard(viewModel.pending[0])

        #expect(viewModel.pending.isEmpty)
    }

    @Test func aRateLimitClosesTheComposerForRetryAfter() async {
        let (harness, viewModel) = await makeOpenChat()
        harness.chat.sendErrors = [AppError.rateLimited(retryAfter: 7)]

        await viewModel.send()

        #expect(viewModel.isCoolingDown && viewModel.cooldownSeconds == 7 && viewModel.pending.map(\.hasFailed) == [true])
        viewModel.draft.text = "again"
        #expect(!viewModel.canSend)
        await viewModel.retry(viewModel.pending[0])
        #expect(harness.chat.sentDrafts.count == 1, "no retry while cooling down")

        harness.clock.advance(by: 7)
        #expect(!viewModel.isCoolingDown && viewModel.cooldownSeconds == nil && viewModel.canSend)
    }

    @Test func aRateLimitWithoutRetryAfterUsesTheFallback() async {
        let (harness, viewModel) = await makeOpenChat()
        harness.chat.sendErrors = [AppError.rateLimited(retryAfter: nil)]

        await viewModel.send()

        #expect(viewModel.cooldownSeconds == Int(AppConfig.Chat.rateLimitCooldownFallback))
    }

    /// A lost `member_left` is learned from the send's answer: resubscribe to the new epoch, then catch up.
    @Test func lostMemberLeftConvergesOnNextSend() async {
        let (harness, viewModel) = await makeOpenChat()
        harness.chat.responseEpoch = 2

        await viewModel.send()

        #expect(harness.controller.subscribedRooms["g"] == 2 && viewModel.subscribedEpoch == 2)
        #expect(harness.chat.newerRequests.count == 2, "one catch-up on appear, one after the epoch change")
        #expect(harness.logger.messages(in: .chat, at: .info).contains("Epoch changed for group g: 1 -> 2"))
        await harness.yield()
        #expect(!harness.transport.subscribedChannels.contains(.room(groupID: "g", epoch: 1)))
    }

    /// A picture without words: Send waits for the upload, the bubble previews the picked file, the stored message
    /// carries the attachment, and its files seed the cache under the stored id.
    @Test func anImageOnlySendShowsPendingBubbleThenStoredOne() async throws {
        let (harness, viewModel) = await makeOpenChat()
        viewModel.draft.text = ""
        harness.uploader.holdsRequests = true
        viewModel.attachments.add(imageData: Data(repeating: 1, count: 300))
        await settle(until: { harness.uploader.inFlight == 1 })
        #expect(!viewModel.canSend && viewModel.attachments.isBusy, "no send while the picture is on its way")

        harness.uploader.releaseRequests()
        await settle(until: { viewModel.canSend })
        harness.chat.holdsRequests = true
        let send = Task { await viewModel.send() }
        await settle(until: { viewModel.pending.count == 1 && harness.chat.sentDrafts.count == 1 })
        let bubble = viewModel.pending[0]
        #expect(bubble.text.isEmpty && bubble.attachments.map { $0.uploadedRef?.attachmentId } == ["att-1"])
        #expect(viewModel.attachments.isEmpty, "the composer starts over as soon as the send leaves")
        #expect(harness.chat.sentDrafts[0].payload.text == nil && harness.chat.sentDrafts[0].payload.attachments?.count == 1)
        harness.chat.releaseRequests()
        await send.value

        let stored = try #require(viewModel.room.messages.last)
        #expect(viewModel.pending.isEmpty && stored.text == nil && stored.attachments.map(\.id) == ["att-1"])
        #expect(harness.attachmentCache.copied.map(\.id) == ["att-1", "att-1"], "the sent files seed the cache")
        #expect(harness.attachmentCache.fileURL(for: "att-1", variant: .thumbnail) != nil)
    }

    @Test func aSendWhileGoneOrBlankIsIgnored() async {
        let (harness, viewModel) = await makeOpenChat()
        viewModel.draft.text = "   "
        await viewModel.send()
        #expect(harness.chat.sentDrafts.isEmpty)

        viewModel.draft.text = "hello"
        viewModel.isGone = true
        await viewModel.send()
        #expect(harness.chat.sentDrafts.isEmpty)
    }
}
