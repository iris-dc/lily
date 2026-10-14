import Foundation

/// The words of clearing a room, read by the menu item and the confirmation so both say the same. A group's history
/// (a tournament room's too, and a room of a kind this build does not know) is cleared for the caller alone: the other
/// members keep the messages. A direct conversation is deleted for them and comes back without the old messages if
/// the other person writes.
nonisolated struct ChatClearPrompt: Equatable, Sendable {
    let isConversation: Bool
    let name: String

    init(group: SportGroup) {
        isConversation = group.isDirect
        name = group.name
    }

    private typealias Copy = AppBranding.Chat

    /// The menu item and the dialog's button, which read the same.
    var actionTitle: String {
        isConversation ? Copy.deleteChat : Copy.clearChat
    }

    var title: String {
        isConversation ? Copy.deleteConfirmationTitle(name: name) : Copy.clearConfirmationTitle
    }

    var message: String {
        isConversation ? Copy.deleteConfirmationMessage(name: name) : Copy.clearConfirmationMessage
    }
}
