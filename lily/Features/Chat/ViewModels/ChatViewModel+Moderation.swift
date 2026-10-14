import Foundation

/// The moderation items of a bubble's long-press menu: what a report of the bubble is about, and blocking its sender.
extension ChatViewModel {
    /// The backend reads a message through its room, so the target names both.
    func reportTarget(for message: ChatMessage) -> ReportTarget {
        .message(id: message.id, groupID: group.id)
    }

    /// Every room hides the sender's lines at once, because the block list feeds `rows`; the backend omits them from the
    /// next pages.
    func block(senderOf message: ChatMessage) async {
        do {
            try await blocks.block(userID: message.senderUserId)
            logger.info(.chat, "Blocked user \(message.senderUserId) from group \(group.id)")
        } catch {
            report(error, during: "Block")
        }
    }
}
