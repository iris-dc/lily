import Foundation
import Observation

/// Room states keyed by group id, observable so the open chat redraws when the realtime controller inserts a
/// message; cleared on sign-out through `SessionObserver`. Nothing is written to disk.
@Observable
final class InMemoryChatHistoryCache: ChatHistoryCache, SessionObserver {
    private var rooms: [String: ChatRoomState] = [:]
    private let limit: Int
    private let logger: any Logging

    init(limit: Int = AppConfig.Chat.roomCacheLimit, logger: any Logging) {
        self.limit = limit
        self.logger = logger
    }

    var cachedGroupIDs: [String] { Array(rooms.keys) }

    func room(for groupID: String) -> ChatRoomState? {
        rooms[groupID]
    }

    func store(_ room: ChatRoomState, for groupID: String) {
        rooms[groupID] = room
    }

    func drop(groupID: String, reason: String) {
        guard rooms.removeValue(forKey: groupID) != nil else { return }
        logger.info(.cache, "Room cache dropped for group \(groupID) (\(reason))")
    }

    func compact(groupID: String) {
        guard let room = rooms[groupID], room.messages.count > limit else { return }
        rooms[groupID] = room.trimmed(toNewest: limit)
        logger.debug(.cache, "Room cache compacted for group \(groupID) to \(limit) messages")
    }

    func clear() {
        rooms.removeAll()
    }

    func sessionDidEnd() {
        clear()
        logger.debug(.cache, "Room caches cleared on sign-out")
    }
}
