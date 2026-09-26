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

    /// The newest page of a room, merged into the cached room. A room not held yet is cached as a stub before the
    /// request, so a live message arriving meanwhile has somewhere to land; `nil` when the room was dropped while the
    /// page was in flight (the caller lost the group), which the page must not undo.
    @discardableResult
    func loadNewest(groupID: String, epoch: Int) async throws -> ChatRoomState? {
        if cache.room(for: groupID) == nil {
            cache.store(ChatRoomState(groupID: groupID, channelEpoch: epoch), for: groupID)
        }
        let page = try await repository.newest(groupID: groupID)
        return apply(to: groupID) { $0.applyNewest(page) }
    }

    /// Everything after the room's watermark, at most `AppConfig.Chat.maxCatchUpPages` pages; a room without a
    /// watermark yet takes the newest page instead. `nil` when the room is not cached (or was dropped meanwhile):
    /// there is nothing to catch up. Every page is merged into the room as the cache holds it at that moment, never
    /// into a copy taken before the request, so nothing that landed while the page was in flight is lost.
    @discardableResult
    func catchUp(groupID: String) async throws -> ChatRoomState? {
        guard let room = cache.room(for: groupID) else { return nil }
        guard var watermark = room.restWatermark else {
            return try await loadNewest(groupID: groupID, epoch: room.channelEpoch)
        }
        for _ in 0..<AppConfig.Chat.maxCatchUpPages {
            let page = try await repository.newer(groupID: groupID, after: watermark)
            guard let updated = apply(to: groupID, { $0.applyNewer(page) }) else { return nil }
            guard page.hasMore, let next = updated.restWatermark, next != watermark else { return updated }
            watermark = next
        }
        return cache.room(for: groupID)
    }

    /// Step three of the resume protocol: the open room always, and every other cached room whose `lastMessageId`
    /// moved past its watermark, `maxConcurrent` at a time. Rooms without a cache have nothing to catch up.
    func catchUpMovedRooms(_ groups: [SportGroup], openRoomID: String?, maxConcurrent: Int) async {
        let due = groups.filter { hasMoved($0, isOpen: $0.id == openRoomID) }.map(\.id)
        await catchUpRooms(due, maxConcurrent: maxConcurrent)
    }

    /// The rooms named, whatever their watermarks say, `maxConcurrent` at a time: for a room resubscribed at an epoch
    /// a page revealed, whose watermark the same page moved while the resubscribe reopened the gap behind it.
    func catchUpRooms(_ groupIDs: [String], maxConcurrent: Int) async {
        await withTaskGroup(of: Void.self) { tasks in
            var pending = groupIDs[...]
            for _ in 0..<min(maxConcurrent, pending.count) {
                if let next = pending.popFirst() { tasks.addTask { await self.catchUpQuietly(next) } }
            }
            for await _ in tasks {
                if let next = pending.popFirst() { tasks.addTask { await self.catchUpQuietly(next) } }
            }
        }
    }

    /// The room after `change`, or `nil` when it is no longer cached.
    private func apply(to groupID: String, _ change: (inout ChatRoomState) -> Void) -> ChatRoomState? {
        cache.update(groupID: groupID, change)
        return cache.room(for: groupID)
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
