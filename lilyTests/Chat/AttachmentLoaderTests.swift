import Foundation
import Synchronization
import Testing
@testable import lily

/// The loader over a stubbed bucket: the cache first, else one download, a link refreshed before it expires and once
/// more after a 403, and a refusal that stays one.
@MainActor
struct AttachmentLoaderTests {
    private let chat = FakeChatRepository()
    private let cache = FakeAttachmentCache()
    private let logger = SpyLogger()
    private let clock = DateClock()
    private let message = ChatMessage.fixture(id: "m1", groupID: "g1")

    private func makeLoader(_ backend: StubBackend) -> AttachmentLoader {
        AttachmentLoader(repository: chat, cache: cache, session: backend.makeSession(), logger: logger) { [clock] in clock.now }
    }

    private func attachment(on backend: StubBackend, expiresIn seconds: TimeInterval = 3600) -> lily.Attachment {
        .fixture(id: "a1",
                 url: backend.baseURL.appending(path: "/chat/g1/a1"),
                 thumbnailUrl: backend.baseURL.appending(path: "/chat/g1/a1/thumb"),
                 expiresAt: clock.now.addingTimeInterval(seconds))
    }

    private func link(on backend: StubBackend) -> AttachmentLink {
        AttachmentLink(url: backend.baseURL.appending(path: "/chat/g1/a1-fresh"),
                       thumbnailUrl: backend.baseURL.appending(path: "/chat/g1/a1-fresh/thumb"),
                       urlExpiresAt: clock.now.addingTimeInterval(3600))
    }

    @Test func aFreshLinkDownloadsOnceAndThenHitsTheCache() async throws {
        let backend = StubBackend(json: "thumb-bytes")
        let loader = makeLoader(backend)
        let attachment = attachment(on: backend)

        let first = try await loader.file(for: attachment, variant: .thumbnail, in: message)
        let second = try await loader.file(for: attachment, variant: .thumbnail, in: message)

        let bytes = try Data(contentsOf: first)
        #expect(first == second && bytes == Data("thumb-bytes".utf8))
        #expect(backend.requests.map { $0.url?.path() } == ["/chat/g1/a1/thumb"], "the thumbnail link, once")
        #expect(chat.refreshRequests.isEmpty)
        #expect(cache.fileURL(for: "a1", variant: .thumbnail) == first && cache.fileURL(for: "a1", variant: .full) == nil)
        #expect(logger.messages(in: .chat, at: .debug).contains("Attachment a1 downloaded (thumbnail, 11 B)"))
    }

    @Test func aLinkAboutToExpireIsRefreshedFirst() async throws {
        let backend = StubBackend(json: "full-bytes")
        let loader = makeLoader(backend)
        chat.refreshLinks = [link(on: backend)]

        _ = try await loader.file(for: attachment(on: backend, expiresIn: 30), variant: .full, in: message)

        #expect(chat.refreshRequests == [FakeChatRepository.RefreshRequest(groupID: "g1", messageID: "m1", attachmentID: "a1")])
        #expect(backend.requests.map { $0.url?.path() } == ["/chat/g1/a1-fresh"], "the fresh link is what downloads")
        #expect(logger.messages(in: .chat, at: .debug).contains("Attachment link refreshed for a1"))
    }

    /// A link the bucket refuses (credentials gone before the stated expiry) is refreshed once.
    @Test func aForbiddenLinkIsRefreshedOnce() async throws {
        let attempts = Mutex(0)
        let backend = StubBackend { request in
            attempts.withLock { $0 += 1 }
            let fresh = request.url?.path().contains("fresh") == true
            return .success(StubURLProtocol.Response(status: fresh ? 200 : 403, json: fresh ? "ok" : ""))
        }
        let loader = makeLoader(backend)
        chat.refreshLinks = [link(on: backend)]

        let url = try await loader.file(for: attachment(on: backend), variant: .full, in: message)

        #expect(try Data(contentsOf: url) == Data("ok".utf8) && attempts.withLock { $0 } == 2)
        #expect(chat.refreshRequests.count == 1)
    }

    @Test func aSecondForbiddenOrAnyOtherRefusalIsUnavailable() async {
        let forbidden = StubBackend(status: 403)
        chat.refreshLinks = [link(on: forbidden)]
        await #expect(throws: AppError.attachmentUnavailable) {
            try await makeLoader(forbidden).file(for: attachment(on: forbidden), variant: .full, in: message)
        }
        #expect(chat.refreshRequests.count == 1 && forbidden.requests.count == 2)

