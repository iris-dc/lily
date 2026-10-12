import Foundation

nonisolated extension FileManager {
    /// Removes the file or directory at `url` when there is one; nothing there is nothing to remove, not an error.
    /// A removal the file system refuses still throws, so no caller takes a stuck file for gone.
    func removeItemIfPresent(at url: URL) throws {
        guard fileExists(atPath: url.path()) else { return }
        try removeItem(at: url)
    }
}
