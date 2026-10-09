import Foundation

nonisolated struct EventLocation: Hashable, Codable, Sendable {
    let name: String
    let coordinate: Coordinate
}

/// Decodes the backend's `Event` directly: same keys, same optionality. `CodingKeys` and `init(from:)` are written out
/// for one reason: `allowsExtraParticipants` reads as `false` when absent, so fixtures and payloads from before it keep
/// decoding, while the synthesized encoder still writes it.
nonisolated struct SportEvent: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let type: EventType
    let startsAt: Date
    let location: EventLocation
    /// The players the host wants: a cap, or with `allowsExtraParticipants` the number needed; `nil` for no limit.
    let capacity: Int?
    /// Whether players may join past `capacity`; such a game is never full. Always `false` without a capacity.
    let allowsExtraParticipants: Bool
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
         capacity: Int?,
         allowsExtraParticipants: Bool = false,
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
        self.allowsExtraParticipants = allowsExtraParticipants
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

    enum CodingKeys: String, CodingKey {
        case id, title, type, startsAt, location, capacity, allowsExtraParticipants, participantCount, hostName, hostUserId
        case isJoined, description, lookingFor, skillLevel, price, group
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        type = try container.decode(EventType.self, forKey: .type)
        startsAt = try container.decode(Date.self, forKey: .startsAt)
        location = try container.decode(EventLocation.self, forKey: .location)
        capacity = try container.decodeIfPresent(Int.self, forKey: .capacity)
        allowsExtraParticipants = try container.decodeIfPresent(Bool.self, forKey: .allowsExtraParticipants) ?? false
        participantCount = try container.decode(Int.self, forKey: .participantCount)
        hostName = try container.decode(String.self, forKey: .hostName)
        hostUserId = try container.decodeIfPresent(String.self, forKey: .hostUserId)
        isJoined = try container.decodeIfPresent(Bool.self, forKey: .isJoined)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        lookingFor = try container.decodeIfPresent(String.self, forKey: .lookingFor)
        skillLevel = try container.decodeIfPresent(SkillLevel.self, forKey: .skillLevel)
        price = try container.decodeIfPresent(Price.self, forKey: .price)
        group = try container.decodeIfPresent(EventGroupRef.self, forKey: .group)
    }

    var locationName: String { location.name }
    var playerLimit: PlayerLimit { PlayerLimit(capacity: capacity, allowsExtraParticipants: allowsExtraParticipants) }
    /// Seats under the cap, or still missing to the number needed; zero without a limit or once it is reached.
    var spotsLeft: Int { capacity.map { max($0 - participantCount, 0) } ?? 0 }
    /// Only a capped game is ever full, once the count reaches the cap.
    var isFull: Bool { playerLimit == .maximum && spotsLeft == 0 }
    /// Amber warns that a cap is near; a game without one has nothing to warn about.
    var isNearlyFull: Bool { playerLimit == .maximum && !isFull && fillRatio >= AppConfig.Events.nearlyFullRatio }
    /// The people the host asked for are in; what a game that allows extras counts up to before it counts past.
    var hasPlayersNeeded: Bool { capacity.map { participantCount >= $0 } ?? false }
    /// The occupied share of the capacity, clamped to one; zero without a limit, which draws no bar.
    var fillRatio: Double {
        guard let capacity, capacity > 0 else { return 0 }
        return min(1, Double(participantCount) / Double(capacity))
    }
    var participates: Bool { isJoined ?? false }
    var isFree: Bool { price?.isFree ?? true }
    /// For the create and update log lines: the shape of the limit, never a name.
    var spotsDescription: String {
        guard let capacity else { return "no limit" }
        return "\(capacity) spots" + (allowsExtraParticipants ? ", extras allowed" : "")
    }
    /// For the join and leave log lines: "7/10", or the count alone without a limit.
    var countDescription: String { capacity.map { "\(participantCount)/\($0)" } ?? "\(participantCount)" }
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
                   capacity: draft.capacityIfLimited,
                   allowsExtraParticipants: draft.allowsExtraParticipants,
                   participantCount: participantCount,
                   hostName: hostName,
                   hostUserId: hostUserId,
                   isJoined: isJoined,
                   description: draft.trimmedDescription,
                   lookingFor: draft.trimmedLookingFor,
                   skillLevel: draft.skillLevel,
                   price: draft.eventPrice,
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
                   allowsExtraParticipants: allowsExtraParticipants,
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
    /// Short form for compact cards: "Full" or "3 spots left" under a cap; "3 more needed" or "12 joined" for a game
    /// that allows extras; "12 joined" without a limit.
    var availabilityText: String {
        switch playerLimit {
        case .unlimited:
            return AppBranding.Events.joinedCount(participantCount)
        case .minimum:
            return hasPlayersNeeded ? AppBranding.Events.joinedCount(participantCount) : AppBranding.Events.moreNeeded(spotsLeft)
        case .maximum:
            return isFull ? AppBranding.Events.full : AppBranding.Events.spotsLeft(spotsLeft)
        }
    }

    /// Long form under the capacity bar: "Full" or "7 of 10 joined" under a cap, counting the way the bar fills;
    /// "7 joined · 10 needed" for a game that allows extras, whatever side of the number it is on; "7 joined" without
    /// a limit, where there is no bar.
    var capacityText: String {
        switch (playerLimit, capacity) {
        case (.minimum, let capacity?):
            return AppBranding.Events.joined(participantCount, needed: capacity)
        case (.maximum, let capacity?):
            return isFull ? AppBranding.Events.full : AppBranding.Events.joined(participantCount, of: capacity)
        default:
            return AppBranding.Events.joinedCount(participantCount)
        }
    }
}

/// Which slice of events a list shows.
nonisolated enum EventScope: Hashable, Sendable {
    case upcoming
    case joined
    /// The upcoming games of one group, in start order; what its Events segment shows.
    case group(id: String)
}
