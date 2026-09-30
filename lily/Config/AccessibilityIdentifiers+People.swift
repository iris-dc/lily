import Foundation

/// Identifiers of the profile screen and of the rows that open it; mirrored by hand in `lilyUITests` like the rest.
nonisolated extension AccessibilityIdentifiers {
    /// The "Message" button on another person's profile.
    static let profileMessage = "profile-message"
    /// The "Groups in common" rows on a profile.
    static let profileSharedGroups = "profile-shared-groups"
    /// The host line under an event's title, a link to the host's profile when the caller may open it.
    static let eventHost = "event-host"

    /// A row of an event's "Who's in" list; the caller's own row is not a link.
    static func participantRow(_ userID: String) -> String {
        "participant-row-\(userID)"
    }
}
