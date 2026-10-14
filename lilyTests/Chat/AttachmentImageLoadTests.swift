import Testing
import UIKit
@testable import lily

/// `AttachmentImageLoad` is the state of one picture a view brings through the loader: the decoded picture from the
/// cache or a download, failed for a refusal, bytes that are no picture or an object that is not there, and untouched
/// when the caller left before a refusal came back.
@MainActor
struct AttachmentImageLoadTests {
    private let chat = FakeChatRepository()
    private let cache = FakeAttachmentCache()
    private let logger = SpyLogger()
    private let clock = DateClock()
    private let message = ChatMessage.fixture(id: "m1", groupID: "g1")
    private let box = AttachmentImageLoad()
    /// A preview folder per test, never the process-wide one, as in `AttachmentLoaderTests`.
    private let previewDirectory = FileManager.default.temporaryDirectory
        .appending(path: "image-load-previews-\(UUID().uuidString)")

    private func makeLoader(_ backend: StubBackend) -> AttachmentLoader {
        AttachmentLoader(repository: chat,
                         cache: cache,
                         session: backend.makeSession(),
                         logger: logger,
                         previewDirectory: previewDirectory) { [clock] in clock.now }
    }

    private func attachment(on backend: StubBackend) -> lily.Attachment {
        .fixture(id: "a1",
                 url: backend.baseURL.appending(path: "/chat/g1/a1"),
                 thumbnailUrl: backend.baseURL.appending(path: "/chat/g1/a1/thumb"),
                 expiresAt: clock.now.addingTimeInterval(3600))
    }

    /// `StubBackend` serves text only, so a picture that decodes reaches the box through the cache.
    private func png() -> Data {
        let size = CGSize(width: 8, height: 8)
        return UIGraphicsImageRenderer(size: size).pngData { context in
            UIColor.systemRed.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    @Test func aCachedPictureIsDecodedAndHandedBack() async throws {
        let backend = StubBackend(json: "never asked")
        try await cache.store(png(), for: "a1", variant: .thumbnail)
        #expect(box.isLoading, "a fresh box is loading")

        let handed = await box.load(attachment(on: backend), variant: .thumbnail, in: message, through: makeLoader(backend))

        #expect(handed != nil && box.image === handed)
        #expect(!box.failed && !box.isLoading)
        #expect(backend.requests.isEmpty, "a cache hit downloads nothing")
    }

    @Test func aRefusedDownloadFailsWithoutAPicture() async {
        let backend = StubBackend(status: 404)

        let handed = await box.load(attachment(on: backend), variant: .thumbnail, in: message, through: makeLoader(backend))

        #expect(handed == nil && box.image == nil)
        #expect(box.failed && !box.isLoading)
    }

    @Test func bytesThatAreNoPictureFail() async {
        let backend = StubBackend(json: "not a picture")

        let handed = await box.load(attachment(on: backend), variant: .thumbnail, in: message, through: makeLoader(backend))

        #expect(handed == nil && box.image == nil && box.failed)
        #expect(backend.requests.count == 1, "the bytes were fetched once and refused by the decoder")
    }

    @Test func aMissingObjectFailsWithoutARequest() async {
        let backend = StubBackend(json: "the whole clip")

        let handed = await box.load(attachment(on: backend),
                                    variant: .thumbnail,
                                    in: message,
                                    through: makeLoader(backend),
                                    available: false)

        #expect(handed == nil && box.failed && !box.isLoading)
        #expect(backend.requests.isEmpty, "never the whole clip for a frame")
    }

    /// The loader shares one download with every caller, so a cancelled caller's refusal is where cancellation shows:
    /// the box stays as it was instead of reading failed. Deterministic: the task inherits the main actor and cannot
    /// start before the test yields, so it is cancelled before the loader throws.
    @Test func aCancelledLoadStaysLoading() async {
        let backend = StubBackend(status: 404)
        let loader = makeLoader(backend)

        let task = Task { await box.load(attachment(on: backend), variant: .thumbnail, in: message, through: loader) }
        task.cancel()
        let handed = await task.value

        #expect(handed == nil && box.image == nil)
        #expect(!box.failed && box.isLoading)
    }
}
