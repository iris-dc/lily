import Foundation

/// What a chat row is: something a member wrote, or a system note the backend posted (a game created in the group).
nonisolated enum MessageKind: String, Codable, Sendable {
    case text
    case eventCreated = "event_created"
}
