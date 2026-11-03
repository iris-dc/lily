import Foundation

/// Identifiers of the profile screen and of the rows that open it; a UI test that reads one mirrors the literal by hand.
nonisolated extension AccessibilityIdentifiers {
    /// The "Message" button on another person's profile.
    static let profileMessage = "profile-message"

    /// A row of an event's "Who's in" list; the caller's own row is not a link.
    static func participantRow(_ userID: String) -> String {
        "participant-row-\(userID)"
    }
}
