import Foundation

/// What a long press on a member's bubble offers, decided once so the view only draws and the transcript attaches a
/// menu only when something can be tapped: reply, copy and delete as the view model's rules allow (`canReply(to:)`,
/// `canDelete(_:)`; this type composes them with the message), Report and Block for another member's live message.
/// The caller's own message and a tombstone offer neither, so a long press on another member's tombstone still opens
/// nothing.
nonisolated struct MessageMenuItems: Equatable, Sendable {
    enum Item: Hashable, Sendable {
        case reply
        case copy
        case delete
        case report
        case block
    }

    /// The items a tap acts on, in menu order.
    let enabled: [Item]

    var hasEnabledItems: Bool { !enabled.isEmpty }

    func offers(_ item: Item) -> Bool { enabled.contains(item) }

    /// Reply when the view model allows it, copy when there is text, delete when the view model allows it; Report and
    /// Block for another member's message while it stands.
    static func items(for message: ChatMessage, isOwn: Bool, canReply: Bool, canDelete: Bool) -> MessageMenuItems {
        var enabled: [Item] = []
        if canReply { enabled.append(.reply) }
        if message.text != nil { enabled.append(.copy) }
        if canDelete { enabled.append(.delete) }
        if !isOwn && !message.isDeleted { enabled += [.report, .block] }
        return MessageMenuItems(enabled: enabled)
    }
}
