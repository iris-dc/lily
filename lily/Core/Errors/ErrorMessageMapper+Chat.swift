import Foundation

/// Copy for the chat: reading, sending, replying and attaching (pictures, videos and files alike, so one line names the
/// caps of all three); `message(for:)` routes exactly those cases here, the attachments in a branch of their own so
/// neither switch grows past the complexity limit.
nonisolated extension ErrorMessageMapper {
    static func chatMessage(for error: AppError) -> ErrorMessage {
        switch error {
        case .chatUnavailable:
            ErrorMessage(title: localized("Chat unavailable"),
                         body: localized("We couldn't load messages right now. Try again in a moment."))
        case .messageSendFailed:
            ErrorMessage(title: localized("Not sent"), body: localized("Your message didn't go through. Tap it to retry."))
        case .messageNotFound:
            ErrorMessage(title: localized("Message not found"), body: localized("This message was already deleted."))
        case .replyTargetNotFound:
            ErrorMessage(title: localized("That message is gone"), body: localized("It was deleted before your reply was sent."))
        default:
            unknownMessage
        }
    }

    static func attachmentMessage(for error: AppError) -> ErrorMessage {
        switch error {
        case .attachmentNotFound:
            ErrorMessage(title: localized("Attachment missing"),
                         body: localized("The upload didn't finish. Remove it and add it again."))
        case .attachmentTooLarge(let caps):
            ErrorMessage(title: localized("That's too big"), body: attachmentCapsBody(caps))
        case .attachmentTypeNotAllowed:
            ErrorMessage(title: localized("That can't be sent"), body: localized("Try a photo, a video or another file."))
        case .attachmentsDisabled:
            ErrorMessage(title: localized("Attachments are off"),
                         body: localized("Attachments can't be sent right now. Try again later."))
        case .attachmentUploadFailed:
            ErrorMessage(title: localized("Couldn't upload the attachment"), body: localized("Tap it to try again."))
        case .attachmentUnavailable:
            ErrorMessage(title: localized("Couldn't load the attachment"), body: localized("Try again in a moment."))
        default:
            unknownMessage
        }
    }

    /// The room's caps as the config holds them, so the copy never disagrees with what is refused.
    private static func attachmentCapsBody(_ caps: AttachmentCaps) -> String {
        let mebibyte = 1024 * 1024
        let pictures = caps.imageMaxBytes / mebibyte
        let videos = caps.videoMaxBytes / mebibyte
        let minutes = Int(AppConfig.Chat.Attachments.videoMaxDurationSeconds) / 60
        let files = caps.fileMaxBytes / mebibyte
        return localized("""
            Pictures can be up to \(pictures) MB, videos up to \(videos) MB and \(minutes) minutes, \
            files up to \(files) MB.
            """)
    }
}
