import Foundation

/// Identifiers of the regular-width (iPad) layouts; a UI test that reads one mirrors the literal by hand.
nonisolated extension AccessibilityIdentifiers {
    /// The persistent map beside Explore's content column on a wide layout.
    static let exploreMapPane = "explore-map-pane"
    /// The conversation list column of the Chats split view.
    static let chatsSidebar = "chats-sidebar"
    /// The split view's detail while no conversation is chosen.
    static let chatsNothingChosen = "chats-nothing-chosen"
}
