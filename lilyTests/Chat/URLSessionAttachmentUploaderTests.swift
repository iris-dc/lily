import Foundation
import Testing
@testable import lily

/// The real uploader against a stubbed bucket: one PUT per object with exactly the ticket's headers and the file's
/// bytes, progress ending at one, and the two ways a PUT fails.
@MainActor
struct URLSessionAttachmentUploaderTests {
    private let logger = SpyLogger()

    private func makeDraft() throws -> AttachmentDraft {
        try AttachmentDraft.prepared(id: "u1", data: Data(repeating: 9, count: 1000))
    }

    private func ticket(on backend: StubBackend, thumbnail: Bool = true) -> UploadTicket {
        let headers = ["Content-Type": "image/jpeg", "x-amz-meta-uploader": "u-1"]
        return UploadTicket(attachmentId: "att-1",
                            upload: UploadTarget(url: backend.baseURL.appending(path: "/chat/g/att-1"), headers: headers),
                            thumbnailUpload: thumbnail
                                ? UploadTarget(url: backend.baseURL.appending(path: "/chat/g/att-1/thumb"), headers: headers)
                                : nil,
                            expiresAt: .distantFuture)
    }

    @Test func putsTheFileAndTheThumbnailWithTheTicketsHeaders() async throws {
        let backend = StubBackend(status: 200)
        let uploader = URLSessionAttachmentUploader(session: backend.makeSession(), logger: logger)
        var progress: [Double] = []

        try await uploader.upload(try makeDraft(), with: ticket(on: backend)) { progress.append($0) }

        #expect(backend.requests.count == 2 && backend.requests.allSatisfy { $0.httpMethod == "PUT" })
        #expect(backend.requests.map { $0.url?.path() } == ["/chat/g/att-1", "/chat/g/att-1/thumb"])
        #expect(backend.requests.map { $0.httpBody?.count } == [1000, 5])
        for request in backend.requests {
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "image/jpeg")
            #expect(request.value(forHTTPHeaderField: "x-amz-meta-uploader") == "u-1")
            #expect(request.value(forHTTPHeaderField: AppConfig.API.Headers.appVersion) == nil, "a bucket gets no app headers")
        }
        await settle(until: { progress.last == 1 })
        #expect(progress.allSatisfy { (0...1).contains($0) })
    }

    @Test func aTicketWithoutAThumbnailPutsTheFileAlone() async throws {
        let backend = StubBackend(status: 200)
        let uploader = URLSessionAttachmentUploader(session: backend.makeSession(), logger: logger)

        try await uploader.upload(try makeDraft(), with: ticket(on: backend, thumbnail: false)) { _ in }

        #expect(backend.requests.map { $0.url?.path() } == ["/chat/g/att-1"])
    }

    @Test func aRefusedPutFailsTheUploadWithoutLoggingTheURL() async throws {
        let backend = StubBackend(status: 403, json: "<Error><Code>AccessDenied</Code></Error>")
        let uploader = URLSessionAttachmentUploader(session: backend.makeSession(), logger: logger)

        await #expect(throws: AppError.attachmentUploadFailed) {
            try await uploader.upload(try makeDraft(), with: ticket(on: backend)) { _ in }
        }

        #expect(backend.requests.count == 1, "the thumbnail is not tried after the object was refused")
        #expect(logger.messages(in: .chat, at: .error) == ["Attachment u1 upload refused with status 403"])
        #expect(!logger.entries.contains { $0.message.contains(backend.baseURL.host()!) })
    }

    @Test func aLostConnectionIsANetworkFailure() async throws {
        let backend = StubBackend { _ in .failure(URLError(.notConnectedToInternet)) }
        let uploader = URLSessionAttachmentUploader(session: backend.makeSession(), logger: logger)

        await #expect(throws: AppError.network) {
            try await uploader.upload(try makeDraft(), with: ticket(on: backend)) { _ in }
        }
        #expect(logger.messages(in: .chat, at: .warning).count == 1)
    }

    @Test func theSessionWaitsForConnectivityWithTheUploadTimeout() {
        let configuration = URLSessionAttachmentUploader.makeSession().configuration
        #expect(configuration.waitsForConnectivity)
        #expect(configuration.timeoutIntervalForRequest == AppConfig.Chat.Attachments.uploadTimeout)
        #expect(configuration.timeoutIntervalForResource == AppConfig.Chat.Attachments.uploadTimeout)
    }
}
