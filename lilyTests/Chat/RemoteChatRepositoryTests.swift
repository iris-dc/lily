import Foundation
import Testing
@testable import lily

@MainActor
struct RemoteChatRepositoryTests {
    private let client = FakeAPIClient()
    private var repository: RemoteChatRepository { RemoteChatRepository(client: client) }
    private let page = MessagePage.fixture([.fixture(id: "m1")], hasMore: true, epoch: 3)

    @Test func pagesAskTheMessagesResourceWithTheirCursorsAndLimits() async throws {
        client.responses = [page, page, page]

        #expect(try await repository.newest(groupID: "g1") == page)
        _ = try await repository.older(groupID: "g1", before: "m1")
        _ = try await repository.newer(groupID: "g1", after: "m1")

        let history = String(AppConfig.Chat.historyPageSize)
        #expect(client.requests.allSatisfy { $0.method == .get && $0.path == "/api/groups/g1/messages" && $0.body == nil })
        #expect(client.requests[0].queryItems == [URLQueryItem(name: "limit", value: history)])
        #expect(client.requests[1].queryItems == [URLQueryItem(name: "before", value: "m1"),
                                                  URLQueryItem(name: "limit", value: history)])
        #expect(client.requests[2].queryItems == [URLQueryItem(name: "after", value: "m1"),
                                                  URLQueryItem(name: "limit", value: String(AppConfig.Chat.catchUpPageSize))])
    }

    @Test func sendPostsTheDraftAsThePayload() async throws {
        var draft = MessageDraft(clientMessageID: "c-1")
        draft.text = " hi "
        let sent = SentMessage(message: .fixture(id: "m1", clientMessageID: "c-1"), channelEpoch: 2)
        client.responses = [sent]

        #expect(try await repository.send(groupID: "g1", draft) == sent)
        let request = try #require(client.requests.first)
        #expect(request.method == .post && request.path == "/api/groups/g1/messages")
        #expect(request.body as? SendMessagePayload == SendMessagePayload(clientMessageId: "c-1", text: "hi"))
    }

    /// A reply names its target in the body; the stored message comes back with the backend's quote.
    @Test func sendWithAReplyNamesTheTargetInThePayload() async throws {
        var draft = MessageDraft(clientMessageID: "c-1")
        draft.text = "Here"
        draft.replyTo = .fixture(messageId: "01J8ZK7Q9X2M4N6P8R0T2V4W6Y")
        let stored = try ContractSamples.decode(ChatMessage.self, from: ContractSamples.replyMessage)
        client.responses = [SentMessage(message: stored, channelEpoch: 3)]

        let sent = try await repository.send(groupID: "g1", draft)

        #expect(sent.message.replyTo?.messageId == "01J8ZK7Q9X2M4N6P8R0T2V4W6Y" && sent.message.replyTo?.senderName == "Jonas")
        let request = try #require(client.requests.first)
        #expect(request.body as? SendMessagePayload
                == SendMessagePayload(clientMessageId: "c-1", text: "Here", replyToMessageId: "01J8ZK7Q9X2M4N6P8R0T2V4W6Y"))
    }

    @Test func deleteAndReadMarkerUseTheirResources() async throws {
        let deleted = ChatMessage.fixture(id: "m1").markingDeleted()
        client.responses = [deleted, ReadMarker(lastReadMessageId: "m1", channelEpoch: 2)]

        #expect(try await repository.delete(groupID: "g1", messageID: "m1") == deleted)
        #expect(try await repository.markRead(groupID: "g1", messageID: "m1").lastReadMessageId == "m1")

        #expect(client.requests.map(\.method) == [.delete, .put])
        #expect(client.requests.map(\.path) == ["/api/groups/g1/messages/m1", "/api/groups/g1/read"])
        #expect(client.requests[1].body as? ReadMarkerPayload == ReadMarkerPayload(messageId: "m1"))
    }

    @Test func clearHistoryDeletesTheMessagesRoute() async throws {
        let cleared = ClearedHistory(historyFloor: "01K6A0000000000000000000000", hidden: true, channelEpoch: 1)
        client.responses = [cleared]

        #expect(try await repository.clearHistory(groupID: "g1") == cleared)

        let request = try #require(client.requests.first)
        #expect(request.method == .delete && request.path == "/api/groups/g1/messages" && request.body == nil)
        #expect(try ContractSamples.decode(ClearedHistory.self, from: ContractSamples.clearedHistory) == cleared)
    }

    /// A ticket is asked for at the group's uploads route with the draft's request; the answer is the contract's ticket.
    @Test func requestUploadPostsTheUploadsRoute() async throws {
        let ticket = try ContractSamples.decode(UploadTicket.self, from: ContractSamples.uploadTicket)
        client.responses = [ticket]
        let request = AttachmentDraft.fixture().uploadRequest

        #expect(try await repository.requestUpload(groupID: "g1", request) == ticket)

        let recorded = try #require(client.requests.first)
        #expect(recorded.method == .post && recorded.path == "/api/groups/g1/uploads")
        #expect(recorded.body as? UploadRequestPayload == request)
    }

    @Test func refreshAttachmentGetsTheAttachmentRoute() async throws {
        let link = try ContractSamples.decode(AttachmentLink.self, from: ContractSamples.attachmentLink)
        client.responses = [link]

        #expect(try await repository.refreshAttachment(groupID: "g1", messageID: "m1", attachmentID: "a1") == link)

        let recorded = try #require(client.requests.first)
        #expect(recorded.method == .get && recorded.path == "/api/groups/g1/messages/m1/attachments/a1" && recorded.body == nil)
    }

    /// A send with pictures posts the refs and reads the stored message's attachments back.
    @Test func sendWithAttachmentsPostsTheRefs() async throws {
        var draft = MessageDraft(clientMessageID: "9b2f6c1e-3d4a-4f5b-8c6d-7e8f9a0b1c2d")
        draft.attachments = [.fixture(state: .uploaded(.fixture(attachmentID: "01ARYZ6S41TSV4RRFFQ69G5FB0")))]
        client.responses = [try ContractSamples.decode(SentMessage.self, from: ContractSamples.imageSentMessage)]

        let sent = try await repository.send(groupID: "g1", draft)

        #expect(sent.message.attachments.map(\.id) == ["01ARYZ6S41TSV4RRFFQ69G5FB0"] && sent.message.text == nil)
        let body = try #require(client.requests.first?.body as? SendMessagePayload)
        #expect(body.text == nil && body.attachments == [.fixture(attachmentID: "01ARYZ6S41TSV4RRFFQ69G5FB0")])
    }

    @Test func contractSamplesDecode() throws {
        let page = try ContractSamples.decode(MessagePage.self, from: ContractSamples.messagePage)
        let sent = try ContractSamples.decode(SentMessage.self, from: ContractSamples.sentMessage)
        let marker = try ContractSamples.decode(ReadMarker.self, from: ContractSamples.readMarker)

        #expect(page.items.map(\.kind) == [.text, .eventCreated] && page.hasMore && page.channelEpoch == 3)
        #expect(page.nextBefore == "01J8ZK7Q9X2M4N6P8R0T2V4W6Y" && page.nextAfter == nil)
        #expect(sent.message.id == "01J8ZK7Q9X2M4N6P8R0T2V4W6Y" && sent.channelEpoch == 3)
        #expect(marker.lastReadMessageId == "01J8ZK7Q9X2M4N6P8R0T2V4W6Y" && marker.channelEpoch == 3)
    }

    /// A backend that names no continuation cursors still decodes; paging then falls back to the ids held.
    @Test func aPageWithoutCursorsDecodes() throws {
        let page = try ContractSamples.decode(MessagePage.self, from: ContractSamples.messagePageWithoutCursors)

        #expect(page.nextBefore == nil && page.nextAfter == nil && page.hasMore && page.items.count == 1)
    }

    nonisolated private static let codeCases: [(code: String, expected: AppError)] = [
        ("NOT_A_MEMBER", .notAMember), ("GROUP_NOT_FOUND", .groupNotFound), ("CONTENT_REJECTED", .contentRejected),
        ("TERMS_REQUIRED", .termsRequired), ("MESSAGE_NOT_FOUND", .messageNotFound), ("TRY_AGAIN", .tryAgain),
        ("VALIDATION_FAILED", .messageSendFailed), ("REPLY_TARGET_NOT_FOUND", .replyTargetNotFound),
        ("ATTACHMENT_NOT_FOUND", .attachmentNotFound), ("ATTACHMENT_TOO_LARGE", .attachmentTooLarge),
        ("ATTACHMENT_TYPE_NOT_ALLOWED", .attachmentTypeNotAllowed), ("ATTACHMENTS_DISABLED", .attachmentsDisabled),
    ]

    @Test(arguments: codeCases)
    func backendCodesMapToAppErrors(code: String, expected: AppError) async {
        client.error = APIError.http(status: 400, body: APIErrorBody(code: code, message: "m"))
        await #expect(throws: expected) { try await repository.send(groupID: "g1", MessageDraft()) }
    }

    /// A 429 carries how long to wait; the composer's cooldown reads it.
    @Test func rateLimitCarriesRetryAfter() async {
        client.error = APIError.http(status: 429, body: APIErrorBody(code: "RATE_LIMITED", message: "m"), retryAfter: 7)
        await #expect(throws: AppError.rateLimited(retryAfter: 7)) { try await repository.send(groupID: "g1", MessageDraft()) }
    }

    @Test func unnamedFailuresFallBackPerRoute() async {
        for error in [APIError.http(status: 500, body: nil), .decodingFailed] {
            client.error = error
            await #expect(throws: AppError.chatUnavailable) { try await repository.newest(groupID: "g1") }
            await #expect(throws: AppError.chatUnavailable) { try await repository.newer(groupID: "g1", after: "m1") }
            await #expect(throws: AppError.messageSendFailed) { try await repository.send(groupID: "g1", MessageDraft()) }
            await #expect(throws: AppError.chatUnavailable) { try await repository.markRead(groupID: "g1", messageID: "m1") }
            await #expect(throws: AppError.chatUnavailable) { try await repository.clearHistory(groupID: "g1") }
            await #expect(throws: AppError.attachmentUploadFailed) {
                try await repository.requestUpload(groupID: "g1", AttachmentDraft.fixture().uploadRequest)
            }
            await #expect(throws: AppError.attachmentUnavailable) {
                try await repository.refreshAttachment(groupID: "g1", messageID: "m1", attachmentID: "a1")
            }
        }
        client.error = URLError(.notConnectedToInternet)
        await #expect(throws: AppError.network) { try await repository.send(groupID: "g1", MessageDraft()) }
    }
}
