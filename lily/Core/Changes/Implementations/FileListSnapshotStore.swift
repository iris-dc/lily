import Foundation

/// Snapshots as JSON files under `Caches/ListSnapshots/<list>.<caller>.json`, in the backend's own coding
/// (`APIJSONCoding`), so a wire type comes back as it arrived. Reads and writes are synchronous on purpose: a list is
/// a few kilobytes, read once when its list is built and written once per answer, which no hop off the main actor
/// would pay for (the attachment cache's detached writes are for megabytes). The system may purge `Caches/`, which is
/// fine: a miss means the spinner, as before there were snapshots.
final class FileListSnapshotStore: ListSnapshotStore {
    private let directory: URL
    private let logger: any Logging
    private let decoder = APIJSONCoding.makeDecoder()
    private let encoder = APIJSONCoding.makeEncoder()

    init(directory: URL = FileListSnapshotStore.defaultDirectory, logger: any Logging) {
        self.directory = directory
        self.logger = logger
    }

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: AppConfig.Lists.snapshotDirectoryName)
    }

    /// A snapshot that no longer decodes (a model that changed shape) is dropped, so the next launch is a plain miss.
    func load<Value: Decodable>(_ type: Value.Type, for key: ListSnapshotKey) -> Value? {
        let url = location(of: key)
        guard let data = try? Data(contentsOf: url) else {
            logger.debug(.cache, "Snapshot miss for \(key.list)")
            return nil
        }
        do {
            let value = try decoder.decode(Value.self, from: data)
            logger.debug(.cache, "Snapshot hit for \(key.list)")
            return value
        } catch {
            logger.warning(.cache, "Snapshot for \(key.list) unreadable, discarding: \(error)")
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    /// In place of whatever was there, the directory made on the way; a failure is a warning, since the list on screen
    /// is right either way.
    func save<Value: Encodable>(_ value: Value, for key: ListSnapshotKey) {
        do {
            let data = try encoder.encode(value)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: location(of: key), options: .atomic)
        } catch {
            logger.warning(.cache, "Storing the snapshot for \(key.list) failed: \(error)")
        }
    }

    /// A removal the file system refuses is a warning and no "cleared" line: a failed clear never claims a clean device.
    func clear() {
        do {
            try FileManager.default.removeItemIfPresent(at: directory)
            logger.debug(.cache, "List snapshots cleared")
        } catch {
            logger.warning(.cache, "List snapshots could not be cleared: \(error)")
        }
    }

    func sessionDidEnd() {
        clear()
    }

    private func location(of key: ListSnapshotKey) -> URL {
        directory.appending(path: key.fileName)
    }
}
