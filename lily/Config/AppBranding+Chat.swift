import Foundation

nonisolated extension AppBranding {
    /// Copy of the chat screen: composer, bubbles and the system rows.
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

        static func eventCreated(by name: String, title: String) -> String {
            String(format: eventCreatedFormat, name, title)
        }

        static func remaining(_ count: Int) -> String {
            String(format: remainingFormat, count)
        }

        static func slowDown(seconds: Int) -> String {
            String(format: slowDownFormat, seconds)
        }
    }
}
