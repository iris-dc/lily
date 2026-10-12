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
        types = filter.types.sorted { $0.wireName < $1.wireName }
        maxDistanceMeters = filter.maxDistanceMeters
        maxPrice = filter.maxPrice
        skillLevel = filter.skillLevel
        openSpotsOnly = filter.openSpotsOnly
    }

    /// The filter as the list applies it; no date window. A type or level this build does not know (a filter kept by
    /// a newer build) is left out: the panel could neither show it nor clear it.
    var filter: EventFilter {
        EventFilter(types: Set(types.filter { !$0.isUnknown }),
                    maxDistanceMeters: maxDistanceMeters,
                    maxPrice: maxPrice,
                    skillLevel: skillLevel?.ifKnown,
                    dateWindow: nil,
                    openSpotsOnly: openSpotsOnly)
    }
}
