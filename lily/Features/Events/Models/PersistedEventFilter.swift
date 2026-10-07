import Foundation

/// The part of an `EventFilter` worth keeping between launches: the types, the radius, the price cap, the level and
/// the open-spots switch. The date window stays out, since a stored range goes stale within days. Stored as JSON.
nonisolated struct PersistedEventFilter: Codable, Equatable, Sendable {
    /// Sorted by wire name, so equal selections store the same bytes.
    let types: [EventType]
    /// `nil` is "anywhere", as on the filter; the key is then absent.
    let maxDistanceMeters: Double?
    let maxPrice: Decimal?
    let skillLevel: SkillLevel?
    let openSpotsOnly: Bool

    init(_ filter: EventFilter) {
        types = filter.types.sorted { $0.rawValue < $1.rawValue }
        maxDistanceMeters = filter.maxDistanceMeters
        maxPrice = filter.maxPrice
        skillLevel = filter.skillLevel
        openSpotsOnly = filter.openSpotsOnly
    }

    /// The filter as the list applies it; no date window.
    var filter: EventFilter {
        EventFilter(types: Set(types),
                    maxDistanceMeters: maxDistanceMeters,
                    maxPrice: maxPrice,
                    skillLevel: skillLevel,
                    dateWindow: nil,
                    openSpotsOnly: openSpotsOnly)
    }
}
