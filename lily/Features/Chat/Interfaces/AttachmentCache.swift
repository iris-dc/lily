import Foundation

/// The bytes of attachments the device has seen, keyed by attachment id and variant, never by URL: presigned links
/// expire, the objects do not. What was just sent is copied in from its own files, so it never downloads.
protocol AttachmentCache: AnyObject {
    /// The cached file, or `nil`; a hit counts as a use, so the least recently used files are the ones evicted.
    func fileURL(for id: String, variant: AttachmentVariant) -> URL?
    /// Keeps downloaded bytes and answers where they are.
    @discardableResult
    func store(_ data: Data, for id: String, variant: AttachmentVariant) throws -> URL
    /// Copies a file on the device in (a sent picture's own files) and answers where the copy is.
    @discardableResult
    func store(copying fileURL: URL, for id: String, variant: AttachmentVariant) throws -> URL
    /// Drops the least recently used files until the cache is within its byte budget.
    func evict()
    /// Drops everything; the end of a session.
    func clear()
}
