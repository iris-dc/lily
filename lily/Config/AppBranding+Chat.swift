import Foundation

nonisolated extension AppBranding {
    /// Copy of the chat screen: composer, bubbles, the system rows and the room's menu.
    enum Chat {
        static let placeholder = "Message"
        static let deletedPlaceholder = "Message deleted"
        static let eventCreatedFormat = "%@ created %@"
        static let failedHint = "Not sent. Tap to retry."
        static let slowDownFormat = "Slow down a moment. Try again in %lds."
        static let retry = "Retry"
        static let deleteMessage = "Delete"
        static let copyMessage = "Copy"
        static let today = "Today"
        static let yesterday = "Yesterday"
        /// VoiceOver name of the send button (its label is a glyph).
        static let send = "Send"
        /// Stands in for the game's title while it loads, or when the game is gone.
        static let eventCreatedFallbackTitle = "a game"
        static let remainingFormat = "%ld left"
        static let emptyTitle = "No messages yet"
        static let emptyMessage = "Say hello to the group."
        /// The room's "more" menu and its one item: a group's history is cleared for the caller, a conversation is
        /// deleted for them (it returns, without the old messages, when the other person writes).
        static let more = "More"
        static let clearChat = "Clear chat"
        static let deleteChat = "Delete chat"
        static let clearConfirmationTitle = "Clear chat history?"
        static let clearConfirmationMessage = "The messages disappear for you only. Other members keep them."
        static let deleteConfirmationTitleFormat = "Delete chat with %@?"
        static let deleteConfirmationMessageFormat =
            "The chat disappears for you. If %@ writes again, it comes back without the old messages."
        /// Replies: the context-menu item, the composer's preview bar, the X that drops the reply, and what a quote
        /// shows for an original that is gone or had no text.
        static let reply = "Reply"
        static let replyingToFormat = "Replying to %@"
        static let cancelReply = "Cancel reply"
        static let quotedDeleted = deletedPlaceholder
        static let quotedPhoto = "Photo"
        static let quotedVideo = "Video"
        static let quotedFile = "File"

        static func replyingTo(_ name: String) -> String {
            String(format: replyingToFormat, name)
        }

        static func eventCreated(by name: String, title: String) -> String {
            String(format: eventCreatedFormat, name, title)
        }

        static func remaining(_ count: Int) -> String {
            String(format: remainingFormat, count)
        }

        static func slowDown(seconds: Int) -> String {
            String(format: slowDownFormat, seconds)
        }

        static func deleteConfirmationTitle(name: String) -> String {
            String(format: deleteConfirmationTitleFormat, name)
        }

        static func deleteConfirmationMessage(name: String) -> String {
            String(format: deleteConfirmationMessageFormat, name)
        }
    }
}
