import Foundation

/// Clears a room for the caller alone: `DELETE /api/groups/{id}/messages` moves their history floor, so what came
/// before is gone from their pages while every other member keeps it. The room's unsent bubbles go with it, files and
/// all. The backend's verdict says what becomes of the room: one it still lists keeps its row and its cached room is
/// seated at the floor (a line that landed meanwhile stays, the watermark sits at the floor, so the next appear catches
/// up from there and a quiet room is not fetched at all); one it hid (`hidden`, a conversation with today's Laurel)
/// leaves Mine, the cache and the realtime subscription at once through `RealtimeSessionController.removeGroupLocally`,
/// and returns on a later Mine load once either side writes again. The chat's menu and a Chats row's context menu both
/// go through one of these.
final class ChatHistoryClearer {
    private let repository: any ChatRepository
    private let cache: any ChatHistoryCache
    private let outbox: ChatOutbox
    private let realtime: RealtimeSessionController
    private let unread: UnreadCenter
    private let reporter: GroupErrorReporter
    private let logger: any Logging

    init(repository: any ChatRepository,
         cache: any ChatHistoryCache,
         outbox: ChatOutbox,
         realtime: RealtimeSessionController,
         unread: UnreadCenter,
         reporter: GroupErrorReporter,
         logger: any Logging) {
        self.repository = repository
        self.cache = cache
        self.outbox = outbox
        self.realtime = realtime
        self.unread = unread
        self.reporter = reporter
        self.logger = logger
    }

    /// The backend's verdict, or `nil` when the history is not gone: a failure has reached the popup already (a refusal
    /// the room expects, `AppError.isChatRefusal`, logged at warning, a fault at error), cancellation stays quiet.
    func clear(_ group: SportGroup) async -> ClearedHistory? {
        do {
            let cleared = try await repository.clearHistory(groupID: group.id)
            outbox.discardAll(in: group.id)
            // The backend's verdict, not the group's kind, says whether Mine still lists the room.
            if cleared.hidden {
                realtime.removeGroupLocally(group.id, reason: "history cleared")
            } else {
                storeClearedRoom(for: group.id, cleared)
                unread.markRead(groupID: group.id)
            }
            logger.info(.chat, "Chat history cleared for group \(group.id) (hidden: \(cleared.hidden))")
            return cleared
        } catch {
            guard !AppError.isCancellation(error) else { return nil }
            logger.log(AppError.chatLogLevel(for: error), .chat, "Clearing the chat failed for group \(group.id): \(error)")
            reporter.report(error)
            return nil
        }
    }

    /// The cached room seated at the floor; a room never opened is cached first, so its first open is a catch-up too.
    private func storeClearedRoom(for groupID: String, _ cleared: ClearedHistory) {
        if cache.room(for: groupID) == nil {
            cache.store(ChatRoomState(groupID: groupID, channelEpoch: cleared.channelEpoch), for: groupID)
        }
        cache.update(groupID: groupID) { $0.applyCleared(floor: cleared.historyFloor, epoch: cleared.channelEpoch) }
    }
}
