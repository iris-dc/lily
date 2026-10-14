import Foundation

/// Clearing the room for the caller (a group's "Clear chat", a conversation's "Delete chat"), through the shared
/// `ChatHistoryClearer`, which also serves the Chats rows.
extension ChatViewModel {
    /// The room emptied for the caller: the read marker starts over (the backend dropped the caller's, so the first line
    /// after the clear is flushed at once), and the screen leaves when the backend's verdict says the room left Mine;
    /// the verdict decides, not the group's kind.
    func clearHistory() async {
        guard let cleared = await clearer.clear(group) else { return }
        readMarker.reset()
        if cleared.hidden { isGone = true }
    }
}
