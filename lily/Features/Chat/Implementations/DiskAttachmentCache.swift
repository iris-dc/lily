import Foundation

/// Attachment bytes under `Caches/Attachments/<id>` and `<id>.thumb`, least recently used first out once the files
/// exceed `diskCacheBytes`. "Used" is the file's modification date, bumped on every hit (the file system's access
/// date is not kept reliably). The system may purge `Caches/` on its own, which is fine: a miss downloads again.
/// Cleared when the session ends, so one account's pictures never stay on the device for the next.
final class DiskAttachmentCache: AttachmentCache, SessionObserver {
    private let directory: URL
    private let limitBytes: Int
    private let fileManager = FileManager.default
    private let logger: any Logging
    private let now: () -> Date

    init(directory: URL = DiskAttachmentCache.defaultDirectory,
         limitBytes: Int = AppConfig.Chat.Attachments.diskCacheBytes,
         logger: any Logging,
         now: @escaping () -> Date = { .now }) {
        self.directory = directory
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
        guard fileManager.fileExists(atPath: url.path()) else { return nil }
        touch(url)
        return url
    }

    @discardableResult
    func store(_ data: Data, for id: String, variant: AttachmentVariant) throws -> URL {
        let url = try prepareSlot(for: id, variant: variant)
        try data.write(to: url, options: .atomic)
        return finishStoring(url)
    }

    @discardableResult
    func store(copying fileURL: URL, for id: String, variant: AttachmentVariant) throws -> URL {
        let url = try prepareSlot(for: id, variant: variant)
        try fileManager.copyItem(at: fileURL, to: url)
        return finishStoring(url)
    }

    /// Oldest first, until the rest fits. Runs after every store, so the budget holds without a timer.
    func evict() {
        var entries = cachedFiles()
        var total = entries.reduce(0) { $0 + $1.size }
        var removed = 0
        var removedBytes = 0
        while total > limitBytes, !entries.isEmpty {
            let oldest = entries.removeFirst()
            try? fileManager.removeItem(at: oldest.url)
            total -= oldest.size
            removed += 1
            removedBytes += oldest.size
        }
        if removed > 0 {
            logger.info(.cache, "Attachment cache evicted \(removed) files (\(removedBytes) B)")
        }
    }

    func clear() {
        try? fileManager.removeItem(at: directory)
    }

    func sessionDidEnd() {
        clear()
        logger.debug(.cache, "Attachment cache cleared on sign-out")
    }

    private struct Entry {
        let url: URL
        let size: Int
        let usedAt: Date
    }

    /// Every cached file, least recently used first.
    private func cachedFiles() -> [Entry] {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        let urls = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys)) ?? []
        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            return Entry(url: url, size: values.fileSize ?? 0, usedAt: values.contentModificationDate ?? .distantPast)
        }
        .sorted { $0.usedAt < $1.usedAt }
    }

    private func prepareSlot(for id: String, variant: AttachmentVariant) throws -> URL {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = location(of: id, variant: variant)
        if fileManager.fileExists(atPath: url.path()) {
            try fileManager.removeItem(at: url)
        }
        return url
    }

    private func finishStoring(_ url: URL) -> URL {
        touch(url)
        evict()
        return url
    }

    private func touch(_ url: URL) {
        try? fileManager.setAttributes([.modificationDate: now()], ofItemAtPath: url.path())
    }

    private func location(of id: String, variant: AttachmentVariant) -> URL {
        directory.appending(path: id + variant.fileSuffix)
    }
}
