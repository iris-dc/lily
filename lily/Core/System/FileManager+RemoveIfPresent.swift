import Foundation

nonisolated extension FileManager {
    /// `removeItem(at:)`, except that nothing at `url` is not an error; a removal the file system refuses still throws.
    func removeItemIfPresent(at url: URL) throws {
        guard fileExists(atPath: url.path()) else { return }
        try removeItem(at: url)
    }
}
