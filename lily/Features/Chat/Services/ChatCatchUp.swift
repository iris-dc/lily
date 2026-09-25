import Foundation

/// Brings cached rooms up to date over REST, anchored to each room's `restWatermark`: the first page for a room seen
/// for the first time, `newer` pages for one already held. Shared by the open chat and the realtime controller, so
/// the resume protocol and the chat screen recover a room the same way, into the same cache.
final class ChatCatchUp {
    private let repository: any ChatRepository
    private let cache: any ChatHistoryCache
    private let logger: any Logging

    init(repository: any ChatRepository, cache: any ChatHistoryCache, logger: any Logging) {
        self.repository = repository
        self.cache = cache
        self.logger = logger
    }

    /// The newest page of a room, cached; a room already held merges the page in.
    func loadNewest(groupID: String, epoch: Int) async throws -> ChatRoomState {
        var room = cache.room(for: groupID) ?? ChatRoomState(groupID: groupID, channelEpoch: epoch)
        room.applyNewest(try await repository.newest(groupID: groupID))
        cache.store(room, for: groupID)
        return room
    }

    /// Everything after the room's watermark, at most `AppConfig.Chat.maxCatchUpPages` pages; a room without a
    /// watermark yet takes the newest page instead. `nil` when the room is not cached: there is nothing to catch up.
    @discardableResult
    func catchUp(groupID: String) async throws -> ChatRoomState? {
        guard var room = cache.room(for: groupID) else { return nil }
        guard var watermark = room.restWatermark else {
            return try await loadNewest(groupID: groupID, epoch: room.channelEpoch)
        }
        for _ in 0..<AppConfig.Chat.maxCatchUpPages {
            let page = try await repository.newer(groupID: groupID, after: watermark)
            room.applyNewer(page)
            cache.store(room, for: groupID)
            guard page.hasMore, let next = room.restWatermark, next != watermark else { break }
            watermark = next
        }
        return room
    }

    /// Step three of the resume protocol: the open room always, and every other cached room whose `lastMessageId`
    /// moved past its watermark, `maxConcurrent` at a time. Rooms without a cache have nothing to catch up.
    func catchUpMovedRooms(_ groups: [SportGroup], openRoomID: String?, maxConcurrent: Int) async {
        let due = groups.filter { hasMoved($0, isOpen: $0.id == openRoomID) }.map(\.id)
        await withTaskGroup(of: Void.self) { tasks in
            var pending = due[...]
            for _ in 0..<min(maxConcurrent, pending.count) {
                if let next = pending.popFirst() { tasks.addTask { await self.catchUpQuietly(next) } }
            }
            for await _ in tasks {
                if let next = pending.popFirst() { tasks.addTask { await self.catchUpQuietly(next) } }
            }
        }
    }

    private func hasMoved(_ group: SportGroup, isOpen: Bool) -> Bool {
        guard let room = cache.room(for: group.id) else { return false }
        if isOpen { return true }
        if let newest = group.lastMessageId, newest > (room.restWatermark ?? "") { return true }
        logger.debug(.cache, "Catch-up skipped for group \(group.id) (nothing new)")
        return false
    }

    private func catchUpQuietly(_ groupID: String) async {
        do {
            try await catchUp(groupID: groupID)
            logger.debug(.chat, "Caught up group \(groupID)")
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.warning(.chat, "Catch-up failed for group \(groupID): \(error)")
        }
    }
}
