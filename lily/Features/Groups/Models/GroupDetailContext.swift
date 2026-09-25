import Foundation

/// Where the group detail was opened from. From the chat, "Open chat" is hidden so the path never cycles.
nonisolated enum GroupDetailContext: Hashable, Sendable {
    case standalone
    case fromChat
}
