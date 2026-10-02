import Foundation

nonisolated struct EventLocation: Hashable, Codable, Sendable {
    let name: String
    let coordinate: Coordinate
}

/// Decodes the backend's `Event` directly: same keys, same optionality.
nonisolated struct SportEvent: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let type: EventType
    let startsAt: Date
    let location: EventLocation
    let capacity: Int
    let participantCount: Int
    let hostName: String
    /// Set by the backend; `nil` for fixtures, which predate hosts having ids.
    let hostUserId: String?
    /// Whether the caller participates, as the backend saw it; `nil` when nobody has said (fixtures).
    let isJoined: Bool?
    /// Optional details a host may add. All decode as `nil` when a payload omits them, so older data keeps loading.
    let description: String?
    /// Who the host still needs, in their words ("two defenders, one keeper").
    let lookingFor: String?
    let skillLevel: SkillLevel?
    /// `nil` means free.
    let price: Price?
    /// The group the game is hosted in, as the backend stamps it; `nil` for an ungrouped game.
    let group: EventGroupRef?

    init(id: String,
         title: String,
         type: EventType,
         startsAt: Date,
         location: EventLocation,
         capacity: Int,
         participantCount: Int,
         hostName: String,
         hostUserId: String? = nil,
         isJoined: Bool? = nil,
         description: String? = nil,
         lookingFor: String? = nil,
         skillLevel: SkillLevel? = nil,
         price: Price? = nil,
         group: EventGroupRef? = nil) {
        self.id = id
        self.title = title
        self.type = type
        self.startsAt = startsAt
        self.location = location
        self.capacity = capacity
        self.participantCount = participantCount
        self.hostName = hostName
        self.hostUserId = hostUserId
        self.isJoined = isJoined
        self.description = description
        self.lookingFor = lookingFor
        self.skillLevel = skillLevel
        self.price = price
        self.group = group
    }

    var locationName: String { location.name }
    var spotsLeft: Int { max(capacity - participantCount, 0) }
    var isFull: Bool { spotsLeft == 0 }
    var isNearlyFull: Bool { !isFull && fillRatio >= AppConfig.Events.nearlyFullRatio }
    var fillRatio: Double { capacity > 0 ? min(1, Double(participantCount) / Double(capacity)) : 0 }
    var participates: Bool { isJoined ?? false }
    var isFree: Bool { price?.isFree ?? true }
    /// Whether Explore lists the event, the backend's rule repeated on device: every ungrouped game and those of public
    /// groups; a private group's game is found under its group and on Home only.
    var isListed: Bool { !(group?.isPrivate ?? false) }
    /// "Free" or the per-person amount; the one formatter for every surface that shows a price. Surfaces check `isFree`
    /// first and show nothing for free games, so "Free" is the model fallback, not screen copy (the filter's price cap
    /// treats 0 as free only).
    var priceText: String { price?.text ?? AppBranding.Events.free }

    func isHosted(by userId: String?) -> Bool {
        hostUserId != nil && hostUserId == userId
    }

    /// Meters from `origin`, or `nil` when the user's position is unknown.
    func distance(from origin: Coordinate?) -> Measurement<UnitLength>? {
        origin.map { Measurement(value: location.coordinate.distance(to: $0), unit: .meters) }
    }

    /// The event after the host's edit: what the draft says, over who is in, who hosts and where it is hosted, which
    /// an edit never changes. What the mock repository and the test fake answer for an update.
    func updating(with draft: EventDraft) -> SportEvent {
        SportEvent(id: id,
                   title: draft.trimmedTitle,
                   type: draft.type,
                   startsAt: draft.startsAt,
                   location: EventLocation(name: draft.trimmedLocationName,
                                           coordinate: draft.coordinate ?? location.coordinate),
                   capacity: draft.capacity,
                   participantCount: participantCount,
                   hostName: hostName,
                   hostUserId: hostUserId,
                   isJoined: isJoined,
                   description: draft.trimmedDescription,
                   lookingFor: draft.trimmedLookingFor,
                   skillLevel: draft.skillLevel,
                   price: draft.price(),
                   group: group)
    }

    /// The same event after a join or leave; everything but the participation is kept.
    func updatingParticipation(count: Int, isJoined: Bool) -> SportEvent {
        SportEvent(id: id,
                   title: title,
                   type: type,
                   startsAt: startsAt,
                   location: location,
                   capacity: capacity,
                   participantCount: count,
                   hostName: hostName,
                   hostUserId: hostUserId,
                   isJoined: isJoined,
                   description: description,
                   lookingFor: lookingFor,
                   skillLevel: skillLevel,
                   price: price,
                   group: group)
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
    /// The upcoming games of one group, in start order; what its Events segment shows.
    case group(id: String)
}
