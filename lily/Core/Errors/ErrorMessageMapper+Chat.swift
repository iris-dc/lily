import Foundation

/// Copy for the chat: reading, sending, replying and attaching (pictures, videos and files alike, so one line names the
/// caps of all three); `message(for:)` routes exactly those cases here, the attachments in a branch of their own so
/// neither switch grows past the complexity limit.
nonisolated extension ErrorMessageMapper {
    static func chatMessage(for error: AppError) -> ErrorMessage {
        switch error {
        case .chatUnavailable:
            ErrorMessage(title: "Chat unavailable", body: "We couldn't load messages right now. Try again in a moment.")
        case .messageSendFailed:
            ErrorMessage(title: "Not sent", body: "Your message didn't go through. Tap it to retry.")
        case .messageNotFound:
            ErrorMessage(title: "Message not found", body: "This message was already deleted.")
        case .replyTargetNotFound:
            ErrorMessage(title: "That message is gone", body: "It was deleted before your reply was sent.")
        default:
            unknownMessage
        }
    }

    static func attachmentMessage(for error: AppError) -> ErrorMessage {
        switch error {
        case .attachmentNotFound:
            ErrorMessage(title: "Attachment missing", body: "The upload didn't finish. Remove it and add it again.")
        case .attachmentTooLarge:
            ErrorMessage(title: "That's too big", body: attachmentCapsBody)
        case .attachmentTypeNotAllowed:
            ErrorMessage(title: "That can't be sent", body: "Try a photo, a video or another file.")
        case .attachmentsDisabled:
            ErrorMessage(title: "Attachments are off", body: "Attachments can't be sent right now. Try again later.")
        case .attachmentUploadFailed:
            ErrorMessage(title: "Couldn't upload the attachment", body: "Tap it to try again.")
        case .attachmentUnavailable:
            ErrorMessage(title: "Couldn't load the attachment", body: "Try again in a moment.")
        default:
            unknownMessage
        }
    }

    /// The caps as the config holds them, so the copy never disagrees with what is refused.
    private static var attachmentCapsBody: String {
        let mebibyte = 1024 * 1024
        let pictures = AppConfig.Chat.Attachments.imageMaxBytes / mebibyte
        let videos = AppConfig.Chat.Attachments.videoMaxBytes / mebibyte
        let minutes = Int(AppConfig.Chat.Attachments.videoMaxDurationSeconds) / 60
        let files = AppConfig.Chat.Attachments.fileMaxBytes / mebibyte
        return "Pictures can be up to \(pictures) MB, videos up to \(videos) MB and \(minutes) minutes, files up to \(files) MB."
    }
}
