import Foundation

/// Where the group detail, or a person's profile, was opened from. From the chat, "Open chat" (and a conversation
/// counterpart's "Message") is hidden so the path never cycles.
nonisolated enum GroupDetailContext: Hashable, Sendable {
    case standalone
    case fromChat
}
