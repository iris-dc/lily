import Foundation
import Testing
@testable import lily

/// The mock's attachments, an extension of the main suite like the reply cases: a ticket, the mock uploader, a send
/// that names the upload and a page that carries it with `mock://` links the mock protocol serves; a video and a file
/// the same way; the refusals the backend would answer.
extension MockChatRepositoryTests {
    private var photo: Data { Data(repeating: 3, count: 64) }

    /// A draft of `kind` whose files hold a few bytes, uploaded through the mock uploader without the paced sleep.
    private func upload(_ kind: AttachmentKind,
                        _ repository: MockChatRepository,
                        store: MockAttachmentStore) async throws -> AttachmentDraft {
        let directory = FileManager.default.temporaryDirectory
        let id = "\(kind.rawValue)-\(UUID().uuidString)"
        let fileURL = directory.appending(path: "\(id).bin")
        try Data(repeating: 5, count: 48).write(to: fileURL)
        let draft = AttachmentDraft.fixture(id: id, kind: kind, fileURL: fileURL, state: .preparing)
        if let thumbnailURL = draft.thumbnailURL { try Data("thumb".utf8).write(to: thumbnailURL) }
        let ticket = try await repository.requestUpload(groupID: kickers, draft.uploadRequest)
        try await MockAttachmentUploader(store: store) { _ in }.upload(draft, with: ticket) { _ in }
        return draft.updating(state: .uploaded(draft.ref(attachmentID: ticket.attachmentId)))
    }

    /// The ticket, the upload (progress in steps over the held sleep) and the send, end to end.
    private func sendPhoto(_ repository: MockChatRepository,
                           store: MockAttachmentStore,
                           text: String = "") async throws -> SentMessage {
        let draft = try AttachmentDraft.prepared(id: "pic-\(UUID().uuidString)", data: photo)
        let ticket = try await repository.requestUpload(groupID: kickers, draft.uploadRequest)
        let uploader = MockAttachmentUploader(store: store) { [sleep] in try await sleep.sleep(for: $0) }
        var progress: [Double] = []
        let upload = Task { try await uploader.upload(draft, with: ticket) { progress.append($0) } }
        for _ in 0..<AppConfig.Chat.Attachments.mockUploadSteps {
            await settle(until: { !sleep.held.isEmpty })
            sleep.release()
        }
        try await upload.value
        #expect(progress == [0.25, 0.5, 0.75, 1])
        var message = MessageDraft()
        message.text = text
        message.attachments = [draft.updating(state: .uploaded(draft.ref(attachmentID: ticket.attachmentId)))]
        return try await repository.send(groupID: kickers, message)
    }

    @Test func aTicketAnUploadAndASendPutThePictureOnThePage() async throws {
        let store = MockAttachmentStore()
        let repository = makeRepository(attachments: store)

        let sent = try await sendPhoto(repository, store: store)

        let attachment = try #require(sent.message.attachments.first)
        #expect(sent.message.text == nil && attachment.kind == .image && attachment.sizeBytes == 64)
        #expect(attachment.url.scheme == "mock" && attachment.url.path() == "/\(attachment.id)")
        #expect(attachment.thumbnailUrl?.path() == "/\(attachment.id)/thumb")
        #expect(store.data(for: attachment.id, variant: .full) == photo)
        #expect(store.data(for: attachment.id, variant: .thumbnail) != nil)
        #expect(try await repository.newest(groupID: kickers).items.last?.attachments == [attachment])
        let issued = "Mock upload ticket \(attachment.id) issued in group \(kickers)"
        #expect(logger.messages(in: .chat, at: .debug).contains(issued))

        let link = try await repository.refreshAttachment(groupID: kickers,
                                                          messageID: sent.message.id,
                                                          attachmentID: attachment.id)
        #expect(link.url == attachment.url && link.thumbnailUrl == attachment.thumbnailUrl)
    }

    /// The protocol the loader's session speaks: 200 with the bytes for an uploaded object, 404 for anything else.
    @Test func theMockProtocolServesTheStore() async throws {
        let store = MockAttachmentStore()
        let repository = makeRepository(attachments: store)
        let sent = try await sendPhoto(repository, store: store)
        let attachment = try #require(sent.message.attachments.first)
        MockAttachmentURLProtocol.serve(store)
        let session = MockAttachmentURLProtocol.makeSession()

        let (data, response) = try await session.data(from: attachment.url)
        let (_, missing) = try await session.data(from: store.url(of: "nothing", variant: .full))

        #expect(data == photo && (response as? HTTPURLResponse)?.statusCode == 200)
        #expect((missing as? HTTPURLResponse)?.statusCode == 404)
    }

    @Test func aRefThatWasNeverUploadedIsRefused() async throws {
        let store = MockAttachmentStore()
        let repository = makeRepository(attachments: store)
        let draft = try AttachmentDraft.prepared(id: "pic-2", data: photo)
        let ticket = try await repository.requestUpload(groupID: kickers, draft.uploadRequest)
        var message = MessageDraft()
        message.attachments = [draft.updating(state: .uploaded(draft.ref(attachmentID: ticket.attachmentId)))]

        await #expect(throws: AppError.attachmentNotFound) { try await repository.send(groupID: kickers, message) }

        message.attachments = [draft.updating(state: .uploaded(draft.ref(attachmentID: "unknown")))]
        await #expect(throws: AppError.attachmentNotFound) { try await repository.send(groupID: kickers, message) }
        #expect(try await repository.newest(groupID: kickers).items.allSatisfy { $0.attachments.isEmpty })
    }

