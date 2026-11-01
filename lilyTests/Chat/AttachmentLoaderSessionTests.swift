import Foundation
import Testing
@testable import lily

/// What a sign-out does to the downloads in flight; `AttachmentLoaderTests` is near the type-body limit.
@MainActor
struct AttachmentLoaderSessionTests {
    private let chat = FakeChatRepository()
    private let cache = FakeAttachmentCache()
    private let logger = SpyLogger()
    private let clock = DateClock()
    private let message = ChatMessage.fixture(id: "m1", groupID: "g1")
    private let previewDirectory = FileManager.default.temporaryDirectory
        .appending(path: "loader-session-previews-\(UUID().uuidString)")

    private func makeLoader(_ backend: StubBackend) -> AttachmentLoader {
        AttachmentLoader(repository: chat,
                         cache: cache,
                         session: backend.makeSession(),
                         logger: logger,
                         previewDirectory: previewDirectory) { [clock] in clock.now }
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

    /// The bytes cross the stub session's own queues before the store is reached, so this waits on the clock, not on
    /// main-actor yields.
    private func waitUntilStoring() async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !cache.isHolding, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(2))
        }
        #expect(cache.isHolding, "the download reached the cache")
    }

    /// The transfer is cancelled with the session and nothing of the ended account reaches the cache after its sweep.
    @Test func aDownloadInFlightAtTheSessionsEndIsCancelledAndStoresNothing() async {
        let backend = StubBackend(json: "full-bytes")
        let loader = makeLoader(backend)
        chat.refreshLinks = [link(on: backend)]
        chat.holdsRequests = true
        let ended = Recorded<Bool>()

        let download = Task { try await loader.file(for: attachment(on: backend, expiresIn: 30), variant: .full, in: message) }
        await settle(until: { chat.refreshRequests.count == 1 })
        let ending = Task {
            await loader.sessionWillEnd()
            ended.record(true)
        }
        await Task.yield()
        #expect(ended.values.isEmpty, "the drain waits for the task")
        chat.releaseRequests()
        await ending.value

        await #expect(throws: CancellationError.self) { try await download.value }
        #expect(backend.requests.isEmpty && cache.fileURL(for: "a1", variant: .full) == nil)
        #expect(!logger.hasLine(in: .chat, at: .debug, mentioning: "downloaded"))
        #expect(logger.messages(in: .cache, at: .debug) == ["1 attachment downloads ended for the sign-out"])
    }

    /// A store already running when the session ends is a detached write the cancel does not reach: the drain lets it
    /// finish, so the sweep that follows removes it instead of racing it.
    @Test func theSessionsEndWaitsForAStoreInFlight() async throws {
        let backend = StubBackend(json: "full-bytes")
        let loader = makeLoader(backend)
        cache.holdsRequests = true
        let ended = Recorded<Bool>()

        let download = Task { try await loader.file(for: attachment(on: backend), variant: .full, in: message) }
        try await waitUntilStoring()
        let ending = Task {
            await loader.sessionWillEnd()
            ended.record(true)
        }
        await Task.yield()
        #expect(ended.values.isEmpty, "the drain waits for the write")
        cache.releaseRequests()
        await ending.value
        let url = try await download.value

        #expect(cache.fileURL(for: "a1", variant: .full) == url, "the store completed inside the drain")
        await cache.clear()
        #expect(cache.fileURL(for: "a1", variant: .full) == nil, "so the sweep that follows removes it")
    }

    /// A tile appearing between the drain and the cache sweep starts no download the sweep could race; the next account
    /// downloads again.
    @Test func aDownloadAskedForAfterTheDrainIsRefused() async throws {
        let backend = StubBackend(json: "full-bytes")
        let loader = makeLoader(backend)
        await loader.sessionWillEnd()

        await #expect(throws: CancellationError.self) {
            try await loader.file(for: attachment(on: backend), variant: .full, in: message)
        }
        #expect(backend.requests.isEmpty && cache.fileURL(for: "a1", variant: .full) == nil)
        #expect(logger.count(in: .chat, at: .debug, mentioning: "a1", "session is ending") == 1)

        loader.sessionDidEnd()
        let url = try await loader.file(for: attachment(on: backend), variant: .full, in: message)
        #expect(cache.fileURL(for: "a1", variant: .full) == url)
    }

    @Test func nothingInFlightEndsAtOnce() async {
        let loader = makeLoader(StubBackend(json: "x"))

        await loader.sessionWillEnd()

        #expect(logger.entries.isEmpty)
    }
}
