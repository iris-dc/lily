import Foundation

nonisolated extension AppBranding {
    /// Copy of the chat screen: composer, bubbles, the system rows and the room's menu.
    enum Chat {
        static var placeholder: String { localized("Message") }
        static var deletedPlaceholder: String { localized("Message deleted") }
        static var failedHint: String { localized("Not sent. Tap to retry.") }
        static var retry: String { localized("Retry") }
        static var deleteMessage: String { localized("Delete") }
        static var copyMessage: String { localized("Copy") }
        static var today: String { localized("Today") }
        static var yesterday: String { localized("Yesterday") }
        /// VoiceOver name of the send button (its label is a glyph).
        static var send: String { localized("Send") }
        /// Stands in for the game's title while it loads, or when the game is gone.
        static var eventCreatedFallbackTitle: String { localized("a game") }
        static var emptyTitle: String { localized("No messages yet") }
        static var emptyMessage: String { localized("Say hello to the group.") }
        /// The room's "more" menu and its one item: a group's history is cleared for the caller, a conversation is
        /// deleted for them (it returns, without the old messages, when the other person writes).
        static var more: String { localized("More") }
        static var clearChat: String { localized("Clear chat") }
        static var deleteChat: String { localized("Delete chat") }
        static var clearConfirmationTitle: String { localized("Clear chat history?") }
        static var clearConfirmationMessage: String { localized("The messages disappear for you only. Other members keep them.") }
        /// Replies: the context-menu item, the composer's preview bar, the X that drops the reply, and what a quote
        /// shows for an original that is gone or had no text.
        static var reply: String { localized("Reply") }
        static var cancelReply: String { localized("Cancel reply") }
        static var quotedDeleted: String { deletedPlaceholder }
        static var quotedPhoto: String { localized("Photo") }
        static var quotedVideo: String { localized("Video") }
        static var quotedFile: String { localized("File") }

        static func replyingTo(_ name: String) -> String {
            localized("Replying to \(name)")
        }

        /// The system row of a game created in the group.
        static func eventCreated(by name: String, title: String) -> String {
            localized("\(name) created \(title)")
        }

        /// How many attachments the composer still takes.
        static func remaining(_ count: Int) -> String {
            localized("\(count) left")
        }

        static func slowDown(seconds: Int) -> String {
            localized("Slow down a moment. Try again in \(seconds)s.")
        }

        static func deleteConfirmationTitle(name: String) -> String {
            localized("Delete chat with \(name)?")
        }

        static func deleteConfirmationMessage(name: String) -> String {
            localized("The chat disappears for you. If \(name) writes again, it comes back without the old messages.")
        }
    }
}