    /// Another user's upload, or a blank message without any, is refused like the backend does.
    @Test func anotherUsersUploadAndABlankMessageAreRefused() async throws {
        let store = MockAttachmentStore()
        let repository = makeRepository(attachments: store)
        let draft = try AttachmentDraft.prepared(id: "pic-3", data: photo)
        let ticket = try await repository.requestUpload(groupID: kickers, draft.uploadRequest)
        try store.receive(photo, for: ticket.attachmentId, variant: .full)
        try store.receive(photo, for: ticket.attachmentId, variant: .thumbnail)
        identity.currentUserID = MockGroupFixtures.memberID(for: "Marta")
        var message = MessageDraft()
        message.attachments = [draft.updating(state: .uploaded(draft.ref(attachmentID: ticket.attachmentId)))]

        await #expect(throws: AppError.attachmentNotFound) { try await repository.send(groupID: kickers, message) }
        await #expect(throws: AppError.messageSendFailed) { try await repository.send(groupID: kickers, MessageDraft()) }
    }

    @Test func aLinkForAMissingOrDeletedMessageIsRefused() async throws {
        let store = MockAttachmentStore()
        let repository = makeRepository(attachments: store)
        let sent = try await sendPhoto(repository, store: store, text: "Look")
        let attachment = try #require(sent.message.attachments.first)

        await #expect(throws: AppError.messageNotFound) {
            try await repository.refreshAttachment(groupID: kickers, messageID: "nope", attachmentID: attachment.id)
        }
        await #expect(throws: AppError.attachmentNotFound) {
            try await repository.refreshAttachment(groupID: kickers, messageID: sent.message.id, attachmentID: "other")
        }
        _ = try await repository.delete(groupID: kickers, messageID: sent.message.id)
        await #expect(throws: AppError.attachmentNotFound) {
            try await repository.refreshAttachment(groupID: kickers, messageID: sent.message.id, attachmentID: attachment.id)
        }
    }

    /// A video and a file go through the mock like a picture: the video's ticket names a thumbnail target, the file's
    /// none, and the stored rows carry kind, duration and name with links the protocol serves.
    @Test func aVideoAndAFileBecomeRowsWithTheirHints() async throws {
        let store = MockAttachmentStore()
        let repository = makeRepository(attachments: store)
        let video = try await upload(.video, repository, store: store)
        let file = try await upload(.file, repository, store: store)
        var message = MessageDraft()
        message.attachments = [video, file]

        let sent = try await repository.send(groupID: kickers, message)

        #expect(sent.message.attachments.map(\.kind) == [.video, .file] && sent.message.text == nil)
        let storedVideo = sent.message.attachments[0]
        #expect(storedVideo.durationSeconds == 12 && storedVideo.width == 1280 && storedVideo.thumbnailUrl != nil)
        let storedFile = sent.message.attachments[1]
        #expect(storedFile.fileName == "training-plan.pdf" && storedFile.contentType == "application/pdf")
        #expect(storedFile.thumbnailUrl == nil && store.data(for: storedFile.id, variant: .thumbnail) == nil)
        #expect(store.data(for: storedVideo.id, variant: .thumbnail) != nil)
        #expect(try await repository.newest(groupID: kickers).items.last?.attachments.map(\.kind) == [.video, .file])
        let link = try await repository.refreshAttachment(groupID: kickers,
                                                          messageID: sent.message.id,
                                                          attachmentID: storedFile.id)
        #expect(link.thumbnailUrl == nil && link.url == storedFile.url)
    }

    /// A conversation's ticket is judged against the smaller caps, a group's against the full ones, as Laurel does
    /// by the room's kind: a 6 MB file passes in Kreuzberg Kickers and is refused in the conversation with Marta.
    @Test func aConversationsTicketTakesTheDirectCaps() async throws {
        let repository = makeRepository()
        let sixMegabytes = UploadRequestPayload(clientAttachmentId: "f",
                                                kind: .file,
                                                contentType: "application/pdf",
                                                sizeBytes: 6 * 1024 * 1024,
                                                fileName: "season.pdf")

        _ = try await repository.requestUpload(groupID: kickers, sixMegabytes)
        await #expect(throws: AppError.attachmentTooLarge(caps: .direct)) {
            try await repository.requestUpload(groupID: MockGroupFixtures.martaConversationID, sixMegabytes)
        }
    }

    /// The mock ticket refuses what the backend's policy refuses: a thumbnail on a file, a video over its cap or off
    /// the type list.
    @Test func theMockTicketAppliesTheBackendsPolicy() async throws {
        let repository = makeRepository()
        let thumbnail = UploadRequestPayload.Thumbnail(contentType: "image/jpeg", sizeBytes: 10)
        let fileWithThumbnail = UploadRequestPayload(clientAttachmentId: "f",
                                                     kind: .file,
                                                     contentType: "application/pdf",
                                                     sizeBytes: 10,
                                                     fileName: "plan.pdf",
                                                     thumbnail: thumbnail)
        await #expect(throws: AppError.attachmentUploadFailed) {
            try await repository.requestUpload(groupID: kickers, fileWithThumbnail)
        }

        let hugeVideo = UploadRequestPayload(clientAttachmentId: "v",
                                             kind: .video,
                                             contentType: "video/mp4",
                                             sizeBytes: 60 * 1024 * 1024)
        await #expect(throws: AppError.attachmentTooLarge(caps: .group)) {
            try await repository.requestUpload(groupID: kickers, hugeVideo)
        }

        let webm = UploadRequestPayload(clientAttachmentId: "w", kind: .video, contentType: "video/webm", sizeBytes: 10)
        await #expect(throws: AppError.attachmentTypeNotAllowed) { try await repository.requestUpload(groupID: kickers, webm) }
        #expect(logger.messages(in: .chat, at: .debug).allSatisfy { !$0.hasPrefix("Mock upload ticket") })
    }
}
