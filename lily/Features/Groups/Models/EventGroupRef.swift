import Foundation

/// The group an event belongs to, as the backend stamps it on the event: enough for the badge and the link.
nonisolated struct EventGroupRef: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let visibility: GroupVisibility
    let isDeleted: Bool

    /// A public, live group is worth a link to its detail; a private or deleted one shows its name only.
    var isLinkable: Bool { visibility == .public && !isDeleted }
    var isPrivate: Bool { visibility == .private }
}
