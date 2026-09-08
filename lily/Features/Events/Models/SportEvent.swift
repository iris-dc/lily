import Foundation

nonisolated struct EventLocation: Hashable, Codable, Sendable {
    let name: String
    let coordinate: Coordinate
}

nonisolated struct SportEvent: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let sport: SportType
    let startsAt: Date
    let location: EventLocation
    let capacity: Int
    let participantCount: Int
    let hostName: String

    var locationName: String { location.name }
    var spotsLeft: Int { max(capacity - participantCount, 0) }
    var isFull: Bool { spotsLeft == 0 }
    var isNearlyFull: Bool { !isFull && fillRatio >= AppConfig.Events.nearlyFullRatio }
    var fillRatio: Double { capacity > 0 ? Double(participantCount) / Double(capacity) : 0 }

    /// Meters from `origin`, or `nil` when the user's position is unknown.
    func distance(from origin: Coordinate?) -> Measurement<UnitLength>? {
        origin.map { Measurement(value: location.coordinate.distance(to: $0), unit: .meters) }
    }
}

/// Which slice of events a list shows.
nonisolated enum EventScope: Hashable, Sendable {
    case upcoming
    case joined
}
