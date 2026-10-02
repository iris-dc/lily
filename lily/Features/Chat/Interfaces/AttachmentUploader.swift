import Foundation

/// Moves a prepared attachment into the bucket through the presigned targets an `UploadTicket` names. The ticket
/// comes from `ChatRepository.requestUpload`; the send then names the ticket's id.
protocol AttachmentUploader {
    /// PUTs the draft's file to `ticket.upload` and, when both exist, its thumbnail to `ticket.thumbnailUpload`, with
    /// exactly the headers each target names (the signature covers them). `progress` runs on the main actor with the
    /// share of all bytes sent so far, ending at one. A refused PUT is `.attachmentUploadFailed`, a lost connection
    /// `.network`; cancellation passes through.
    func upload(_ draft: AttachmentDraft,
                with ticket: UploadTicket,
                progress: @escaping @MainActor (Double) -> Void) async throws
}
