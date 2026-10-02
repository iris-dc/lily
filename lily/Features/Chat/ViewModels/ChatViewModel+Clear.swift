import Foundation

/// Clearing the room for the caller (a group's "Clear chat", a conversation's "Delete chat"), through the shared
/// `ChatHistoryClearer`, which also serves the Chats rows.
extension ChatViewModel {
    /// The room emptied for the caller: the unsent bubbles go with it, the read marker starts over (the backend
    /// dropped the caller's), and a conversation is gone from Mine, so the screen leaves.
    func clearHistory() async {
        guard await clearer.clear(group) else { return }
        pending.removeAll()
        lastFlushedReadID = nil
        lastFlushAt = nil
        if group.isDirect { isGone = true }
    }
}
