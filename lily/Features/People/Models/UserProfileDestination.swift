import Foundation

/// A person's profile, pushed from wherever they are named (a roster row, a participant row, an event's host line, a
/// sender in a chat, a conversation's info button). The name is what the screen shows until the profile answers.
/// `context` is `.fromChat` when the conversation with the person is one Back away, where "Message" would only push
/// that chat again.
nonisolated struct UserProfileDestination: Hashable, Sendable {
    let userId: String
    let displayName: String
    let context: GroupDetailContext

    init(userId: String, displayName: String, context: GroupDetailContext = .standalone) {
        self.userId = userId
        self.displayName = displayName
        self.context = context
    }
}