        let gone = StubBackend(status: 404)
        await #expect(throws: AppError.attachmentUnavailable) {
            try await makeLoader(gone).file(for: attachment(on: gone), variant: .full, in: message)
        }
        #expect(cache.fileURL(for: "a1", variant: .full) == nil && logger.messages(in: .chat, at: .error).count == 2)
    }

    @Test func aFailedRefreshAndALostConnectionSurfaceAsTheirErrors() async {
        let backend = StubBackend(json: "x")
        chat.refreshError = AppError.messageNotFound
        await #expect(throws: AppError.messageNotFound) {
            try await makeLoader(backend).file(for: attachment(on: backend, expiresIn: 1), variant: .full, in: message)
        }

        let offline = StubBackend { _ in .failure(URLError(.notConnectedToInternet)) }
        await #expect(throws: AppError.network) {
            try await makeLoader(offline).file(for: attachment(on: offline), variant: .full, in: message)
        }
    }

    /// Two views asking for the same file share one download.
    @Test func concurrentCallersShareOneDownload() async throws {
        let attempts = Mutex(0)
        let backend = StubBackend { _ in
            attempts.withLock { $0 += 1 }
            return .success(StubURLProtocol.Response(status: 200, json: "shared"))
        }
        let loader = makeLoader(backend)
        let attachment = attachment(on: backend)

        async let first = loader.file(for: attachment, variant: .thumbnail, in: message)
        async let second = loader.file(for: attachment, variant: .thumbnail, in: message)
        let urls = try await [first, second]

        #expect(urls[0] == urls[1] && attempts.withLock { $0 } == 1)
    }

    /// A download's progress is reported along the way and ends at one; a cached file costs no download and reports
    /// nothing, since there is nothing to wait for.
    @Test func aDownloadReportsItsProgressAndEndsAtOne() async throws {
        let backend = StubBackend(json: "a-full-file")
        let loader = makeLoader(backend)
        let attachment = attachment(on: backend)
        var reported: [Double] = []

        _ = try await loader.file(for: attachment, variant: .full, in: message) { reported.append($0) }
        await Task.yield()

        #expect(reported.last == 1 && reported.allSatisfy { (0...1).contains($0) })
        #expect(loader.cachedFile(for: attachment) == cache.fileURL(for: "a1", variant: .full))
        reported = []
        _ = try await loader.file(for: attachment, variant: .full, in: message) { reported.append($0) }
        #expect(reported.isEmpty && backend.requests.count == 1)
    }

    /// The preview copy carries the sender's name for the file (the id when there is none) in a folder of its own,
    /// linked to the cached bytes, so QuickLook knows the type and nothing is written twice.
    @Test func aPreviewFileIsNamedAfterTheAttachment() async throws {
        let backend = StubBackend(json: "%PDF-1.4 fake")
        let loader = makeLoader(backend)
        let named = lily.Attachment.fileFixture(id: "doc-1")
        let fixedLinks = lily.Attachment(id: named.id,
                                         kind: named.kind,
                                         contentType: named.contentType,
                                         sizeBytes: named.sizeBytes,
                                         fileName: named.fileName,
                                         url: backend.baseURL.appending(path: "/chat/g1/doc-1"),
                                         urlExpiresAt: clock.now.addingTimeInterval(3600))

        let preview = try await loader.previewFile(for: fixedLinks, in: message)

        #expect(preview.lastPathComponent == "training-plan.pdf")
        #expect(preview.deletingLastPathComponent().lastPathComponent == "doc-1")
        #expect(preview.path().hasPrefix(PreviewFiles.directory.path()))
        #expect(try Data(contentsOf: preview) == Data("%PDF-1.4 fake".utf8))
        PreviewFiles.remove(preview)
        #expect(!FileManager.default.fileExists(atPath: preview.deletingLastPathComponent().path()))
    }

    /// A video from the camera roll has no name of its own: the content type gives the preview its extension, which is
    /// what the player needs to read the file.
    @Test func anUnnamedAttachmentIsNamedByItsType() {
        #expect(PreviewFiles.name(for: .videoFixture(id: "vid-9")) == "vid-9.mp4")
        #expect(PreviewFiles.name(for: .fileFixture(id: "doc-9", fileName: nil)) == "doc-9.pdf")
        #expect(PreviewFiles.name(for: .fileFixture(id: "doc-9", fileName: "plan.pdf")) == "plan.pdf")
        #expect(PreviewFiles.name(for: .fileFixture(id: "doc-9", fileName: "README")) == "README.pdf")
    }

    /// The name becomes a path component under the preview folder: only its last component counts, and a name that
    /// is no file name at all falls back to the id, so a sender's name can never reach outside the folder.
    @Test func aNameWithSeparatorsOrDotsCannotLeaveThePreviewFolder() {
        #expect(PreviewFiles.name(for: .fileFixture(id: "doc-9", fileName: "../../evil.pdf")) == "evil.pdf")
        #expect(PreviewFiles.name(for: .fileFixture(id: "doc-9", fileName: "/etc/passwd")) == "passwd.pdf")
        #expect(PreviewFiles.name(for: .fileFixture(id: "doc-9", fileName: "..")) == "doc-9.pdf")
        #expect(PreviewFiles.name(for: .fileFixture(id: "doc-9", fileName: ".")) == "doc-9.pdf")
        #expect(PreviewFiles.name(for: .fileFixture(id: "doc-9", fileName: "/")) == "doc-9.pdf")
        #expect(PreviewFiles.name(for: .fileFixture(id: "doc-9", fileName: "")) == "doc-9.pdf")
    }
}
