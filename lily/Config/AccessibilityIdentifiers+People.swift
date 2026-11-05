import Foundation

/// Identifiers of the profile screen and of the rows that open it; a UI test that reads one mirrors the literal by hand.
nonisolated extension AccessibilityIdentifiers {
    /// The "Message" button on another person's profile.
    static let profileMessage = "profile-message"
    /// The bio under a person's name.
    static let profileBio = "profile-bio"

    /// A game both joined, on a person's profile; a row, not a link.
    static func sharedEventRow(_ id: String) -> String {
        "shared-event-row-\(id)"
    }

    /// A row of an event's "Who's in" list; the caller's own row is not a link.
    static func participantRow(_ userID: String) -> String {
        "participant-row-\(userID)"
    }
}
