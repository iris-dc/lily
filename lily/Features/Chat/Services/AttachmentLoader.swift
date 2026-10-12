import Foundation

/// The bytes of a stored attachment for the transcript, the viewer, the player and the file cards: the cache when it
/// has them (keyed by id, so a link's expiry never costs a download), else one download through a session of its own,
/// with the link refreshed first when it is about to expire (`urlRefreshMargin`) and once more after a 403 (presigned
/// links die with the backend's credentials, which can be sooner than the stated expiry). Two views asking for the
/// same file share one download; a caller that wants to show the download's progress passes `progress`
/// (`AttachmentLoader+Files.swift` builds the player's and the cards' entries on it).
final class AttachmentLoader {
    private let repository: any ChatRepository
    private let cache: any AttachmentCache
    private let session: URLSession
    /// Internal, not private, so `AttachmentLoader+Files.swift` can log the preview copy it makes and knows where.
    let logger: any Logging
    /// Where the named preview copies go; the tests give every suite a folder of its own, because the disk cache sweeps
    /// the default one at the end of a session.
    let previewDirectory: URL
    private let now: () -> Date
    private var inFlight: [String: Task<URL, any Error>] = [:]

    init(repository: any ChatRepository,
         cache: any AttachmentCache,
         session: URLSession = URLSession(configuration: .default),
         logger: any Logging,
         previewDirectory: URL = PreviewFiles.directory,
         now: @escaping () -> Date = { .now }) {
        self.repository = repository
        self.cache = cache
        self.session = session
        self.logger = logger
        self.previewDirectory = previewDirectory
        self.now = now
    }

    /// The share of a download received so far, on the main actor; one once the bytes are on disk.
    typealias ProgressHandler = @MainActor @Sendable (Double) -> Void

    /// The file holding `variant` of `attachment`, which belongs to `message` (the link route needs its room and id).
    /// A picture stored without a thumbnail has one object, kept once under `.full` whichever variant is asked for
    /// (`Attachment.url(for: .thumbnail)` falls back to the full link, so the gallery's thumbnail and the viewer's full
    /// request would otherwise download and store the same bytes twice). A refused or failed download, or a cache that
    /// cannot keep the bytes, is `.attachmentUnavailable`, a lost connection `.network`. `progress` follows the download
    /// when there is one; a caller joining a download already running hears only its end.
    func file(for attachment: Attachment,
              variant: AttachmentVariant,
              in message: ChatMessage,
              progress: ProgressHandler? = nil) async throws -> URL {
        let variant: AttachmentVariant = attachment.thumbnailUrl == nil ? .full : variant
        if let cached = cache.fileURL(for: attachment.id, variant: variant) { return cached }
        let key = attachment.id + variant.fileSuffix
        if let running = inFlight[key] {
            let url = try await running.value
            progress?(1)
            return url
        }
        let task = Task { try await download(attachment, variant: variant, in: message, progress: progress) }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        return try await task.value
    }

    /// The full object's file when the device has it already, so a card can say whether a tap costs a download.
    func cachedFile(for attachment: Attachment) -> URL? {
        cache.fileURL(for: attachment.id, variant: .full)
    }

    private func download(_ attachment: Attachment,
                          variant: AttachmentVariant,
                          in message: ChatMessage,
                          progress: ProgressHandler?) async throws -> URL {
        var current = attachment
        if current.urlExpiresAt < now().addingTimeInterval(AppConfig.Chat.Attachments.urlRefreshMargin) {
            current = try await refreshed(current, in: message)
        }
        var (data, status) = try await fetch(current.url(for: variant), progress: progress)
        if status == AppConfig.Chat.Attachments.forbiddenStatus {
            current = try await refreshed(current, in: message)
            (data, status) = try await fetch(current.url(for: variant), progress: progress)
        }
        guard (200..<300).contains(status) else {
            logger.error(.chat, "Attachment \(attachment.id) download refused with status \(status)")
            throw AppError.attachmentUnavailable
        }
        let url = try await stored(data, for: attachment, variant: variant)
        logger.debug(.chat, "Attachment \(attachment.id) downloaded (\(variant), \(data.count) B)")
        progress?(1)
        return url
    }

    /// The downloaded bytes kept by the cache; a cache that cannot keep them (the disk is full) fails the download,
    /// logged with the id and never the link.
    private func stored(_ data: Data, for attachment: Attachment, variant: AttachmentVariant) async throws -> URL {
        do {
            return try await cache.store(data, for: attachment.id, variant: variant)
        } catch {
            logger.error(.chat, "Attachment \(attachment.id) could not be cached: \(error)")
            throw AppError.attachmentUnavailable
        }
    }

    private func fetch(_ url: URL, progress: ProgressHandler?) async throws -> (Data, Int) {
        do {
            let (data, response) = try await ProgressDataTask.run(url, in: session, progress: progress)
            guard let http = response as? HTTPURLResponse else { throw AppError.attachmentUnavailable }
            return (data, http.statusCode)
        } catch let error as URLError where error.code != .cancelled {
            logger.warning(.chat, "Attachment download failed before a response: \(error.localizedDescription)")
            throw AppError.network
        }
    }

    private func refreshed(_ attachment: Attachment, in message: ChatMessage) async throws -> Attachment {
        let link = try await repository.refreshAttachment(groupID: message.groupId,
                                                          messageID: message.id,
                                                          attachmentID: attachment.id)
        logger.debug(.chat, "Attachment link refreshed for \(attachment.id)")
        return attachment.refreshed(with: link)
    }
}
