import Foundation

/// A picture, a video or a file on its way into a message: its files on the device, the hints the backend stores, and
/// where it stands. The id is chosen once on the device; the ticket's `attachmentId` is what the send names. While
/// preparing, `fileURL` is where the prepared file will be written.
nonisolated struct AttachmentDraft: Identifiable, Hashable, Sendable {
    enum State: Hashable, Sendable {
        /// Being downsampled and re-encoded; nothing to show yet.
        case preparing
        /// The PUTs are running; the share of the bytes sent so far.
        case uploading(Double)
        /// Both objects are in the bucket under the ticket's id; the send may name it.
        case uploaded(AttachmentRef)
        /// The ticket or a PUT failed; Retry asks for a new ticket.
        case failed
    }

    /// Lower-case, like every id the device chooses.
    let clientAttachmentID: String
    let kind: AttachmentKind
    let fileURL: URL
    let thumbnailURL: URL?
    let contentType: String
    let sizeBytes: Int
    let thumbnailSizeBytes: Int?
    let fileName: String?
    let width: Int?
    let height: Int?
    let durationSeconds: Int?
    var state: State

    init(clientAttachmentID: String,
         kind: AttachmentKind,
         fileURL: URL,
         thumbnailURL: URL? = nil,
         contentType: String,
         sizeBytes: Int,
         thumbnailSizeBytes: Int? = nil,
         fileName: String? = nil,
         width: Int? = nil,
         height: Int? = nil,
         durationSeconds: Int? = nil,
         state: State = .preparing) {
        self.clientAttachmentID = clientAttachmentID
        self.kind = kind
        self.fileURL = fileURL
        self.thumbnailURL = thumbnailURL
        self.contentType = contentType
        self.sizeBytes = sizeBytes
        self.thumbnailSizeBytes = thumbnailSizeBytes
        // Cut on the device, so a long name never earns the backend's 400.
        self.fileName = fileName?.prefix(wireLength: AppConfig.Chat.Attachments.fileNameMaxLength)
        self.width = width
        self.height = height
        self.durationSeconds = durationSeconds
        self.state = state
    }

    /// The slot a just-picked item takes while the preparer works on it; a file's slot already shows its name.
    static func preparing(id: String, kind: AttachmentKind, fileName: String? = nil) -> AttachmentDraft {
        AttachmentDraft(clientAttachmentID: id,
                        kind: kind,
                        fileURL: FileManager.default.temporaryDirectory.appending(path: id),
                        contentType: AppConfig.Chat.Attachments.fallbackFileContentType,
                        sizeBytes: 0,
                        fileName: fileName)
    }

    var id: String { clientAttachmentID }

    /// Preparing or uploading: the message cannot be sent yet.
    var isInFlight: Bool {
        switch state {
        case .preparing, .uploading: true
        case .uploaded, .failed: false
        }
    }

    var hasFailed: Bool { state == .failed }

    var uploadedRef: AttachmentRef? {
        if case .uploaded(let ref) = state { return ref }
        return nil
    }

    /// The share uploaded so far while uploading, one once uploaded; `nil` otherwise.
    var progress: Double? {
        switch state {
        case .uploading(let progress): progress
        case .uploaded: 1
        case .preparing, .failed: nil
        }
    }

    /// The file the strip and the unsent bubble show: the thumbnail when there is one.
    var previewURL: URL { thumbnailURL ?? fileURL }

    /// Every file on the device that belongs to the draft.
    var localFiles: [URL] { [fileURL] + (thumbnailURL.map { [$0] } ?? []) }

    var aspectRatio: CGFloat? {
        guard let width, let height, width > 0, height > 0 else { return nil }
        return CGFloat(width) / CGFloat(height)
    }

    /// What the upload ticket is asked for.
    var uploadRequest: UploadRequestPayload {
        UploadRequestPayload(clientAttachmentId: clientAttachmentID,
                             kind: kind,
                             contentType: contentType,
                             sizeBytes: sizeBytes,
                             fileName: fileName,
                             width: width,
                             height: height,
                             durationSeconds: durationSeconds,
                             thumbnail: thumbnailSizeBytes.map {
                                 UploadRequestPayload.Thumbnail(contentType: AppConfig.Chat.Attachments.imageContentType,
                                                                sizeBytes: $0)
                             })
    }

    /// What the send names once the ticket's objects are uploaded.
    func ref(attachmentID: String) -> AttachmentRef {
        AttachmentRef(attachmentId: attachmentID,
                      kind: kind,
                      contentType: contentType,
                      sizeBytes: sizeBytes,
                      fileName: fileName,
                      width: width,
                      height: height,
                      durationSeconds: durationSeconds,
                      hasThumbnail: thumbnailURL != nil)
    }

    func updating(state: State) -> AttachmentDraft {
        var copy = self
        copy.state = state
        return copy
    }
}
