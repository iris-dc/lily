import Foundation

/// One row of the chat list, ready to draw: the timeline decides runs, names and dividers so the view only renders.
nonisolated enum ChatRow: Identifiable, Hashable, Sendable {
    /// A day boundary between messages.
    case day(Date)
    case message(MessageRow)
    /// A system note, centred: "Marta created Sunday 5-a-side".
    case system(ChatMessage)
    case pending(PendingMessage)

    /// A sent message keeps the id of the unsent bubble it replaces (the client id), so the transcript sees one row
    /// change rather than a row leave and another arrive.
    var id: String {
        switch self {
        case .day(let date): "day-\(Int(date.timeIntervalSince1970))"
        case .message(let row): row.message.clientMessageId ?? row.message.id
        case .system(let message): message.id
        case .pending(let pending): pending.id
        }
    }

    /// The stored message's id, what a quote names; `nil` for a day chip or an unsent message.
    var messageID: String? {
        switch self {
        case .message(let row): row.message.id
        case .system(let message): message.id
        case .day, .pending: nil
        }
    }

    /// Whether the row is the caller's: their unsent messages and their own bubbles follow to the bottom whatever the
    /// reader does.
    var isOwn: Bool {
        switch self {
        case .pending: true
        case .message(let row): row.isOwn
        case .day, .system: false
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
