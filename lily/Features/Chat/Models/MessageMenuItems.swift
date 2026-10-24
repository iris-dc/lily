import Foundation

/// What a long press on a bubble offers, decided once so the transcript attaches a context menu only when something
/// can be tapped.
nonisolated struct MessageMenuItems: Equatable, Sendable {
    enum Item: Hashable, Sendable {
        case reply
        case copy
        case pin
        case unpin
        case retractVote
        case delete
        case report
        case block
    }

    /// Whether the caller may pin the message, and which way.
    enum Pinning: Equatable, Sendable {
        case none
        case pin
        case unpin
    }

    /// The items a tap acts on, in menu order.
    let enabled: [Item]

    var hasEnabledItems: Bool { !enabled.isEmpty }

    func offers(_ item: Item) -> Bool { enabled.contains(item) }

    static func items(for message: ChatMessage,
                      isOwn: Bool,
                      canReply: Bool,
                      canDelete: Bool,
                      pinning: Pinning = .none,
                      canRetractVote: Bool = false) -> MessageMenuItems {
        var enabled: [Item] = []
        if canReply { enabled.append(.reply) }
        if message.text != nil { enabled.append(.copy) }
        switch pinning {
        case .pin: enabled.append(.pin)
        case .unpin: enabled.append(.unpin)
        case .none: break
        }
        if canRetractVote { enabled.append(.retractVote) }
        if canDelete { enabled.append(.delete) }
        if !isOwn && !message.isDeleted { enabled += [.report, .block] }
        return MessageMenuItems(enabled: enabled)
    }
}
