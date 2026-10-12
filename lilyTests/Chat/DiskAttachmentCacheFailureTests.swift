import Foundation
import Testing
@testable import lily

/// The on-disk cache where the file system says no, each test in a tree of its own (`root/cache`, `root/previews`,
/// never the process-wide folders): the end of a session sweeps the preview copies with the cache, a refused clear
/// or eviction is a warning and never a "cleared" line or a count, a file another sweep already removed is neither,
/// an unwritable directory fails the store, and the file work has an entry a detached task can call. `0o555` is what
/// makes a removal or a create fail deterministically here, because the test process is not root.
@MainActor
struct DiskAttachmentCacheFailureTests {
    private let root = FileManager.default.temporaryDirectory.appending(path: "attachment-cache-\(UUID().uuidString)")
    private let clock = DateClock()
    private let logger = SpyLogger()

    private var directory: URL { root.appending(path: "cache") }
    private var previewDirectory: URL { root.appending(path: "previews") }

    private func makeCache(limitBytes: Int = 100) -> DiskAttachmentCache {
        DiskAttachmentCache(directory: directory,
                            previewDirectory: previewDirectory,
                            limitBytes: limitBytes,
                            logger: logger) { [clock] in clock.now }
    }

    private func bytes(_ count: Int) -> Data {
        Data(repeating: 1, count: count)
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path())
    }

    /// Nothing inside can be made or unlinked until `unlock`.
    private func lock(_ folder: URL) throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.path())
    }

    /// Back to `0o755`, then the test's tree goes, so a locked folder never outlives its test in the temporary directory.
    private func unlock(_ folder: URL) {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path())
        try? FileManager.default.removeItem(at: root)
    }

    /// The shape `PreviewFiles.named` makes: a folder per attachment id under the preview directory, the stored object
    /// hard-linked into it under the name the viewer opens.
    private func previewCopy(of stored: URL, id: String, named name: String) throws -> URL {
        let folder = previewDirectory.appending(path: id)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: name)
        try FileManager.default.linkItem(at: stored, to: url)
        return url
    }

    @Test func signOutRemovesThePreviewCopiesToo() async throws {
        let cache = makeCache()
        let stored = try await cache.store(bytes(10), for: "a", variant: .full)
        let copy = try previewCopy(of: stored, id: "a", named: "clip.mp4")
        #expect(exists(copy), "the preview copy is in place before the session ends")

        await cache.sessionWillEnd()

        #expect(!exists(previewDirectory) && !exists(directory))
        #expect(cache.fileURL(for: "a", variant: .full) == nil)
        #expect(logger.messages(in: .cache, at: .debug).filter { $0.contains("cleared") }.count == 1)
        #expect(logger.messages(in: .cache, at: .warning).isEmpty)
    }

    @Test func aFailedClearIsAWarningNotACleared() async throws {
        let cache = makeCache()
        let stored = try await cache.store(bytes(10), for: "a", variant: .full)
        try lock(directory)
        defer { unlock(directory) }

        await cache.clear()

        #expect(exists(directory) && exists(stored), "what would not go is still there")
        #expect(logger.messages(in: .cache, at: .warning).count == 1)
        #expect(!logger.messages(in: .cache, at: .debug).contains { $0.contains("cleared") })
    }

    @Test func aFailedEvictionIsAWarningNotACount() async throws {
        let cache = makeCache(limitBytes: 1000)
        for id in ["a", "b", "c"] {
            try await cache.store(bytes(40), for: id, variant: .full)
            clock.advance(by: 1)
        }
        try lock(directory)
        defer { unlock(directory) }
        let second = makeCache(limitBytes: 100)

        await second.evict()

        #expect(["a", "b", "c"].allSatisfy { second.fileURL(for: $0, variant: .full) != nil }, "nothing went")
        #expect(logger.messages(in: .cache, at: .info).isEmpty, "so there is no eviction line")
        #expect(logger.messages(in: .cache, at: .warning).count == 1)
    }

    /// Downloads completing together run their sweeps together over the same oldest files; a file one sweep already
    /// removed left the device without the other, so it costs that sweep no other file and no warning.
    @Test func aFileAnotherSweepRemovedIsNeitherFailedNorPaidForWithAnother() async throws {
        let cache = makeCache(limitBytes: 1000)
        for id in ["a", "b", "c"] {
            try await cache.store(bytes(40), for: id, variant: .full)
            clock.advance(by: 1)
        }
        let listing = AttachmentCacheFiles.cachedFiles(in: directory)
        try FileManager.default.removeItem(at: directory.appending(path: "a"))

        let eviction = AttachmentCacheFiles.evict(listing, limitBytes: 100)

        #expect(eviction.removed == 0 && eviction.failed == 0, "the 80 B left fit, and nothing is blamed")
        #expect(["b", "c"].allSatisfy { cache.fileURL(for: $0, variant: .full) != nil }, "so nothing else went")
    }

    @Test func aStoreIntoAnUnwritableDirectoryThrows() async throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try lock(root)
        defer { unlock(root) }
        let cache = makeCache()

        await #expect(throws: (any Error).self) {
            try await cache.store(bytes(1), for: "a", variant: .full)
        }

        #expect(cache.fileURL(for: "a", variant: .full) == nil)
    }

    /// A scheduling assertion would be timing-based and is deliberately not written; this pins the IO entry the cache
    /// hops to: `nonisolated` with Sendable inputs, so a detached task may call it, and a file it wrote is a hit.
    @Test func aStoreRunsOffTheMainActor() async throws {
        let cache = makeCache()
        let url = directory.appending(path: "x")
        let stamp = clock.now

        try await Task.detached { try AttachmentCacheFiles.write(Data([1, 2, 3]), to: url, usedAt: stamp) }.value
        try await cache.store(bytes(5), for: "y", variant: .full)

        let written = try Data(contentsOf: url)
        let stored = try Data(contentsOf: directory.appending(path: "y"))
        let usedAt = try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        #expect(written.count == 3 && stored.count == 5)
        #expect(usedAt?.timeIntervalSince1970.rounded() == stamp.timeIntervalSince1970.rounded())
        #expect(cache.fileURL(for: "x", variant: .full) == url)
    }
}
