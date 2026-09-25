import Foundation

/// One row of the chat list, ready to draw: the timeline decides runs, names and dividers so the view only renders.
nonisolated enum ChatRow: Identifiable, Hashable, Sendable {
    /// A day boundary between messages.
    case day(Date)
    case message(MessageRow)
    /// A system note, centred: "Marta created Sunday 5-a-side".
    case system(ChatMessage)
    case pending(PendingMessage)

    var id: String {
        switch self {
        case .day(let date): "day-\(Int(date.timeIntervalSince1970))"
        case .message(let row): row.message.id
        case .system(let message): message.id
        case .pending(let pending): pending.id
        }
    }
}

/// A member's message with what its bubble needs from its neighbours.
nonisolated struct MessageRow: Hashable, Sendable {
    let message: ChatMessage
    let isOwn: Bool
    /// The sender's current name when still a member, else the name stored with the message.
    let senderName: String
    /// The first message of a sender's run carries the name and avatar.
    let isFirstInRun: Bool
    /// The last message of a run carries the timestamp.
    let isLastInRun: Bool
}
