import Foundation

/// Identifiers of the Chats tab's inbox; mirrored by hand in `lilyUITests` like the rest.
nonisolated extension AccessibilityIdentifiers {
    /// The pinned inbox row at the top of the Chats tab.
    static let inboxRow = "inbox-row"
    /// The glass button above the oldest loaded item while an earlier page exists.
    static let inboxLoadEarlier = "inbox-load-earlier"

    /// An item's card; a reminder card is the button that opens its game.
    static func inboxItem(_ id: String) -> String {
        "inbox-item-\(id)"
    }

    static func inboxAccept(_ id: String) -> String {
        "inbox-accept-\(id)"
    }

    static func inboxDecline(_ id: String) -> String {
        "inbox-decline-\(id)"
    }
}
