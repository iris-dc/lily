import Foundation

/// Attachment bytes under `Caches/Attachments/<id>` and `<id>.thumb`, least recently used first out once the files
/// exceed `diskCacheBytes`. "Used" is the file's modification date, bumped on every hit (the file system's access
/// date is not kept reliably). The system may purge `Caches/` on its own, which is fine: a miss downloads again.
/// The file work runs on a detached task (`AttachmentCacheFiles`), so a 25 MB write never holds the main actor.
/// Cleared when the session ends, the preview copies included, so one account's pictures never stay on the device
/// for the next.
final class DiskAttachmentCache: AttachmentCache, SessionObserver {
    private let directory: URL
    private let previewDirectory: URL
    private let limitBytes: Int
    private let logger: any Logging
    private let now: () -> Date

    init(directory: URL = DiskAttachmentCache.defaultDirectory,
         previewDirectory: URL = PreviewFiles.directory,
         limitBytes: Int = AppConfig.Chat.Attachments.diskCacheBytes,
         logger: any Logging,
         now: @escaping () -> Date = { .now }) {
        self.directory = directory
        self.previewDirectory = previewDirectory
        self.limitBytes = limitBytes
        self.logger = logger
        self.now = now
    }

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: AppConfig.Chat.Attachments.cacheDirectoryName)
    }

    func fileURL(for id: String, variant: AttachmentVariant) -> URL? {
        let url = location(of: id, variant: variant)
        guard FileManager.default.fileExists(atPath: url.path()) else { return nil }
        AttachmentCacheFiles.touch(url, usedAt: now())
        return url
    }

    @discardableResult
    func store(_ data: Data, for id: String, variant: AttachmentVariant) async throws -> URL {
        let url = location(of: id, variant: variant)
        let stamp = now()
        try await Task.detached(priority: .userInitiated) {
            try AttachmentCacheFiles.write(data, to: url, usedAt: stamp)
        }.value
        await evict()
        return url
    }

    @discardableResult
    func store(copying fileURL: URL, for id: String, variant: AttachmentVariant) async throws -> URL {
        let url = location(of: id, variant: variant)
        let stamp = now()
        try await Task.detached(priority: .userInitiated) {
            try AttachmentCacheFiles.copy(fileURL, to: url, usedAt: stamp)
        }.value
        await evict()
        return url
    }

    /// Oldest first, until the rest fits. Runs after every store, so the budget holds without a timer.
    func evict() async {
        let directory = self.directory
        let limitBytes = self.limitBytes
        let eviction = await Task.detached(priority: .utility) {
            AttachmentCacheFiles.evict(in: directory, limitBytes: limitBytes)
        }.value
        if eviction.removed > 0 {
            logger.info(.cache, "Attachment cache evicted \(eviction.removed) files (\(eviction.removedBytes) B)")
        }
        if eviction.failed > 0 {
            logger.warning(.cache, "Attachment cache could not evict \(eviction.failed) files")
        }
    }

    /// A removal the file system refuses is a warning and no "cleared" line: a failed clear never claims a clean device.
    func clear() async {
        let directory = self.directory
        let previewDirectory = self.previewDirectory
        let clearing = await Task.detached(priority: .userInitiated) {
            AttachmentCacheFiles.clear(directory, previews: previewDirectory)
        }.value
        if let error = clearing.cacheError {
            logger.warning(.cache, "Attachment cache could not be cleared: \(error)")
        }
        if let error = clearing.previewsError {
            logger.warning(.cache, "Attachment previews could not be cleared: \(error)")
        }
        if clearing.succeeded {
            logger.debug(.cache, "Attachment cache cleared")
        }
    }

    /// Awaited by the session controller before the state flips, so the device is clean (or the warning logged) before
    /// the next account can sign in.
    func sessionWillEnd() async {
        await clear()
    }

    /// Nothing left to do: the clearing happened in `sessionWillEnd`.
    func sessionDidEnd() {}

    private func location(of id: String, variant: AttachmentVariant) -> URL {
        directory.appending(path: id + variant.fileSuffix)
    }
}

/// The file work of DiskAttachmentCache, free of any actor so it runs on a detached task.
nonisolated enum AttachmentCacheFiles {
    struct Eviction: Sendable {
        let removed: Int
        let removedBytes: Int
        let failed: Int
    }

    struct Clearing: Sendable {
        let cacheError: (any Error)?
        let previewsError: (any Error)?

        var succeeded: Bool { cacheError == nil && previewsError == nil }
    }

    /// `data` at `url`, in place of whatever was there, the directory made on the way.
    static func write(_ data: Data, to url: URL, usedAt: Date) throws {
        try prepareSlot(at: url)
        try data.write(to: url, options: .atomic)
        touch(url, usedAt: usedAt)
    }

    /// A copy of `source` at `url`, in place of whatever was there, the directory made on the way.
    static func copy(_ source: URL, to url: URL, usedAt: Date) throws {
        try prepareSlot(at: url)
        try FileManager.default.copyItem(at: source, to: url)
        touch(url, usedAt: usedAt)
    }

    /// The file's "last used" is its modification date; a date the file system will not take is no reason to fail a
    /// hit or a store.
    static func touch(_ url: URL, usedAt: Date) {
        try? FileManager.default.setAttributes([.modificationDate: usedAt], ofItemAtPath: url.path())
    }

    /// Oldest first, until the rest fits.
    static func evict(in directory: URL, limitBytes: Int) -> Eviction {
        evict(cachedFiles(in: directory), limitBytes: limitBytes)
    }

    /// The sweep over a listing. A file that will not go is counted as failed and keeps its bytes in the total, so one
    /// stuck file neither stops the sweep nor passes for gone; one already gone (another store's sweep running at the
    /// same time, or the system purging Caches) left without this sweep, so its bytes come off the total and it counts
    /// neither as removed nor as failed.
    static func evict(_ listing: [Entry], limitBytes: Int) -> Eviction {
        var entries = listing
        var total = entries.reduce(0) { $0 + $1.size }
        var removed = 0
        var removedBytes = 0
        var failed = 0
        while total > limitBytes, !entries.isEmpty {
            let oldest = entries.removeFirst()
            do {
                try FileManager.default.removeItem(at: oldest.url)
                total -= oldest.size
                removed += 1
                removedBytes += oldest.size
            } catch {
                if FileManager.default.fileExists(atPath: oldest.url.path()) {
                    failed += 1
                } else {
                    total -= oldest.size
                }
            }
        }
        return Eviction(removed: removed, removedBytes: removedBytes, failed: failed)
    }

    /// The cache directory and the preview copies, each attempted whatever became of the other, so a stuck preview
    /// folder never keeps an account's pictures on the device.
    static func clear(_ directory: URL, previews previewDirectory: URL) -> Clearing {
        Clearing(cacheError: failure { try FileManager.default.removeItemIfPresent(at: directory) },
                 previewsError: failure { try PreviewFiles.removeAll(in: previewDirectory) })
    }

    struct Entry {
        let url: URL
        let size: Int
        let usedAt: Date
    }

    /// Every cached file, least recently used first.
    static func cachedFiles(in directory: URL) -> [Entry] {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys)) ?? []
        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            return Entry(url: url, size: values.fileSize ?? 0, usedAt: values.contentModificationDate ?? .distantPast)
        }
        .sorted { $0.usedAt < $1.usedAt }
    }

    private static func prepareSlot(at url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.removeItemIfPresent(at: url)
    }

    private static func failure(of work: () throws -> Void) -> (any Error)? {
        do {
            try work()
            return nil
        } catch {
            return error
        }
    }
}
