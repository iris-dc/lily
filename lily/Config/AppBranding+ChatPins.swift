import Foundation

/// Pinned messages: the note pinning posts, and the bar at the top of the chat.
nonisolated extension AppBranding.Chat {
    /// "Marta pinned «Bring the balls»".
    static func messagePinned(by name: String, excerpt: String) -> String {
        localized("\(name) pinned «\(excerpt)»")
    }

    /// The note when the pinned message had nothing to quote.
    static func messagePinned(by name: String) -> String {
        localized("\(name) pinned a message")
    }

    enum Pins {
        static var pin: String { localized("Pin") }
        static var unpin: String { localized("Unpin") }
        static var pinnedMessage: String { localized("Pinned message") }
        /// The bar's title among several pins: "Pinned message 2 of 3", counting from the oldest.
        static func pinnedMessage(_ number: Int, of count: Int) -> String {
            localized("Pinned message \(number) of \(count)")
        }
        static var showPinned: String { localized("Shows the pinned message") }
    }
}
