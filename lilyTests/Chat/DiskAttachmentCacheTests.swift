import Foundation
import Testing
@testable import lily

/// The on-disk cache in a directory of its own per test: files keyed by id and variant, the least recently used out
/// first once over the budget, a hit counting as a use, and nothing left after the session ends.
@MainActor
struct DiskAttachmentCacheTests {
    private let directory = FileManager.default.temporaryDirectory.appending(path: "attachment-cache-\(UUID().uuidString)")
    private let clock = DateClock()
    private let logger = SpyLogger()

    private func makeCache(limitBytes: Int = 100) -> DiskAttachmentCache {
        DiskAttachmentCache(directory: directory, limitBytes: limitBytes, logger: logger) { [clock] in clock.now }
    }

    private func bytes(_ count: Int) -> Data {
        Data(repeating: 1, count: count)
    }

    @Test func storesAndAnswersFilesByIdAndVariant() throws {
        let cache = makeCache()

        let full = try cache.store(bytes(10), for: "a1", variant: .full)
        let thumbnail = try cache.store(bytes(5), for: "a1", variant: .thumbnail)

        #expect(cache.fileURL(for: "a1", variant: .full) == full && cache.fileURL(for: "a1", variant: .thumbnail) == thumbnail)
        #expect(full != thumbnail && full.lastPathComponent == "a1" && thumbnail.lastPathComponent == "a1.thumb")
        #expect(try Data(contentsOf: full).count == 10 && cache.fileURL(for: "a2", variant: .full) == nil)
    }

    @Test func storingAgainReplacesTheFile() throws {
        let cache = makeCache()
        try cache.store(bytes(10), for: "a1", variant: .full)

        let url = try cache.store(bytes(20), for: "a1", variant: .full)

        #expect(try Data(contentsOf: url).count == 20)
    }

    @Test func copiesALocalFileIn() throws {
        let cache = makeCache()
        let source = FileManager.default.temporaryDirectory.appending(path: "picked-\(UUID().uuidString).jpg")
        try bytes(30).write(to: source)

        let url = try cache.store(copying: source, for: "a1", variant: .full)

        let copied = try Data(contentsOf: url)
        #expect(url != source && copied.count == 30)
        #expect(FileManager.default.fileExists(atPath: source.path()), "the source is left alone")
    }

    /// Over the budget, the oldest files go first; a hit makes a file young again.
    @Test func evictsTheLeastRecentlyUsedFirst() throws {
        let cache = makeCache(limitBytes: 100)
        try cache.store(bytes(40), for: "a", variant: .full)
        clock.advance(by: 1)
        try cache.store(bytes(40), for: "b", variant: .full)
        clock.advance(by: 1)
        _ = cache.fileURL(for: "a", variant: .full)
        clock.advance(by: 1)

        try cache.store(bytes(40), for: "c", variant: .full)

        #expect(cache.fileURL(for: "b", variant: .full) == nil, "the oldest untouched file went")
        #expect(cache.fileURL(for: "a", variant: .full) != nil && cache.fileURL(for: "c", variant: .full) != nil)
        #expect(logger.messages(in: .cache, at: .info).contains("Attachment cache evicted 1 files (40 B)"))
    }

    @Test func aStoreWithinTheBudgetEvictsNothing() throws {
        let cache = makeCache(limitBytes: 100)
        try cache.store(bytes(40), for: "a", variant: .full)
        try cache.store(bytes(40), for: "b", variant: .full)

        #expect(cache.fileURL(for: "a", variant: .full) != nil && cache.fileURL(for: "b", variant: .full) != nil)
        #expect(logger.messages(in: .cache, at: .info).isEmpty)
    }

    @Test func theSessionsEndClearsEverything() throws {
        let cache = makeCache()
        try cache.store(bytes(10), for: "a", variant: .full)
        try cache.store(bytes(10), for: "a", variant: .thumbnail)

        cache.sessionDidEnd()

        #expect(cache.fileURL(for: "a", variant: .full) == nil && cache.fileURL(for: "a", variant: .thumbnail) == nil)
        #expect(!FileManager.default.fileExists(atPath: directory.path()))
        #expect(logger.messages(in: .cache, at: .debug).contains("Attachment cache cleared on sign-out"))
        #expect(try cache.store(bytes(1), for: "b", variant: .full).lastPathComponent == "b", "and it works again afterwards")
    }

    @Test func theDefaultDirectoryIsUnderCaches() {
        let url = DiskAttachmentCache.defaultDirectory
        #expect(url.lastPathComponent == AppConfig.Chat.Attachments.cacheDirectoryName)
        #expect(url.path().contains("/Caches/"))
    }
}
