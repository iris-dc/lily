import Foundation

/// The bytes of a stored attachment for the transcript, the viewer, the player and the file cards: the cache when it
/// has them (keyed by id, so a link's expiry never costs a download), else one download through a session of its own,
/// with the link refreshed first when it is about to expire (`urlRefreshMargin`) and once more after a 403 (presigned
/// links die with the backend's credentials, which can be sooner than the stated expiry). Two views asking for the
/// same file share one download; a caller that wants to show the download's progress passes `progress`
/// (`AttachmentLoader+Files.swift` builds the player's and the cards' entries on it). A sign-out cancels and awaits the
/// downloads in flight before the cache is swept, and starts none until the session has ended (`SessionObserver`,
/// registered ahead of the cache).
final class AttachmentLoader {
    private let repository: any ChatRepository
    private let cache: any AttachmentCache
    private let session: URLSession
    let logger: any Logging
    let previewDirectory: URL
    private let now: () -> Date
    private var inFlight: [String: Task<URL, any Error>] = [:]
    /// Set by `sessionWillEnd` ahead of the drain, cleared by `sessionDidEnd`: a tile appearing in between asks for no
    /// download the cache sweep could race.
    private var isEnding = false

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
    /// A picture stored without a thumbnail is kept once under `.full` whichever variant is asked for, since
    /// `Attachment.url(for: .thumbnail)` falls back to the full link and the gallery and the viewer would otherwise
    /// store the same bytes twice. A refused or failed download, or a cache that cannot keep the bytes, is
    /// `.attachmentUnavailable`, a lost connection `.network`, a session on its way out a `CancellationError`; `progress`
    /// follows the download when there is one, and a caller joining a download already running hears only its end.
    func file(for attachment: Attachment,
              variant: AttachmentVariant,
              in message: ChatMessage,
              progress: ProgressHandler? = nil) async throws -> URL {
        guard !isEnding else {
            logger.debug(.chat, "Attachment \(attachment.id) not fetched: the session is ending")
            throw CancellationError()
        }
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
        guard AppConfig.API.successStatuses.contains(status) else {
            logger.error(.chat, "Attachment \(attachment.id) download refused with status \(status)")
            throw AppError.attachmentUnavailable
        }
        let url = try await stored(data, for: attachment, variant: variant)
        logger.debug(.chat, "Attachment \(attachment.id) downloaded (\(variant), \(data.count) B)")
        progress?(1)
        return url
    }

    /// A cache that cannot keep the bytes (a full disk) fails the download; the log names the id, never the link. A
    /// cache that refuses because the session is ending passes its cancellation on.
    private func stored(_ data: Data, for attachment: Attachment, variant: AttachmentVariant) async throws -> URL {
        do {
            return try await cache.store(data, for: attachment.id, variant: variant)
        } catch {
            guard !AppError.isCancellation(error) else { throw error }
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

/// `SessionController` awaits observers in registration order, so the downloads end here before `DiskAttachmentCache`
/// sweeps, and from the drain until `sessionDidEnd` no download starts here and no store lands there (the cache refuses
/// its own), so nothing of the ended account re-creates the folder before the state flips. The cancel reaches the
/// transfer (`ProgressDataTask`); a `cache.store` already running is a detached write it does not touch, which the
/// await lets finish. Callers get the cancellation they already treat as quiet.
extension AttachmentLoader: SessionObserver {
    func sessionWillEnd() async {
        isEnding = true
        let running = Array(inFlight.values)
        guard !running.isEmpty else { return }
        running.forEach { $0.cancel() }
        for task in running { _ = try? await task.value }
        logger.debug(.cache, "\(running.count) attachment downloads ended for the sign-out")
    }

    func sessionDidEnd() {
        isEnding = false
    }
}
