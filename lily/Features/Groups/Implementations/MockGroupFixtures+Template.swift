import Foundation

/// The shape of one fixture community, in a file of its own so the fixture list stays under the type-body limit.
nonisolated extension MockGroupFixtures {
    struct Template {
        let id: String
        let name: String
        let description: String
        let visibility: GroupVisibility
        let type: EventType
        let ownerName: String
        let memberCount: Int
        var maxMembers = AppConfig.Groups.maxMembers
        /// The caller's role, `nil` when they are not in.
        var role: MemberRole?
        var hasUnread = false
        /// Hours since the last message; `nil` for a silent group.
        var lastMessageHoursAgo: Double?
        let createdDaysAgo: Double
        /// The other members shown on the roster (never the caller): name and role.
        let roster: [(name: String, role: MemberRole)]
        /// Where the group plays: a real Berlin place, so the carousel's distances from `mockCenter` read true.
        let place: Place
    }

    /// The same names and coordinates as Laurel's `LocalGroupSeeder`, so a local backend and the mock agree.
    struct Place {
        let name: String
        let latitude: Double
        let longitude: Double

        init(_ name: String, _ latitude: Double, _ longitude: Double) {
            self.name = name
            self.latitude = latitude
            self.longitude = longitude
        }

        var location: EventLocation {
            EventLocation(name: name, coordinate: Coordinate(latitude: latitude, longitude: longitude))
        }
    }
}
