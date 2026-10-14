import Foundation

/// What a long press on a bubble offers, decided once so the transcript attaches a context menu only when something
/// can be tapped.
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

    static func items(for message: ChatMessage, isOwn: Bool, canReply: Bool, canDelete: Bool) -> MessageMenuItems {
        var enabled: [Item] = []
        if canReply { enabled.append(.reply) }
        if message.text != nil { enabled.append(.copy) }
        if canDelete { enabled.append(.delete) }
        if !isOwn && !message.isDeleted { enabled += [.report, .block] }
        return MessageMenuItems(enabled: enabled)
    }
}
