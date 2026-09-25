import Foundation

/// The rooms held in memory for the app's lifetime, so a chat reopens where it was and a foreground catches up
/// only what moved. The one place a room's state lives: the open chat and the realtime controller both read and
/// write it here, so neither can hold a stale copy of the other's changes.
protocol ChatHistoryCache: AnyObject {
    var cachedGroupIDs: [String] { get }
    func room(for groupID: String) -> ChatRoomState?
    func store(_ room: ChatRoomState, for groupID: String)
    /// The caller is out of the group (left, removed, banned, or it was deleted): its history must go.
    func drop(groupID: String, reason: String)
    /// Keeps only the newest `AppConfig.Chat.roomCacheLimit` messages of a room nobody is looking at.
    func compact(groupID: String)
    func clear()
}

extension ChatHistoryCache {
    /// Changes a cached room in place; nothing happens for a room that is not cached.
    func update(groupID: String, _ change: (inout ChatRoomState) -> Void) {
        guard var room = room(for: groupID) else { return }
        change(&room)
        store(room, for: groupID)
    }
}
