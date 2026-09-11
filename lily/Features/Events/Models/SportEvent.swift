import Foundation

nonisolated struct EventLocation: Hashable, Codable, Sendable {
    let name: String
    let coordinate: Coordinate
}

nonisolated struct SportEvent: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let type: EventType
    let startsAt: Date
    let location: EventLocation
    let capacity: Int
    let participantCount: Int
    let hostName: String
    /// Optional details a host may add. All decode as `nil` when a payload omits them, so older data keeps loading.
    let description: String?
    /// Who the host still needs, in their words ("two defenders, one keeper").
    let lookingFor: String?
    let skillLevel: SkillLevel?
    /// `nil` means free.
    let price: Price?

    init(id: String,
         title: String,
         type: EventType,
         startsAt: Date,
         location: EventLocation,
         capacity: Int,
         participantCount: Int,
         hostName: String,
         description: String? = nil,
         lookingFor: String? = nil,
         skillLevel: SkillLevel? = nil,
         price: Price? = nil) {
        self.id = id
        self.title = title
        self.type = type
        self.startsAt = startsAt
        self.location = location
        self.capacity = capacity
        self.participantCount = participantCount
        self.hostName = hostName
        self.description = description
        self.lookingFor = lookingFor
        self.skillLevel = skillLevel
        self.price = price
    }

    var locationName: String { location.name }
    var spotsLeft: Int { max(capacity - participantCount, 0) }
    var isFull: Bool { spotsLeft == 0 }
    var isNearlyFull: Bool { !isFull && fillRatio >= AppConfig.Events.nearlyFullRatio }
    var fillRatio: Double { capacity > 0 ? min(1, Double(participantCount) / Double(capacity)) : 0 }
    var isFree: Bool { price?.isFree ?? true }
    /// "Free" or the per-person amount; the one formatter for every surface that shows a price. Surfaces check `isFree`
    /// first and show nothing for free games, so "Free" is the model fallback, not screen copy (the filter's price cap
    /// treats 0 as free only).
    var priceText: String { price?.text ?? AppBranding.Events.free }

    /// Meters from `origin`, or `nil` when the user's position is unknown.
    func distance(from origin: Coordinate?) -> Measurement<UnitLength>? {
        origin.map { Measurement(value: location.coordinate.distance(to: $0), unit: .meters) }
    }
}

/// The one source for how many seats are open, so no two surfaces can disagree about a full event.
extension SportEvent {
    /// Short form for compact cards: "Full" or "3 spots left".
    var availabilityText: String {
        isFull ? AppBranding.Events.full : AppBranding.Events.spotsLeft(spotsLeft)
    }

    /// Long form under the capacity bar: "Full" or "7 of 10 joined", counting the way the bar fills.
    var capacityText: String {
        isFull ? AppBranding.Events.full : AppBranding.Events.joined(participantCount, of: capacity)
    }
}

/// Which slice of events a list shows.
nonisolated enum EventScope: Hashable, Sendable {
    case upcoming
    case joined
}
