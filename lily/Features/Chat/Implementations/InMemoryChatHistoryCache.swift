import Foundation
import Observation

/// Room states keyed by group id, observable so the open chat redraws when the realtime controller inserts a
/// message; cleared on sign-out through `SessionObserver`. Nothing is written to disk. A room stored with a newer last
/// message tells `activity`, whoever wrote it: a send, a live line, a catch-up.
@Observable
final class InMemoryChatHistoryCache: ChatHistoryCache, SessionObserver {
    private var rooms: [String: ChatRoomState] = [:]
    private let limit: Int
    private let activity: (any RoomActivityRecorder)?
    private let logger: any Logging

    init(limit: Int = AppConfig.Chat.roomCacheLimit, activity: (any RoomActivityRecorder)? = nil, logger: any Logging) {
        self.limit = limit
        self.activity = activity
        self.logger = logger
    }

    var cachedGroupIDs: [String] { Array(rooms.keys) }

    func room(for groupID: String) -> ChatRoomState? {
        rooms[groupID]
    }

    func store(_ room: ChatRoomState, for groupID: String) {
        let previousLast = rooms[groupID]?.messages.last?.id
        rooms[groupID] = room
        if let last = room.messages.last, last.id != previousLast { activity?.noteMessage(last, in: groupID) }
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
