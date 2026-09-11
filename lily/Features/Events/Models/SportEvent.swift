import Foundation

nonisolated struct EventLocation: Hashable, Codable, Sendable {
    let name: String
    let coordinate: Coordinate
}

/// Decodes the backend's `Event` directly. The only renamed field is `sport`, which the API calls `type`.
nonisolated struct SportEvent: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let sport: SportType
    let startsAt: Date
    let location: EventLocation
    let capacity: Int
    let participantCount: Int
    let hostName: String
    /// Set by the backend; `nil` for fixtures, which predate hosts having ids.
    let hostUserId: String?
    /// Whether the caller participates, as the backend saw it; `nil` when nobody has said (fixtures).
    let isJoined: Bool?

    private enum CodingKeys: String, CodingKey {
        case id, title, startsAt, location, capacity, participantCount, hostName, hostUserId, isJoined
        case sport = "type"
    }

    init(id: String,
         title: String,
         sport: SportType,
         startsAt: Date,
         location: EventLocation,
         capacity: Int,
         participantCount: Int,
         hostName: String,
         hostUserId: String? = nil,
         isJoined: Bool? = nil) {
        self.id = id
        self.title = title
        self.sport = sport
        self.startsAt = startsAt
        self.location = location
        self.capacity = capacity
        self.participantCount = participantCount
        self.hostName = hostName
        self.hostUserId = hostUserId
        self.isJoined = isJoined
    }

    var locationName: String { location.name }
    var spotsLeft: Int { max(capacity - participantCount, 0) }
    var isFull: Bool { spotsLeft == 0 }
    var isNearlyFull: Bool { !isFull && fillRatio >= AppConfig.Events.nearlyFullRatio }
    var fillRatio: Double { capacity > 0 ? min(1, Double(participantCount) / Double(capacity)) : 0 }
    var participates: Bool { isJoined ?? false }

    func isHosted(by userId: String?) -> Bool {
        hostUserId != nil && hostUserId == userId
    }

    /// Meters from `origin`, or `nil` when the user's position is unknown.
    func distance(from origin: Coordinate?) -> Measurement<UnitLength>? {
        origin.map { Measurement(value: location.coordinate.distance(to: $0), unit: .meters) }
    }

    /// The same event after a join or leave; everything but the participation is kept.
    func updatingParticipation(count: Int, isJoined: Bool) -> SportEvent {
        SportEvent(id: id,
                   title: title,
                   sport: sport,
                   startsAt: startsAt,
                   location: location,
                   capacity: capacity,
                   participantCount: count,
                   hostName: hostName,
                   hostUserId: hostUserId,
                   isJoined: isJoined)
    }
}

/// The one source for how many seats are open, so no two surfaces can disagree about a full event.
extension SportEvent {
    /// Short form for compact cards: "Full" or "3 spots left".
    var availabilityText: String {
        isFull ? AppBranding.Events.full : AppBranding.Events.spotsLeft(spotsLeft)
    }

    /// Long form under the capacity bar: "Full" or "3 of 10 spots left".
    var capacityText: String {
        isFull ? AppBranding.Events.full : AppBranding.Events.spotsLeft(spotsLeft, of: capacity)
    }
}

/// Which slice of events a list shows.
nonisolated enum EventScope: Hashable, Sendable {
    case upcoming
    case joined
}
