import Foundation

/// Clears a room for the caller alone: `DELETE /api/groups/{id}/messages` moves their history floor, so what came
/// before is gone from their pages while every other member keeps it. A group keeps its row and gets an empty room
/// back in the cache (a live line has somewhere to land, and the next appear costs one `newest` at most); a
/// conversation leaves Mine, which unsubscribes its room through `myGroupsDidChange`, and returns on a later Mine
/// load once either side writes again. The chat's menu and a Chats row's context menu both go through one of these.
final class ChatHistoryClearer {
    private let repository: any ChatRepository
    private let cache: any ChatHistoryCache
    private let myGroups: MyGroupsStore
    private let unread: UnreadCenter
    private let reporter: GroupErrorReporter
    private let logger: any Logging

    init(repository: any ChatRepository,
         cache: any ChatHistoryCache,
         myGroups: MyGroupsStore,
         unread: UnreadCenter,
         reporter: GroupErrorReporter,
         logger: any Logging) {
        self.repository = repository
        self.cache = cache
        self.myGroups = myGroups
        self.unread = unread
        self.reporter = reporter
        self.logger = logger
    }

    /// Answers whether the history is gone. A failure has reached the popup already; cancellation stays quiet.
    func clear(_ group: SportGroup) async -> Bool {
        do {
            let cleared = try await repository.clearHistory(groupID: group.id)
            cache.drop(groupID: group.id, reason: "history cleared")
            // The backend's verdict, not the group's kind, says whether Mine still lists the room.
            if cleared.hidden {
                myGroups.remove(id: group.id)
            } else {
                storeEmptyRoom(for: group.id, epoch: cleared.channelEpoch)
            }
            unread.markRead(groupID: group.id)
            logger.info(.chat, "Chat history cleared for group \(group.id) (hidden: \(cleared.hidden))")
            return true
        } catch {
            guard !AppError.isCancellation(error) else { return false }
            logger.error(.chat, "Clearing the chat failed for group \(group.id): \(error)")
            reporter.report(error)
            return false
        }
    }

    /// A room with its history loaded and nothing in it, at the epoch the answer named.
    private func storeEmptyRoom(for groupID: String, epoch: Int) {
        var room = ChatRoomState(groupID: groupID, channelEpoch: epoch)
        room.applyNewest(MessagePage(items: [], hasMore: false, channelEpoch: epoch))
        cache.store(room, for: groupID)
    }
}
