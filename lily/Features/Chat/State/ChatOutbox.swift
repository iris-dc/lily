import Foundation
import Observation

/// The unsent and failed messages of every room, kept while the screen is away: every open builds a new `ChatViewModel`,
/// so a send that fails after Back is still a failed bubble with Retry on the next open. A room's are discarded when its
/// history is cleared, everyone's on sign-out, because one account's unsent pictures must not stay on the device for the
/// next.
@Observable
final class ChatOutbox: SessionObserver {
    private var rooms: [String: [PendingMessage]] = [:]

    func messages(in groupID: String) -> [PendingMessage] {
        rooms[groupID] ?? []
    }

    /// The room's unsent messages as its screen now holds them; an empty list forgets the room.
    func replace(_ messages: [PendingMessage], in groupID: String) {
        rooms[groupID] = messages.isEmpty ? nil : messages
    }

    /// Drops the room's unsent messages with their files: the files of a failed picture must not outlive the bubble.
    func discardAll(in groupID: String) {
        rooms[groupID]?.forEach { $0.deleteLocalFiles() }
        rooms[groupID] = nil
    }

    func sessionDidEnd() {
        for messages in rooms.values { messages.forEach { $0.deleteLocalFiles() } }
        rooms.removeAll()
    }
}
