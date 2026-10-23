import Foundation

/// Hears of every message that lands in a room, the caller's own included, so the Chats list can put the room with the
/// latest line first without a reload.
protocol RoomActivityRecorder: AnyObject {
    func noteMessage(_ message: ChatMessage, in groupID: String)
}
