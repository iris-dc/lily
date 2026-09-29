import Foundation

/// The inbox conversation as a navigation destination on the Chats stack; a value with no payload, so the pinned
/// row can be a `NavigationLink`.
nonisolated struct InboxDestination: Hashable, Sendable {}
