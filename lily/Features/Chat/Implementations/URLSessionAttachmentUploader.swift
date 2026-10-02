import Foundation

/// PUTs attachment files to their presigned targets over a session of its own: longer timeouts than the API client's
/// and `waitsForConnectivity`, since a picture is bigger than any JSON body. Foreground only: an upload the app is
/// backgrounded through fails, and Retry asks for a new ticket. A 2xx is the only success; the bucket's XML error
/// body is never read, so no signed URL ever reaches a log.
final class URLSessionAttachmentUploader: AttachmentUploader {
    private let session: URLSession
    private let logger: any Logging

    init(session: URLSession = URLSessionAttachmentUploader.makeSession(), logger: any Logging) {
        self.session = session
        self.logger = logger
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = AppConfig.Chat.Attachments.uploadTimeout
        configuration.timeoutIntervalForResource = AppConfig.Chat.Attachments.uploadTimeout
        return URLSession(configuration: configuration)
    }

    func upload(_ draft: AttachmentDraft,
                with ticket: UploadTicket,
                progress: @escaping @MainActor (Double) -> Void) async throws {
        let total = Double(draft.sizeBytes + (draft.thumbnailSizeBytes ?? 0))
        let report: @Sendable (Int64) -> Void = { sent in
            let share = total > 0 ? min(Double(sent) / total, 1) : 1
            Task { @MainActor in progress(share) }
        }
        try await put(draft.fileURL, to: ticket.upload, id: draft.id, onBytesSent: report)
        if let thumbnail = ticket.thumbnailUpload, let thumbnailURL = draft.thumbnailURL {
            let fileBytes = Int64(draft.sizeBytes)
            try await put(thumbnailURL, to: thumbnail, id: draft.id) { report(fileBytes + $0) }
        }
        progress(1)
    }

    private func put(_ fileURL: URL,
                     to target: UploadTarget,
                     id: String,
                     onBytesSent: @escaping @Sendable (Int64) -> Void) async throws {
        var request = URLRequest(url: target.url)
        request.httpMethod = HTTPMethod.put.rawValue
        for (name, value) in target.headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        let response: URLResponse
        do {
            let delegate = UploadProgressDelegate(onBytesSent)
            (_, response) = try await session.upload(for: request, fromFile: fileURL, delegate: delegate)
        } catch let error as URLError where error.code != .cancelled {
            logger.warning(.chat, "Attachment \(id) upload failed before a response: \(error.localizedDescription)")
            throw AppError.network
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            logger.error(.chat, "Attachment \(id) upload refused with status \(status)")
            throw AppError.attachmentUploadFailed
        }
    }
}

/// Relays the bytes sent so far; `URLSession` calls it on its own queue.
nonisolated private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    private let onBytesSent: @Sendable (Int64) -> Void

    init(_ onBytesSent: @escaping @Sendable (Int64) -> Void) {
        self.onBytesSent = onBytesSent
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        onBytesSent(totalBytesSent)
    }
}
