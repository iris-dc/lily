import Foundation

/// The share of an upload's bytes sent so far, with the file and its thumbnail as one total, so the ring on the strip
/// never runs backwards when the second PUT starts.
nonisolated struct UploadProgress: Hashable, Sendable {
    let fileBytes: Int
    let thumbnailBytes: Int

    var total: Int { fileBytes + thumbnailBytes }

    /// The file's PUT has sent `sent` bytes; 1 for a total of zero (nothing to wait for), never above 1.
    func share(fileSent sent: Int64) -> Double {
        share(of: sent)
    }

    /// The thumbnail's PUT has sent `sent` bytes after the whole file.
    func share(thumbnailSent sent: Int64) -> Double {
        share(of: Int64(fileBytes) + sent)
    }

    private func share(of bytes: Int64) -> Double {
        total > 0 ? min(Double(bytes) / Double(total), 1) : 1
    }
}
