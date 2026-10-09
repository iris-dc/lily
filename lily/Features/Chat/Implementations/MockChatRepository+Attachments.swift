import Foundation

/// The attachment routes of the mock chat, over the shared `MockAttachmentStore`: a ticket for any member whose
/// request passes the backend's policy, a link for any attachment of a message the caller can see.
extension MockChatRepository {
    func requestUpload(groupID: String, _ request: UploadRequestPayload) async throws -> UploadTicket {
        let (group, _) = try await room(groupID)
        let ticket = try attachments.issueTicket(groupID: group.id,
                                                 request,
                                                 uploader: identity.currentUserID ?? "",
                                                 now: now(),
                                                 caps: .caps(for: group))
        logger.debug(.chat, "Mock upload ticket \(ticket.attachmentId) issued in group \(groupID)")
        return ticket
    }

    /// Like the backend: a message below the caller's floor is not found, a tombstone or another message's attachment
    /// answers `ATTACHMENT_NOT_FOUND`.
    func refreshAttachment(groupID: String, messageID: String, attachmentID: String) async throws -> AttachmentLink {
        let (_, messages) = try await visibleRoom(groupID)
        guard let message = messages.first(where: { $0.id == messageID }) else { throw AppError.messageNotFound }
        guard !message.isDeleted, message.attachments.contains(where: { $0.id == attachmentID }) else {
            throw AppError.attachmentNotFound
        }
        return attachments.link(for: attachmentID, now: now())
    }

    /// The attachments a send stores, each checked against the store as the backend checks the bucket.
    func storedAttachments(_ refs: [AttachmentRef], in groupID: String, by callerID: String) throws -> [Attachment] {
        try attachments.stored(refs, groupID: groupID, uploader: callerID, now: now())
    }
}
