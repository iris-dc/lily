import Foundation

/// The moderation items of a bubble's long-press menu: what a report of the bubble is about, and blocking its sender.
/// Who gets the items is `MessageMenuItems`' rule, not this file's.
extension ChatViewModel {
    /// What a report of a bubble is about: the message in this room. The backend reads the message through the room,
    /// so the target names both.
    func reportTarget(for message: ChatMessage) -> ReportTarget {
        .message(id: message.id, groupID: group.id)
    }

    /// Blocks the sender for the caller. Every room hides their lines at once, because the block list feeds `rows`,
    /// and the backend omits them from the next pages; a refusal reaches the popup through `report(_:during:)`,
    /// cancellation stays quiet.
    func block(senderOf message: ChatMessage) async {
        do {
            try await blocks.block(userID: message.senderUserId)
            logger.info(.chat, "Blocked user \(message.senderUserId) from group \(group.id)")
        } catch {
            report(error, during: "Block")
        }
    }
}
